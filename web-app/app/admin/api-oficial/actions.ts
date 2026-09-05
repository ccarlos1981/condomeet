'use server'

import { createClient as createServerClient } from '@/lib/supabase/server'
import { createClient as createSupabaseClient } from '@supabase/supabase-js'
import { createHash } from 'node:crypto'

// Helper to obtain an administrative Supabase client exclusively on the server
function getAdminClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY

  if (!url || !serviceRoleKey) {
    throw new Error('Supabase environment variables (NEXT_PUBLIC_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY) are missing on the server.')
  }

  return createSupabaseClient(url, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    }
  })
}

// Helper to check authorization using server session, system roles, and the system_superadmins table (MASTER admins only)
async function checkAuth() {
  const supabase = await createServerClient()
  const { data: { user }, error: authError } = await supabase.auth.getUser()
  if (authError || !user) {
    throw new Error('Acesso Negado: Usuário não autenticado.')
  }

  // Fetch role from perfil
  const { data: profile } = await supabase
    .from('perfil')
    .select('papel_sistema')
    .eq('id', user.id)
    .single()

  if (!profile) {
    throw new Error('Acesso Negado: Usuário sem perfil cadastrado.')
  }

  const role = profile.papel_sistema ?? ''
  const isRoleMaster = ['admin', 'superadmin', 'super_admin', 'master'].includes(role.toLowerCase())

  // Check system_superadmins table
  const { data: superadmin } = await supabase
    .from('system_superadmins')
    .select('email')
    .eq('email', user.email ?? '')
    .maybeSingle()

  const isSuperAdmin = !!superadmin
  const isMaster = isRoleMaster || isSuperAdmin

  if (!isMaster) {
    throw new Error('Acesso Negado: Acesso restrito a administradores MASTER.')
  }

  return {
    id: user.id,
    email: user.email,
    isMaster
  }
}

export async function getSuperUserInfo() {
  try {
    const auth = await checkAuth()
    return { authorized: true, email: auth.email }
  } catch (err: any) {
    return { authorized: false, error: err.message }
  }
}

