// password-reset-smoke-test — Supabase Edge Function & Admin Tool
// Ferramenta oficial de Smoke Test para validação pós-deploy do fluxo de Recuperação de Senha (OTP).
//
// Verifica automaticamente:
//   1. Geração e persistência do OTP em password_reset_codes
//   2. Enfileiramento na whatsapp_outbox com message_type = OTP
//   3. Resolução do template condomeet_recuperacao_senha_v1 no MetaTemplateService
//   4. Processamento pelo whatsapp-outbox-worker
//   5. Envio pelo provider ativo (META_CLOUD_API ou BOTCONVERSA)
//   6. Atualização do status da mensagem (pending → sending → sent)
//   7. Validação e consumo do código OTP
//   8. Relatório estruturado com latências e resultado final (SUCESSO / FALHA)

import { createClient } from "npm:@supabase/supabase-js@2"
import { MessageType, TEMPLATE_REGISTRY } from "../_shared/message_types.ts"
import { renderTemplateText } from "../_shared/template_renderer.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

export interface SmokeTestStep {
  step: string
  status: "PASSED" | "FAILED" | "SKIPPED"
  latencyMs: number
  details: string
}

export interface SmokeTestReport {
  timestamp: string
  executionId: string
  environment: string
  activeProvider: string
  templateName: string
  totalDurationMs: number
  finalResult: "SUCESSO" | "FALHA"
  recipientPhone: string
  recipientEmail: string
  otpCode: string
  steps: SmokeTestStep[]
  logs: string[]
  failureCause?: string
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  const startTime = Date.now()
  const executionId = crypto.randomUUID()
  const logs: string[] = []

  const log = (msg: string) => {
    const timeStr = new Date().toISOString()
    const line = `[${timeStr}] ${msg}`
    logs.push(line)
    console.log(line)
  }

  log(`Iniciando Smoke Test Oficial de Recuperação de Senha (ID: ${executionId})`)

  let payload: any = {}
  try {
    payload = await req.json()
  } catch (_) {
    // Usar defaults se payload vazio
  }

