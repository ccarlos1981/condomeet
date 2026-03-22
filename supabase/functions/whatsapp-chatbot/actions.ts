// actions.ts — Executes actions returned by Gemini AI
// Each action modifies the database or sends notifications

import { type SupabaseClient } from "npm:@supabase/supabase-js@2"
import { sendTextMessage } from "../_shared/uazapi.ts"

export interface ActionResult {
  type: string
  success: boolean
  details?: string
  error?: string
}

interface ActionParams {
  supabase: SupabaseClient
  perfilId: string
  condominioId: string
  bloco: string
  apto: string
  moradorNome: string
  uazapiUrl: string
  uazapiToken: string
}

// ── Execute all actions from Gemini response ────────────────────────────────

export async function executeActions(
  actions: Array<{ type: string; params?: Record<string, unknown> }>,
  ctx: ActionParams
): Promise<ActionResult[]> {
  const results: ActionResult[] = []

  for (const action of actions) {
    try {
      let result: ActionResult

      switch (action.type) {
        case "CREATE_VISITOR_AUTH":
          result = await createVisitorAuth(ctx, action.params || {})
          break
        case "ESCALATE_TO_HUMAN":
          result = await escalateToHuman(ctx)
          break
        case "BLOCK_NOTIFICATIONS":
          result = await blockNotifications(ctx)
          break
        case "DEACTIVATE_USER":
          result = await deactivateUser(ctx)
          break
        case "CHANGE_PHONE":
          result = await changePhone(ctx, action.params || {})
          break
        case "REPORT_WRONG_PARCEL":
          result = await reportWrongParcel(ctx)
          break
        default:
          result = { type: action.type, success: false, error: `Ação desconhecida: ${action.type}` }
      }

      results.push(result)
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err)
      results.push({ type: action.type, success: false, error: msg })
    }
  }

  return results
}

// ── Action: Create Visitor Authorization ────────────────────────────────────

async function createVisitorAuth(
  ctx: ActionParams,
  params: Record<string, unknown>
): Promise<ActionResult> {
  const guestName = String(params.guest_name || "")
  const visitorType = String(params.visitor_type || "Visitante")
  const validityDate = String(params.validity_date || new Date().toISOString().split("T")[0])

  if (!guestName) {
    return { type: "CREATE_VISITOR_AUTH", success: false, error: "Nome do visitante não informado" }
  }

  // Generate QR code data
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
  const shortCode = Array.from({ length: 3 }, () => chars[Math.floor(Math.random() * chars.length)]).join('')

  const { error } = await ctx.supabase.from("convites").insert({
    resident_id: ctx.perfilId,
    condominio_id: ctx.condominioId,
    guest_name: guestName,
    visitor_type: visitorType,
    validity_date: `${validityDate}T23:59:59-03:00`,
    qr_data: shortCode,
    status: "active",
  })

  if (error) {
    console.error("[ACTION] CREATE_VISITOR_AUTH error:", error)
    return { type: "CREATE_VISITOR_AUTH", success: false, error: error.message }
  }

  console.log(`[ACTION] Created visitor auth: ${guestName} (${visitorType}) for ${validityDate}, code: ${shortCode}`)
  return {
    type: "CREATE_VISITOR_AUTH",
    success: true,
    details: `Autorização criada para ${guestName}. Código: ${shortCode}`,
  }
}

// ── Action: Escalate to Human Attendant ─────────────────────────────────────

async function escalateToHuman(ctx: ActionParams): Promise<ActionResult> {
  const adminPhone1 = Deno.env.get("ADMIN_PHONE_1") || "5531992707070"
  const adminPhone2 = Deno.env.get("ADMIN_PHONE_2") || "5531994707070"

  const msg =
    `🔔 *Condomeet — Solicitação de Atendimento*\n\n` +
    `Temos um usuário querendo atendimento no sistema Condomeet.\n\n` +
    `👤 Morador: ${ctx.moradorNome}\n` +
    `🏢 Unidade: Bloco ${ctx.bloco} / Apto ${ctx.apto}\n\n` +
    `Por favor, entre em contato com o morador.`

  const [r1, r2] = await Promise.all([
    sendTextMessage(ctx.uazapiUrl, ctx.uazapiToken, adminPhone1, msg),
    sendTextMessage(ctx.uazapiUrl, ctx.uazapiToken, adminPhone2, msg),
  ])

  const success = r1.success || r2.success
  console.log(`[ACTION] ESCALATE_TO_HUMAN: admin1=${r1.success}, admin2=${r2.success}`)

  return {
    type: "ESCALATE_TO_HUMAN",
    success,
    details: success ? "Administradores notificados" : "Falha ao notificar administradores",
  }
}

// ── Action: Block Notifications ─────────────────────────────────────────────

