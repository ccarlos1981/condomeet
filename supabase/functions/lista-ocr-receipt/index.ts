import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

// ── Receipt text parser ─────────────────────────────────────────────────────
// Parses OCR text from Brazilian supermarket receipts (NFC-e / cupom fiscal)
// Lines usually look like: "ARROZ CAMIL T1 5KG          1 UN X 24,99   24,99"
// Or: "001 ARROZ CAMIL T1 5KG   1   24.99"

interface ParsedItem {
  raw_text: string
  name: string
  quantity: number
  unit_price: number
  total_price: number
}

function parseReceiptText(ocrText: string): {
  items: ParsedItem[]
  supermarket_name: string | null
  cnpj: string | null
  date: string | null
  total: number | null
} {
  const lines = ocrText.split("\n").map(l => l.trim()).filter(l => l.length > 2)

  // Extract supermarket name (usually first few lines)
  let supermarket_name: string | null = null
  for (const line of lines.slice(0, 5)) {
    const clean = line.replace(/[^A-Za-zÀ-ÿ\s]/g, "").trim()
    if (clean.length > 5 && !clean.match(/^(CNPJ|CPF|NOTA|NFC|CUPOM|FISCAL|SAT)/i)) {
      supermarket_name = clean
      break
    }
  }

  // Extract CNPJ
  const cnpjMatch = ocrText.match(/CNPJ[:\s]*(\d{2}\.?\d{3}\.?\d{3}\/?0001-?\d{2})/i)
  const cnpj = cnpjMatch ? cnpjMatch[1] : null

  // Extract date
  const dateMatch = ocrText.match(/(\d{2}\/\d{2}\/\d{4})/)
  const date = dateMatch ? dateMatch[1] : null

  // Parse item lines
  const items: ParsedItem[] = []

  // Pattern 1: "ITEM DESCRIPTION    QTY UN X PRICE    TOTAL"
  // Pattern 2: "### ITEM DESCRIPTION    QTY    PRICE"
  // Pattern 3: "ITEM DESCRIPTION R$ PRICE"

  for (const line of lines) {
    // Skip header/footer lines
    if (line.match(/^(CNPJ|CPF|NOTA|NFC|CUPOM|FISCAL|SAT|TOTAL|SUBTOTAL|TROCO|DINHEIRO|CARTAO|CREDITO|DEBITO|CHAVE|PROTOCOLO|CONSUMIDOR|DATA|TRIBUT)/i)) continue
    if (line.match(/^[-=*_]+$/)) continue
    if (line.length < 8) continue

    // Try pattern: "DESCRIPTION  QTY UN X PRICE  TOTAL"
    const match1 = line.match(/^(\d{0,4}\s*)?(.+?)\s+(\d+)\s*(?:UN|KG|PC|LT|ML|GR|CX|PT|FD|SC)\s*[xX]\s*(\d+[.,]\d{2})\s+(\d+[.,]\d{2})$/i)
    if (match1) {
      const name = match1[2].trim()
      const qty = parseInt(match1[3])
      const unit = parseFloat(match1[4].replace(",", "."))
      const total = parseFloat(match1[5].replace(",", "."))
      if (name.length > 2 && unit > 0) {
        items.push({ raw_text: line, name, quantity: qty, unit_price: unit, total_price: total })
        continue
      }
    }

    // Try pattern: "DESCRIPTION  PRICE" (single item, no quantity)
    const match2 = line.match(/^(\d{0,4}\s*)?(.+?)\s+(\d+[.,]\d{2})$/i)
    if (match2) {
      const name = match2[2].trim()
      const price = parseFloat(match2[3].replace(",", "."))
      // Filter out non-product lines
      if (name.length > 2 && price > 0 && price < 9999 && !name.match(/^(TOTAL|SUBTOTAL|TROCO|DINHEIRO|DESCONTO|ACRESCIMO|ITEM|QTD)/i)) {
        items.push({ raw_text: line, name, quantity: 1, unit_price: price, total_price: price })
        continue
      }
    }

    // Try pattern with R$: "DESCRIPTION R$ PRICE"
    const match3 = line.match(/^(\d{0,4}\s*)?(.+?)\s*R\$\s*(\d+[.,]\d{2})/)
    if (match3) {
      const name = match3[2].trim()
      const price = parseFloat(match3[3].replace(",", "."))
      if (name.length > 2 && price > 0 && price < 9999) {
        items.push({ raw_text: line, name, quantity: 1, unit_price: price, total_price: price })
        continue
      }
    }
  }

  // Extract total
  const totalMatch = ocrText.match(/TOTAL\s*(?:R\$)?\s*(\d+[.,]\d{2})/i)
  const total = totalMatch ? parseFloat(totalMatch[1].replace(",", ".")) : null

  return { items, supermarket_name, cnpj, date, total }
}

// ── Main handler ────────────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const { image_base64, receipt_text } = await req.json()

    let ocrText = receipt_text || ""

    // If image provided, use Google Cloud Vision API
    if (image_base64 && !receipt_text) {
      const apiKey = Deno.env.get("GOOGLE_CLOUD_VISION_API_KEY")

      if (apiKey) {
        // Google Cloud Vision OCR
        const visionRes = await fetch(
          `https://vision.googleapis.com/v1/images:annotate?key=${apiKey}`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              requests: [{
                image: { content: image_base64 },
                features: [{ type: "TEXT_DETECTION", maxResults: 1 }],
                imageContext: { languageHints: ["pt"] }
              }]
            })
          }
        )

        const visionData = await visionRes.json()

        if (visionData.responses?.[0]?.fullTextAnnotation?.text) {
          ocrText = visionData.responses[0].fullTextAnnotation.text
        } else if (visionData.responses?.[0]?.error) {
          return new Response(
            JSON.stringify({ error: "OCR failed", detail: visionData.responses[0].error.message }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          )
        }
      } else {
        return new Response(
          JSON.stringify({ error: "GOOGLE_CLOUD_VISION_API_KEY not configured" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        )
      }
    }

    if (!ocrText) {
      return new Response(
        JSON.stringify({ error: "No image or receipt_text provided" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Parse the receipt
    const result = parseReceiptText(ocrText)

    // Try to match supermarket in DB
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    )

    let matched_supermarket_id: string | null = null
    if (result.cnpj) {
      const { data: marketByCnpj } = await supabase
        .from("lista_supermarkets")
        .select("id, name")
        .eq("cnpj", result.cnpj)
        .maybeSingle()
      if (marketByCnpj) matched_supermarket_id = marketByCnpj.id
    }

    if (!matched_supermarket_id && result.supermarket_name) {
      const { data: marketByName } = await supabase
        .from("lista_supermarkets")
        .select("id, name")
        .ilike("name", `%${result.supermarket_name.substring(0, 10)}%`)
        .limit(1)
      if (marketByName?.length) matched_supermarket_id = marketByName[0].id
    }

    return new Response(
      JSON.stringify({
        ocr_text: ocrText,
        items: result.items,
        supermarket_name: result.supermarket_name,
        matched_supermarket_id,
        cnpj: result.cnpj,
        date: result.date,
        total: result.total,
        items_count: result.items.length,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  } catch (err: any) {
    console.error("OCR Error:", err)
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