export async function getDashboardMetrics() {
  await checkAuth()

  const supabase = await createServerClient()
  const adminClient = getAdminClient()

  // 1. Fetch Price Table
  const { data: prices } = await supabase
    .from('whatsapp_price_table')
    .select('*')
  
  const priceMap: Record<string, number> = {}
  if (prices) {
    for (const p of prices) {
      priceMap[p.category] = Number(p.price)
    }
  }

  // Define categories prices fallbacks
  const priceUtility = priceMap['utility'] ?? 0.0700
  const priceMarketing = priceMap['marketing'] ?? 0.3000
  const priceAuth = priceMap['authentication'] ?? 0.0600
  const priceService = priceMap['service'] ?? 0.0000

  // Calculate timestamps
  const now = new Date()
  const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  const startOfYesterday = new Date(startOfToday.getTime() - 24 * 60 * 60 * 1000)
  
  const startOfWeek = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000)
  const startOfLastWeek = new Date(now.getTime() - 14 * 24 * 60 * 60 * 1000)
  
  const startOfMonth = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000)
  const startOfLastMonth = new Date(now.getTime() - 60 * 24 * 60 * 60 * 1000)

  // 2. Build global message stats queries using admin client
  const [
    todayMsgs, yesterdayMsgs,
    weekMsgs, lastWeekMsgs,
    monthMsgs, lastMonthMsgs,
    metricsViewRes,
    templateUsageRes
  ] = await Promise.all([
    adminClient.from('whatsapp_outbox').select('template_name, payload_type, status, created_at').eq('status', 'sent').eq('delivery_result->>provider', 'META_CLOUD_API').gte('sent_at', startOfToday.toISOString()),
    adminClient.from('whatsapp_outbox').select('template_name, payload_type, status, created_at').eq('status', 'sent').eq('delivery_result->>provider', 'META_CLOUD_API').gte('sent_at', startOfYesterday.toISOString()).lt('sent_at', startOfToday.toISOString()),
    
    adminClient.from('whatsapp_outbox').select('template_name, payload_type, status, created_at').eq('status', 'sent').eq('delivery_result->>provider', 'META_CLOUD_API').gte('sent_at', startOfWeek.toISOString()),
    adminClient.from('whatsapp_outbox').select('template_name, payload_type, status, created_at').eq('status', 'sent').eq('delivery_result->>provider', 'META_CLOUD_API').gte('sent_at', startOfLastWeek.toISOString()).lt('sent_at', startOfWeek.toISOString()),
    
    adminClient.from('whatsapp_outbox').select('template_name, payload_type, status, created_at').eq('status', 'sent').eq('delivery_result->>provider', 'META_CLOUD_API').gte('sent_at', startOfMonth.toISOString()),
    adminClient.from('whatsapp_outbox').select('template_name, payload_type, status, created_at').eq('status', 'sent').eq('delivery_result->>provider', 'META_CLOUD_API').gte('sent_at', startOfLastMonth.toISOString()).lt('sent_at', startOfMonth.toISOString()),
    
    supabase.from('whatsapp_metrics_view').select('*').single(),
    supabase.from('whatsapp_template_usage_view').select('*').order('usage_count', { ascending: false })
  ])

  // Helper to sum cost based on template names
  const calculateCost = (msgs: any[] | null) => {
    if (!msgs) return 0
    return msgs.reduce((acc, msg) => {
      if (msg.template_name) {
        if (msg.template_name.includes('senha') || msg.template_name.includes('otp')) {
          return acc + priceAuth
        }
        return acc + priceUtility
      }
      return acc + priceService
    }, 0)
  }

  const costToday = calculateCost(todayMsgs.data)
  const costYesterday = calculateCost(yesterdayMsgs.data)
  
  const costWeek = calculateCost(weekMsgs.data)
  const costLastWeek = calculateCost(lastWeekMsgs.data)
  
  const costMonth = calculateCost(monthMsgs.data)
  const costLastMonth = calculateCost(lastMonthMsgs.data)

  // Calculations of growths
  const growthToday = costYesterday > 0 ? ((costToday - costYesterday) / costYesterday) * 100 : 0
  const growthWeek = costLastWeek > 0 ? ((costWeek - costLastWeek) / costLastWeek) * 100 : 0
  const growthMonth = costLastMonth > 0 ? ((costMonth - costLastMonth) / costLastMonth) * 100 : 0

  const metricsView = metricsViewRes.data || {
    meta_sent_count: 0,
    meta_delivered_count: 0,
    meta_read_count: 0,
    meta_failed_count: 0,
    botconversa_sent_count: 0,
    meta_free_window_count: 0,
    meta_template_count: 0,
    meta_avg_latency_sec: 0,
    active_conversations_today: 0,
    meta_savings_brl: 0,
    meta_total_cost_brl: 0
  }

  return {
    costs: {
      today: { value: costToday, count: todayMsgs.data?.length || 0, growth: growthToday },
      week: { value: costWeek, count: weekMsgs.data?.length || 0, growth: growthWeek },
      month: { value: costMonth, count: monthMsgs.data?.length || 0, growth: growthMonth }
    },
    metricsView,
    templateUsage: templateUsageRes.data || []
  }
}

export async function getConsumptionByCondo() {
  await checkAuth()

  const supabase = await createServerClient()
  const { data, error } = await supabase.rpc('get_whatsapp_consumption_by_condo', {
    p_condominio_id: null
  })

  if (error) {
    console.error('Error fetching consumption by condo:', error)
    throw new Error(error.message)
  }

  return data || []
}

export async function getConversations(searchQuery = '', filterType = 'all') {
  await checkAuth()

  const supabase = await createServerClient()
  const adminClient = getAdminClient()

  let query = supabase
    .from('whatsapp_conversations')
    .select(`
      *,
      condominios(nome),
      perfil(nome_completo, bloco_txt, apto_txt)
    `)
    .order('last_message_at', { ascending: false })

  // Apply filters
  if (filterType === 'janela_aberta') {
    query = query.gte('window_open_until', new Date().toISOString())
  } else if (filterType === 'janela_fechada') {
    query = query.or(`window_open_until.lt.${new Date().toISOString()},window_open_until.is.null`)
  } else if (filterType === 'nao_lidas') {
    query = query.gt('unread_count', 0)
  }

  const { data: conversations, error } = await query

  if (error) {
    console.error('[getConversations] Error fetching conversations:', error.message)
    return []
  }

  if (!conversations) return []

  // Filtro por participação histórica de provedores em whatsapp_outbox
  let providerFiltered = conversations
  if (filterType === 'meta' || filterType === 'botconversa' || filterType === 'evolution') {
    const targetProvider = 
      filterType === 'meta' ? 'META_CLOUD_API' :
      filterType === 'botconversa' ? 'BOTCONVERSA' : 
      'EVOLUTION'

    const { data: outboxRecords } = await adminClient
      .from('whatsapp_outbox')
      .select('recipient_phone')
      .eq('delivery_result->>provider', targetProvider)

    const historicalPhones = new Set(outboxRecords?.map(o => o.recipient_phone).filter(Boolean) || [])
    providerFiltered = conversations.filter(c => 
      c.current_provider === targetProvider || historicalPhones.has(c.telefone)
    )
  }

  // Client side / Server Action memory filtering for global search to bypass SQL join limitations
  let filtered = providerFiltered
  if (searchQuery.trim()) {
    const term = searchQuery.toLowerCase()
    filtered = providerFiltered.filter(c => {
      const nameMatch = c.perfil?.nome_completo?.toLowerCase().includes(term)
      const phoneMatch = c.telefone?.toLowerCase().includes(term)
      const unitMatch = (c.perfil?.bloco_txt?.toLowerCase().includes(term) || c.perfil?.apto_txt?.toLowerCase().includes(term))
      const condoMatch = c.condominios?.nome?.toLowerCase().includes(term)
      return nameMatch || phoneMatch || unitMatch || condoMatch
    })
  }

  return filtered
}

