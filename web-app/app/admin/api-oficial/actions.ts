'use client'

import { createClient } from '@/lib/supabase/client'

// Helper to check authorization using system roles and the system_superadmins table (MASTER admins only)
async function checkAuth(supabase: any) {
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) {
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
  const supabase = createClient()
  try {
    const auth = await checkAuth(supabase)
    return { authorized: true, email: auth.email }
  } catch (err: any) {
    return { authorized: false, error: err.message }
  }
}

export async function getDashboardMetrics() {
  const supabase = createClient()
  await checkAuth(supabase)

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

  // 2. Build global message stats queries
  const [
    todayMsgs, yesterdayMsgs,
    weekMsgs, lastWeekMsgs,
    monthMsgs, lastMonthMsgs,
    metricsViewRes,
    templateUsageRes
  ] = await Promise.all([
    supabase.from('whatsapp_outbox').select('template_name, payload_type, status, created_at').eq('status', 'sent').eq('delivery_result->>provider', 'META_CLOUD_API').gte('sent_at', startOfToday.toISOString()),
    supabase.from('whatsapp_outbox').select('template_name, payload_type, status, created_at').eq('status', 'sent').eq('delivery_result->>provider', 'META_CLOUD_API').gte('sent_at', startOfYesterday.toISOString()).lt('sent_at', startOfToday.toISOString()),
    
    supabase.from('whatsapp_outbox').select('template_name, payload_type, status, created_at').eq('status', 'sent').eq('delivery_result->>provider', 'META_CLOUD_API').gte('sent_at', startOfWeek.toISOString()),
    supabase.from('whatsapp_outbox').select('template_name, payload_type, status, created_at').eq('status', 'sent').eq('delivery_result->>provider', 'META_CLOUD_API').gte('sent_at', startOfLastWeek.toISOString()).lt('sent_at', startOfWeek.toISOString()),
    
    supabase.from('whatsapp_outbox').select('template_name, payload_type, status, created_at').eq('status', 'sent').eq('delivery_result->>provider', 'META_CLOUD_API').gte('sent_at', startOfMonth.toISOString()),
    supabase.from('whatsapp_outbox').select('template_name, payload_type, status, created_at').eq('status', 'sent').eq('delivery_result->>provider', 'META_CLOUD_API').gte('sent_at', startOfLastMonth.toISOString()).lt('sent_at', startOfMonth.toISOString()),
    
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
  const supabase = createClient()
  await checkAuth(supabase)

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
  const supabase = createClient()
  await checkAuth(supabase)

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
  } else if (filterType === 'meta') {
    query = query.eq('current_provider', 'META_CLOUD_API')
  } else if (filterType === 'botconversa') {
    query = query.eq('current_provider', 'BOTCONVERSA')
  }

  const { data: conversations } = await query

  if (!conversations) return []

  // Client side/Server Action memory filtering for global search to bypass SQL join limitations
  let filtered = conversations
  if (searchQuery.trim()) {
    const term = searchQuery.toLowerCase()
    filtered = conversations.filter(c => {
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
  const supabase = createClient()
  await checkAuth(supabase)

  const { data: messages } = await supabase
    .from('whatsapp_outbox')
    .select('*')
    .eq('recipient_phone', telefone)
    .order('created_at', { ascending: true })

  // Reset unread counts on view
  await supabase
    .from('whatsapp_conversations')
    .update({ unread_count: 0 })
    .eq('telefone', telefone)

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

async function sha256(text: string): Promise<string> {
  const msgBuffer = new TextEncoder().encode(text)
  const cryptoObj = typeof window !== 'undefined' ? window.crypto : (typeof globalThis !== 'undefined' ? globalThis.crypto : null)
  if (!cryptoObj || !cryptoObj.subtle) {
    throw new Error('Cryptographic library subtle is not available in this environment.')
  }
  const hashBuffer = await cryptoObj.subtle.digest("SHA-256", msgBuffer)
  const hashArray = Array.from(new Uint8Array(hashBuffer))
  const hashHex = hashArray.map(b => b.toString(16).padStart(2, "0")).join("")
  return hashHex
}

export async function sendManualMessage(
  telefone: string,
  text: string,
  templateName?: string,
  variables: string[] = [],
  reason = ''
) {
  const supabase = createClient()
  const authInfo = await checkAuth(supabase)

  // Fetch conversation window status
  const { data: conv } = await supabase
    .from('whatsapp_conversations')
    .select('window_open_until, condominio_id, perfil_id')
    .eq('telefone', telefone)
    .maybeSingle()

  const isWindowOpen = conv?.window_open_until && new Date(conv.window_open_until) >= new Date()

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
  const phoneNormalized = normalizePhone(telefone)
  const payloadType = templateName ? 'interactive' : 'text'
  const rawString = `${phoneNormalized}:${payloadType}:${text}:${conv?.condominio_id || ""}`
  const messageHash = await sha256(rawString)

  // Insert outgoing audit message in outbox
  const { data: newMsg, error } = await supabase
    .from('whatsapp_outbox')
    .insert({
      recipient_phone: telefone,
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

  if (error) throw new Error(error.message)
  return newMsg
}