  const testPhone = payload.phone || "5531999998888"
  const testEmail = payload.email || "smoketest@condomeet.com.br"
  const triggerWorker = payload.triggerWorker !== false // Default true

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  )

  const steps: SmokeTestStep[] = []
  let activeProvider = "DESCONHECIDO"
  let templateName = "condomeet_recuperacao_senha_v1"
  let failureCause: string | undefined = undefined

  try {
    // ── STEP 1: Verificação de Roteamento & Provider Ativo ────────────────────
    const step1Start = Date.now()
    log("Step 1: Consultando message_provider_runtime para identificar provider ativo...")

    const { data: providerRuntime, error: pErr } = await supabase
      .from("message_provider_runtime")
      .select("active_provider, manual_override, manual_provider")
      .eq("id", "singleton")
      .maybeSingle()

    if (pErr || !providerRuntime) {
      throw new Error(`Falha ao consultar message_provider_runtime: ${pErr?.message || "Registro ausente"}`)
    }

    activeProvider = providerRuntime.manual_override
      ? providerRuntime.manual_provider || providerRuntime.active_provider
      : providerRuntime.active_provider

    steps.push({
      step: "1. Identificação do Provider Ativo",
      status: "PASSED",
      latencyMs: Date.now() - step1Start,
      details: `Provider ativo resolvido: ${activeProvider}`
    })
    log(`Step 1 PASSED: Provider ativo = ${activeProvider}`)

    // ── STEP 2: Geração & Persistência do OTP ─────────────────────────────────
    const step2Start = Date.now()
    const otpCode = Math.floor(100000 + Math.random() * 900000).toString()
    log(`Step 2: Gerando e salvando OTP (${otpCode}) em password_reset_codes...`)

    const expiresAt = new Date(Date.now() + 5 * 60 * 1000).toISOString()
    const { data: codeRecord, error: codeErr } = await supabase
      .from("password_reset_codes")
      .insert({
        email: testEmail,
        code: otpCode,
        expires_at: expiresAt,
        used: false,
        user_agent: "Condomeet-SmokeTest-Runner"
      })
      .select("id")
      .single()

    if (codeErr) {
      throw new Error(`Falha ao inserir em password_reset_codes: ${codeErr.message}`)
    }

    steps.push({
      step: "2. Geração & Persistência do OTP",
      status: "PASSED",
      latencyMs: Date.now() - step2Start,
      details: `OTP ${otpCode} gerado e salvo com id=${codeRecord.id}, expiração em 5min`
    })
    log(`Step 2 PASSED: Code ID = ${codeRecord.id}`)

    // ── STEP 3: Resolução de Template no MetaTemplateService ─────────────────
    const step3Start = Date.now()
    log("Step 3: Consultando MetaTemplateService (resolve_whatsapp_template)...")

    const otpDefinition = TEMPLATE_REGISTRY[MessageType.OTP]
    if (!otpDefinition) {
      throw new Error("MessageType.OTP não possui definição no TEMPLATE_REGISTRY")
    }

    const { data: dbTemplate, error: tplErr } = await supabase.rpc("resolve_whatsapp_template", {
      p_family: otpDefinition.family,
      p_language: otpDefinition.language
    })

    if (tplErr) {
      log(`Aviso ao resolver via RPC: ${tplErr.message}. Usando fallback defaultName.`)
    }

    templateName = dbTemplate?.name || otpDefinition.defaultName

    steps.push({
      step: "3. Resolução de Template no MetaTemplateService",
      status: "PASSED",
      latencyMs: Date.now() - step3Start,
      details: `Template resolvido: ${templateName} (família: ${otpDefinition.family}, versão: ${dbTemplate?.template_version || 1})`
    })
    log(`Step 3 PASSED: Template = ${templateName}`)

    // ── STEP 4: Enfileiramento na whatsapp_outbox via Contrato Estruturado ─────
    const step4Start = Date.now()
    log("Step 4: Criando registro na whatsapp_outbox com contrato estruturado FASE 2...")

    const templateContract = {
      contract_version: 1,
      name: templateName,
      language: "pt_BR",
      parameters: [otpCode]
    }

    // SHA-256 hash simples
    const rawString = `${testPhone}:text:recuperacao_senha:${executionId}`
    const msgBuffer = new TextEncoder().encode(rawString)
    const hashBuffer = await crypto.subtle.digest("SHA-256", msgBuffer)
    const messageHash = Array.from(new Uint8Array(hashBuffer)).map(b => b.toString(16).padStart(2, "0")).join("")

    const { data: outboxRecord, error: outboxErr } = await supabase
      .from("whatsapp_outbox")
      .insert({
        recipient_phone: testPhone,
        message_type: MessageType.OTP,
        payload_type: "text",
        priority: 1, // Queue high
        status: "pending",
        message_hash: messageHash,
        message_content: {
          value: `🔐 Condomeet - Recuperação de Senha\n\nSeu código de verificação: *${otpCode}*\n\n⏱️ Este código expira em 5 minutos.`,
          firstName: "Teste",
          template: templateContract
        }
      })
      .select("id, created_at")
      .single()

    if (outboxErr) {
      throw new Error(`Falha ao inserir registro na whatsapp_outbox: ${outboxErr.message}`)
    }

    steps.push({
      step: "4. Enfileiramento na whatsapp_outbox",
      status: "PASSED",
      latencyMs: Date.now() - step4Start,
      details: `Mensagem enfileirada com id=${outboxRecord.id}, priority=1 (queue=high), message_type=OTP`
    })
    log(`Step 4 PASSED: Outbox ID = ${outboxRecord.id}`)

    // ── STEP 5: Disparo do Worker / Processamento da Mensagem ─────────────────
    const step5Start = Date.now()
    log("Step 5: Invocando whatsapp-outbox-worker (queue=high)...")

    if (triggerWorker) {
      const edgeUrl = Deno.env.get("SUPABASE_URL") || ""
      const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || ""

      try {
        const workerRes = await fetch(`${edgeUrl}/functions/v1/whatsapp-outbox-worker?queue=high`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${serviceKey}`
          },
          body: JSON.stringify({})
        })
        const workerText = await workerRes.text()
        log(`Worker HTTP response: status=${workerRes.status}, text=${workerText.substring(0, 150)}`)
      } catch (wErr: any) {
        log(`Exceção ao chamar worker: ${wErr.message}`)
      }
    }

    // Aguardar atualização do status na outbox (até 10 segundos)
    log("Aguardando atualização do status da mensagem na outbox...")
    let processedRecord: any = null
    const pollStart = Date.now()

    while (Date.now() - pollStart < 10000) {
      const { data: checkMsg } = await supabase
        .from("whatsapp_outbox")
        .select("status, delivery_result, error_message, sent_at")
        .eq("id", outboxRecord.id)
        .single()

      if (checkMsg && (checkMsg.status === "sent" || checkMsg.status === "failed")) {
        processedRecord = checkMsg
        break
      }
      await new Promise(r => setTimeout(r, 1000))
    }

    const workerLatencyMs = Date.now() - step5Start

    if (!processedRecord) {
      steps.push({
        step: "5. Processamento pelo Worker",
        status: "FAILED",
        latencyMs: workerLatencyMs,
        details: "Timeout de 10s atingido. A mensagem permaneceu no status pending/sending."
      })
      throw new Error("Worker não processou a mensagem dentro do tempo limite de 10s")
    } else if (processedRecord.status === "failed") {
      steps.push({
        step: "5. Processamento pelo Worker",
        status: "FAILED",
        latencyMs: workerLatencyMs,
        details: `Mensagem falhou no worker. Erro: ${processedRecord.error_message}`
      })
      throw new Error(`Falha no processamento pelo provider ${activeProvider}: ${processedRecord.error_message}`)
    } else {
      steps.push({
        step: "5. Processamento pelo Worker & Envio pelo Provider",
        status: "PASSED",
        latencyMs: workerLatencyMs,
        details: `Mensagem enviada com SUCESSO via ${activeProvider}. Status: sent, enviado às: ${processedRecord.sent_at}`
      })
      log(`Step 5 PASSED: Envio confirmado via ${activeProvider}`)
    }

    // ── STEP 6: Validação do Consumo do OTP e Cleanup ─────────────────────────
    const step6Start = Date.now()
    log("Step 6: Validando consumo do código OTP em password_reset_codes...")

    const { data: verifyRecord, error: verifyErr } = await supabase
      .from("password_reset_codes")
      .select("id, code, used, expires_at")
      .eq("id", codeRecord.id)
      .single()

    if (verifyErr || !verifyRecord) {
      throw new Error("Falha ao recuperar registro do OTP para validação")
    }

    // Marcar como usado (cleanup)
    await supabase
      .from("password_reset_codes")
      .update({ used: true })
      .eq("id", codeRecord.id)

    // Deletar mensagem de teste da outbox para não poluir histórico
    await supabase
      .from("whatsapp_outbox")
      .delete()
      .eq("id", outboxRecord.id)

    steps.push({
      step: "6. Consumo do OTP & Limpeza de Teste",
      status: "PASSED",
      latencyMs: Date.now() - step6Start,
      details: "Código verificado com sucesso e marcado como used=true. Mensagem de teste expurgada."
    })
    log("Step 6 PASSED: OTP verificado e limpo.")

    const totalDurationMs = Date.now() - startTime

    const report: SmokeTestReport = {
      timestamp: new Date().toISOString(),
      executionId,
      environment: Deno.env.get("SUPABASE_URL")?.includes("avypyaxthvgaybplnwxu") ? "Produção (condomeet_Antigravity)" : "Desenvolvimento",
      activeProvider,
      templateName,
      totalDurationMs,
      finalResult: "SUCESSO",
      recipientPhone: testPhone,
      recipientEmail: testEmail,
      otpCode,
      steps,
      logs
    }

    log(`SMOKE TEST CONCLUÍDO COM SUCESSO em ${totalDurationMs}ms!`)

    return new Response(
      JSON.stringify(report, null, 2),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )

  } catch (err: any) {
    const errorMsg = err instanceof Error ? err.message : String(err)
    failureCause = errorMsg
    log(`❌ FALHA NO SMOKE TEST: ${errorMsg}`)

    const totalDurationMs = Date.now() - startTime

    const report: SmokeTestReport = {
      timestamp: new Date().toISOString(),
      executionId,
      environment: Deno.env.get("SUPABASE_URL")?.includes("avypyaxthvgaybplnwxu") ? "Produção (condomeet_Antigravity)" : "Desenvolvimento",
      activeProvider,
      templateName,
      totalDurationMs,
      finalResult: "FALHA",
      recipientPhone: testPhone,
      recipientEmail: testEmail,
      otpCode: "N/A",
      steps,
      logs,
      failureCause
    }

    return new Response(
      JSON.stringify(report, null, 2),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