export async function getChatHistory(telefone: string) {
  await checkAuth()

  const canonicalPhone = normalizePhone(telefone)
  if (!canonicalPhone) {
    throw new Error('Telefone inválido para consulta.')
  }

  const adminClient = getAdminClient()

  const { data: messages, error } = await adminClient
    .from('whatsapp_outbox')
    .select('*')
    .eq('recipient_phone', canonicalPhone)
    .order('created_at', { ascending: true })

  if (error) {
    console.error('[getChatHistory] Error fetching outbox:', error.message)
    throw new Error('Falha ao recuperar histórico da conversa.')
  }

  // Reset unread counts on view
  const supabase = await createServerClient()
  await supabase
    .from('whatsapp_conversations')
    .update({ unread_count: 0 })
    .eq('telefone', canonicalPhone)

  return messages || []
}

function normalizePhone(raw: string): string {
  if (!raw) return ""
  let phone = raw.replace(/\D/g, "").replace(/^0+/, "")
  if (phone.length === 0) return ""
  if (!phone.startsWith("55") || phone.length === 10 || phone.length === 11) {
    phone = "55" + phone
  }
  if (phone.length === 12) {
    const country = phone.substring(0, 2)
    const ddd = phone.substring(2, 4)
    const local = phone.substring(4)
    const firstDigit = local.charAt(0)
    if (["6", "7", "8", "9"].includes(firstDigit)) {
      phone = country + ddd + "9" + local
    }
  }
  return phone
}

function sha256(text: string): string {
  return createHash('sha256').update(text).digest('hex')
}

export async function sendManualMessage(
  telefone: string,
  text: string,
  templateName?: string,
  variables: string[] = [],
  reason = ''
) {
  const authInfo = await checkAuth()
  const canonicalPhone = normalizePhone(telefone)
  if (!canonicalPhone) {
    throw new Error('Telefone inválido para envio de mensagem.')
  }

  const supabase = await createServerClient()
  const adminClient = getAdminClient()

  // Fetch conversation window status
  const { data: conv } = await supabase
    .from('whatsapp_conversations')
    .select('window_open_until, condominio_id, perfil_id')
    .eq('telefone', canonicalPhone)
    .maybeSingle()

  // Format message content
  let messageContent: any = { value: text }
  if (templateName) {
    messageContent = {
      value: text,
      template: {
        name: templateName,
        language: 'pt_BR',
        variables
      }
    }
  }

  // Calculate message hash for deduplication and DB constraint
  const payloadType = templateName ? 'interactive' : 'text'
  const rawString = `${canonicalPhone}:${payloadType}:${text}:${conv?.condominio_id || ""}`
  const messageHash = sha256(rawString)

  // Insert outgoing audit message in outbox using admin client
  const { data: newMsg, error } = await adminClient
    .from('whatsapp_outbox')
    .insert({
      recipient_phone: canonicalPhone,
      payload_type: templateName ? 'interactive' : 'text',
      message_type: templateName ? 'TEMPLATE_MANUAL' : 'TEXTO_LIVRE_MANUAL',
      message_content: messageContent,
      status: 'pending',
      perfil_id: conv?.perfil_id || null,
      condominio_id: conv?.condominio_id || null,
      manual_sent_by: authInfo.email,
      manual_sent_at: new Date().toISOString(),
      manual_reason: reason || 'Envio manual via painel Chat',
      message_hash: messageHash
    })
    .select()
    .single()

  if (error) {
    console.error('[sendManualMessage] Error inserting outbox message:', error.message)
    throw new Error(error.message)
  }

  return newMsg
}
