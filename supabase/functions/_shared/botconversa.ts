// _shared/botconversa.ts — Shared BotConversa API utilities
// Used by: botconversa-send, whatsapp-parcel-notify, and future functions

export const BOTCONVERSA_BASE_URL =
  "https://backend.botconversa.com.br/api/v1/webhook"
export const DELAY_TEXT_MS = 1_000
export const DELAY_FILE_MS = 2_000

export interface BotConversaSendResult {
  success: boolean
  subscriberId: string
  error?: string
}

// ── PNG → JPEG URL rewrite ────────────────────────────────────────────────
// BotConversa/WhatsApp has issues rendering PNGs.

export function ensureJpegUrl(url: string): string {
  if (!url.toLowerCase().endsWith(".png")) return url
  console.log(`[PNG→JPEG] URL rewrite: ${url}`)
  return url.replace(/\.png$/i, ".jpeg")
}

// ── Send text or file message ─────────────────────────────────────────────

export async function sendMessage(
  apiKey: string,
  subscriberId: string,
  tipo: "text" | "file",
  value: string
): Promise<BotConversaSendResult> {
  try {
    const finalValue = tipo === "file" ? ensureJpegUrl(value) : value

    const res = await fetch(
      `${BOTCONVERSA_BASE_URL}/subscriber/${encodeURIComponent(subscriberId)}/send_message/`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "API-KEY": apiKey,
        },
        body: JSON.stringify({ type: tipo, value: finalValue }),
      }
    )

    const resultText = await res.text()
    if (!res.ok) {
      console.error(
        `BotConversa error (${subscriberId}): ${res.status} ${resultText}`
      )
      return { success: false, subscriberId, error: `${res.status}: ${resultText}` }
    }
    return { success: true, subscriberId }
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err)
    console.error(`BotConversa fetch error (${subscriberId}):`, message)
    return { success: false, subscriberId, error: message }
  }
}

// ── Send flow ─────────────────────────────────────────────────────────────

export async function sendFlow(
  apiKey: string,
  subscriberId: string,
  flowId: number
): Promise<BotConversaSendResult> {
  try {
    const res = await fetch(
      `${BOTCONVERSA_BASE_URL}/subscriber/${encodeURIComponent(subscriberId)}/send_flow/`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "API-KEY": apiKey,
        },
        body: JSON.stringify({ flow: flowId }),
      }
    )

    const resultText = await res.text()
    if (!res.ok) {
      console.error(
        `BotConversa flow error (${subscriberId}): ${res.status} ${resultText}`
      )
      return { success: false, subscriberId, error: `${res.status}: ${resultText}` }
    }
    return { success: true, subscriberId }
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err)
    console.error(`BotConversa flow error (${subscriberId}):`, message)
    return { success: false, subscriberId, error: message }
  }
}

// ── Send to multiple recipients sequentially ──────────────────────────────

export async function sendToRecipients(
  apiKey: string,
  recipients: Array<{ botconversa_id: string; nome_completo: string }>,
  msg: string,
  tipo: "text" | "file",
  options?: { flowId?: number; personalizeMsg?: boolean }
): Promise<BotConversaSendResult[]> {
  const delayMs = tipo === "file" ? DELAY_FILE_MS : DELAY_TEXT_MS
  const results: BotConversaSendResult[] = []

  for (let i = 0; i < recipients.length; i++) {
    const recipient = recipients[i]
    let result: BotConversaSendResult

    if (options?.flowId) {
      result = await sendFlow(apiKey, recipient.botconversa_id, options.flowId)
    } else {
      const finalMsg =
        options?.personalizeMsg !== false
          ? msg.replace(
              /\|nome\|/g,
              recipient.nome_completo?.split(" ")[0] || "Morador"
            )
          : msg
      result = await sendMessage(apiKey, recipient.botconversa_id, tipo, finalMsg)
    }

    results.push(result)

    // Rate limit between sends (skip after last)
    if (i < recipients.length - 1) {
      await new Promise((resolve) => setTimeout(resolve, delayMs))
    }
  }

  return results
}