async function blockNotifications(ctx: ActionParams): Promise<ActionResult> {
  const { error } = await ctx.supabase
    .from("perfil")
    .update({ notificacoes_whatsapp: false })
    .eq("id", ctx.perfilId)

  if (error) {
    console.error("[ACTION] BLOCK_NOTIFICATIONS error:", error)
    return { type: "BLOCK_NOTIFICATIONS", success: false, error: error.message }
  }

  console.log(`[ACTION] Blocked notifications for perfil ${ctx.perfilId}`)
  return { type: "BLOCK_NOTIFICATIONS", success: true, details: "Notificações desativadas" }
}

// ── Action: Deactivate User ─────────────────────────────────────────────────

async function deactivateUser(ctx: ActionParams): Promise<ActionResult> {
  const { error } = await ctx.supabase
    .from("perfil")
    .update({
      status_aprovacao: "reprovado",
      notificacoes_whatsapp: false,
    })
    .eq("id", ctx.perfilId)

  if (error) {
    console.error("[ACTION] DEACTIVATE_USER error:", error)
    return { type: "DEACTIVATE_USER", success: false, error: error.message }
  }

  console.log(`[ACTION] Deactivated user perfil ${ctx.perfilId}`)
  return { type: "DEACTIVATE_USER", success: true, details: "Cadastro inativado" }
}

// ── Action: Change Phone Number ─────────────────────────────────────────────

async function changePhone(
  ctx: ActionParams,
  params: Record<string, unknown>
): Promise<ActionResult> {
  let newPhone = String(params.new_phone || "").replace(/\D/g, "")

  if (!newPhone || newPhone.length < 10) {
    return { type: "CHANGE_PHONE", success: false, error: "Número inválido" }
  }

  // Add DDI if missing
  if (!newPhone.startsWith("55")) {
    newPhone = "55" + newPhone
  }

  const { error } = await ctx.supabase
    .from("perfil")
    .update({ whatsapp: newPhone })
    .eq("id", ctx.perfilId)

  if (error) {
    console.error("[ACTION] CHANGE_PHONE error:", error)
    return { type: "CHANGE_PHONE", success: false, error: error.message }
  }

  console.log(`[ACTION] Changed phone for perfil ${ctx.perfilId} to ${newPhone}`)
  return { type: "CHANGE_PHONE", success: true, details: `Celular atualizado para ${newPhone}` }
}

// ── Action: Report Wrong Parcel ─────────────────────────────────────────────

async function reportWrongParcel(ctx: ActionParams): Promise<ActionResult> {
  // Find all síndicos of this condominium
  const { data: sindicos } = await ctx.supabase
    .from("perfil")
    .select("id, nome_completo, whatsapp")
    .eq("condominio_id", ctx.condominioId)
    .in("papel_sistema", ["Sindico", "Síndico", "sindico", "Síndico (a)", "Admin", "admin"])
    .eq("status_aprovacao", "aprovado")
    .not("whatsapp", "is", null)

  if (!sindicos || sindicos.length === 0) {
    // Fallback: notify admin phones
    const adminPhone1 = Deno.env.get("ADMIN_PHONE_1") || "5531992707070"
    const msg =
      `⚠️ *Condomeet — Encomenda Errada*\n\n` +
      `Morador(a) ${ctx.moradorNome} (Bloco ${ctx.bloco} / Apto ${ctx.apto}) avisou que a última encomenda cadastrada NÃO pertence à unidade dele(a).\n\n` +
      `Por favor, verifique.`

    await sendTextMessage(ctx.uazapiUrl, ctx.uazapiToken, adminPhone1, msg)

    return {
      type: "REPORT_WRONG_PARCEL",
      success: true,
      details: "Administrador notificado sobre encomenda errada",
    }
  }

  // Notify all síndicos
  const msg =
    `⚠️ *Condomeet — Encomenda Errada*\n\n` +
    `Morador(a) ${ctx.moradorNome} (Bloco ${ctx.bloco} / Apto ${ctx.apto}) avisou que a última encomenda cadastrada NÃO pertence à unidade dele(a).\n\n` +
    `Por favor, verifique no sistema.`

  let anySuccess = false
  for (const sindico of sindicos) {
    if (sindico.whatsapp) {
      const phone = sindico.whatsapp.startsWith("55") ? sindico.whatsapp : "55" + sindico.whatsapp
      const result = await sendTextMessage(ctx.uazapiUrl, ctx.uazapiToken, phone, msg)
      if (result.success) anySuccess = true

      // Small delay between sends
      await new Promise(r => setTimeout(r, 2000))
    }
  }

  console.log(`[ACTION] REPORT_WRONG_PARCEL: notified ${sindicos.length} síndico(s)`)
  return {
    type: "REPORT_WRONG_PARCEL",
    success: anySuccess,
    details: `${sindicos.length} síndico(s) notificado(s)`,
  }
}
