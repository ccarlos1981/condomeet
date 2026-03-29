import "jsr:@supabase/functions-js/edge-runtime.d.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

// ── Gemini Vision OCR for Receipts ──────────────────────────────────────────
// Uses Gemini 2.0 Flash (free) for intelligent receipt parsing
// Returns structured JSON with items, supermarket info, etc.

interface ParsedItem {
  raw_text: string
  name: string
  quantity: number
  unit_price: number
  total_price: number
}

const GEMINI_PROMPT = `Analise esta imagem de um cupom fiscal brasileiro (NFC-e / cupom de supermercado).

Extraia as seguintes informações e retorne APENAS um JSON válido, sem markdown, sem explicações:

{
  "supermarket_name": "Nome do supermercado (string ou null)",
  "cnpj": "CNPJ do estabelecimento (string ou null)",
  "date": "Data da compra DD/MM/YYYY (string ou null)",
  "total": numero_total_da_compra_ou_null,
  "items": [
    {
      "raw_text": "texto original da linha do item",
      "name": "nome do produto limpo e legível (exclua a marca e peso)",
      "brand": "apenas o nome da marca (ex: NESTLÉ, SADIA) ou null",
      "weight_label": "tamanho ou peso (ex: 1KG, 500G, 2L) ou null",
      "quantity": quantidade_numerica,
      "unit_price": preco_unitario_numerico,
      "total_price": preco_total_do_item_numerico
    }
  ]
}

Regras:
- Inclua TODOS os itens/produtos encontrados
- Ignore linhas de subtotal, troco, forma pagamento, tributos, chaves de acesso
- Preços devem ser números decimais (ex: 12.99, não "12,99")
- Se a marca ou peso estiverem no raw_text do item fiscal, separe para os campos brand e weight_label. Deixe null caso contrário.
- Se não conseguir identificar um campo, use null
- Se a quantidade não for clara, use 1
- Se o preço unitário não for claro, use o preço total
- Retorne APENAS o JSON, nada mais`

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const body = await req.json()
    const { image_base64, receipt_text } = body

    console.log("[OCR] Request received:", {
      has_image: !!image_base64,
      image_length: image_base64?.length ?? 0,
      has_receipt_text: !!receipt_text,
    })

    // If raw text provided, parse it directly (legacy support)
    if (receipt_text && !image_base64) {
      const result = parseReceiptTextFallback(receipt_text)
      return jsonResponse(200, {
        ...result,
        method: "text_fallback",
      })
    }

    if (!image_base64) {
      return jsonResponse(400, { error: "No image or receipt_text provided" })
    }

    // ── Use Gemini Vision API (free) ────────────────────────────────────
    const geminiKey = Deno.env.get("GEMINI_API_KEY") || Deno.env.get("GOOGLE_AI_API_KEY")
    
    if (!geminiKey) {
      console.error("[OCR] No Gemini API key found. Set GEMINI_API_KEY in Edge Function secrets.")
      return jsonResponse(500, { 
        error: "GEMINI_API_KEY não configurada. Configure nas secrets das Edge Functions.",
        setup: "Obtenha a chave em https://aistudio.google.com/apikey e adicione como GEMINI_API_KEY nos secrets."
      })
    }

    console.log("[OCR] Calling Gemini Vision API...")

    // Detect MIME type from base64 header or default to jpeg
    let mimeType = "image/jpeg"
    if (image_base64.startsWith("/9j/")) mimeType = "image/jpeg"
    else if (image_base64.startsWith("iVBOR")) mimeType = "image/png"
    else if (image_base64.startsWith("R0lGOD")) mimeType = "image/gif"

    // --- Dynamically find an available model ---
    const listRes = await fetch(`https://generativelanguage.googleapis.com/v1beta/models?key=${geminiKey}`);
    if (!listRes.ok) {
      throw new Error(`Failed to list Gemini models: ${await listRes.text()}`);
    }
    const listData = await listRes.json();
    const availableModels = listData.models || [];
    
    // Prefer flash, then pro-vision, then just fallback to anything that supports generateContent
    let targetModel = availableModels.find((m: any) => m.name.includes("flash") && m.supportedGenerationMethods?.includes("generateContent"));
    if (!targetModel) {
      targetModel = availableModels.find((m: any) => m.name.includes("pro-vision") && m.supportedGenerationMethods?.includes("generateContent"));
    }
    if (!targetModel) {
       targetModel = availableModels.find((m: any) => m.supportedGenerationMethods?.includes("generateContent"));
    }

    if (!targetModel) {
      throw new Error(`No compatible Gemini models found. Available: ${availableModels.map((m:any) => m.name).join(", ")}`);
    }

    // Ensure it has the "models/" prefix
    const modelName = targetModel.name.startsWith("models/") ? targetModel.name : `models/${targetModel.name}`;
    console.log(`[OCR] Dynamically selected Gemini model: ${modelName}`);

    // --- Call Gemini API ---
    const geminiRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/${modelName}:generateContent?key=${geminiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{
            parts: [
              { text: GEMINI_PROMPT },
              {
                inline_data: {
                  mime_type: mimeType,
                  data: image_base64,
                },
              },
            ],
          }],
          generationConfig: {
            temperature: 0.1,
            maxOutputTokens: 4096,
            responseMimeType: "application/json",
          },
        }),
      }
    )

    if (!geminiRes.ok) {
      const errText = await geminiRes.text()
      console.error("[OCR] Gemini API error:", geminiRes.status, errText.substring(0, 500))
      return jsonResponse(502, { 
        error: "Gemini Vision API error", 
        status: geminiRes.status,
        detail: errText.substring(0, 300),
      })
    }

    const geminiData = await geminiRes.json()
    console.log("[OCR] Gemini response received")

    // Extract the JSON text from Gemini response
    const responseText = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text
    
    if (!responseText) {
      console.error("[OCR] No text in Gemini response:", JSON.stringify(geminiData).substring(0, 500))
      
      // Check for safety blocks
      const blockReason = geminiData?.candidates?.[0]?.finishReason
      if (blockReason === "SAFETY") {
        return jsonResponse(400, { error: "A imagem foi bloqueada pelo filtro de segurança. Tente outra foto." })
      }
      
      return jsonResponse(400, { error: "Gemini não conseguiu ler o cupom. Tente uma foto mais nítida." })
    }

    console.log("[OCR] Parsing Gemini JSON response, length:", responseText.length)

    // Safety logic depending on API response format
    if (geminiData.promptFeedback?.blockReason) {
      console.error("[OCR] Gemini blocked the request", geminiData.promptFeedback)
      return new Response(JSON.stringify({ error: "A imagem foi bloqueada pelas politicas de seguranca." }), { status: 400 })
    }

    if (!geminiData.candidates || geminiData.candidates.length === 0) {
      console.error("[OCR] Gemini returned 200, but no candidates found", geminiData)
      return new Response(JSON.stringify({ error: "Nao foi possivel identificar o conteudo da imagem." }), { status: 400 })
    }

    const textContent = geminiData.candidates[0].content.parts[0].text
    if (!textContent) {
      return new Response(JSON.stringify({ error: "Nao foi possivel extrair texto da imagem." }), { status: 400 })
    }

    let parsed = null
    try {
      // Find JSON block within markdown if it exists (fallback if Gemini ignores responseMimeType)
      const match = textContent.match(/```(?:json)?\s*([\s\S]*?)\s*```/)
      const cleanJsonStr = match ? match[1] : textContent.trim()
      parsed = JSON.parse(cleanJsonStr)
    } catch (parseErr) {
      console.error("[OCR] Fallback: Could not parse strict JSON, returning raw text text", textContent)
      // If it's not JSON, we return the error to the user AND the raw text so we can see what Gemini said!
      return new Response(JSON.stringify({ 
        error: "Não foi possível interpretar a resposta. Tente novamente com uma foto mais clara.",
        geminiRawText: textContent
      }), { status: 400 })
    }

    // Validate and normalize the response
    const items: ParsedItem[] = (parsed.items || []).map((item: any) => ({
      raw_text: item.raw_text || item.name || "",
      name: item.name || "Produto",
      quantity: Number(item.quantity) || 1,
      unit_price: Number(item.unit_price) || Number(item.total_price) || 0,
      total_price: Number(item.total_price) || Number(item.unit_price) || 0,
    })).filter((item: ParsedItem) => item.unit_price > 0 || item.total_price > 0)

    console.log("[OCR] Successfully parsed", items.length, "items from receipt")

    // Try to match supermarket in DB
    const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2")
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    )

    let matched_supermarket_id: string | null = null

    // Match by CNPJ first
    if (parsed.cnpj) {
      const cleanCnpj = parsed.cnpj.replace(/[^\d]/g, "")
      const { data: marketByCnpj } = await supabase
        .from("lista_supermarkets")
        .select("id, name")
        .eq("cnpj", cleanCnpj)
        .maybeSingle()
      if (marketByCnpj) {
        matched_supermarket_id = marketByCnpj.id
        console.log("[OCR] Matched market by CNPJ:", marketByCnpj.name)
      }
    }

    // Fallback: match by name
    if (!matched_supermarket_id && parsed.supermarket_name) {
      const searchName = parsed.supermarket_name.substring(0, 15).trim()
      const { data: marketByName } = await supabase
        .from("lista_supermarkets")
        .select("id, name")
        .ilike("name", `%${searchName}%`)
        .limit(1)
      if (marketByName?.length) {
        matched_supermarket_id = marketByName[0].id
        console.log("[OCR] Matched market by name:", marketByName[0].name)
      }
    }

    return jsonResponse(200, {
      items,
      supermarket_name: parsed.supermarket_name || null,
      matched_supermarket_id,
      cnpj: parsed.cnpj || null,
      date: parsed.date || null,
      total: parsed.total != null ? Number(parsed.total) : null,
      items_count: items.length,
      method: "gemini_vision",
    })

  } catch (err: any) {
    console.error("[OCR] Unexpected error:", err.message, err.stack)
    return jsonResponse(500, { error: err.message })
  }
})

// ── Helper: JSON Response ───────────────────────────────────────────────────
function jsonResponse(status: number, data: any) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  })
}

// ── Fallback: Simple text parser (for legacy/text input) ────────────────────
function parseReceiptTextFallback(ocrText: string) {
  const lines = ocrText.split("\n").map(l => l.trim()).filter(l => l.length > 2)

  let supermarket_name: string | null = null
  for (const line of lines.slice(0, 5)) {
    const clean = line.replace(/[^A-Za-zÀ-ÿ\s]/g, "").trim()
    if (clean.length > 5 && !clean.match(/^(CNPJ|CPF|NOTA|NFC|CUPOM|FISCAL|SAT)/i)) {
      supermarket_name = clean
      break
    }
  }

  const cnpjMatch = ocrText.match(/CNPJ[:\s]*(\d{2}\.?\d{3}\.?\d{3}\/?0001-?\d{2})/i)
  const dateMatch = ocrText.match(/(\d{2}\/\d{2}\/\d{4})/)
  const totalMatch = ocrText.match(/TOTAL\s*(?:R\$)?\s*(\d+[.,]\d{2})/i)

  const items: ParsedItem[] = []
  for (const line of lines) {
    if (line.match(/^(CNPJ|CPF|NOTA|NFC|CUPOM|FISCAL|SAT|TOTAL|SUBTOTAL|TROCO|DINHEIRO|CARTAO)/i)) continue
    if (line.match(/^[-=*_]+$/)) continue

    const match = line.match(/^(\d{0,4}\s*)?(.+?)\s+(\d+[.,]\d{2})$/i)
    if (match) {
      const name = match[2].trim()
      const price = parseFloat(match[3].replace(",", "."))
      if (name.length > 2 && price > 0 && price < 9999) {
        items.push({ raw_text: line, name, quantity: 1, unit_price: price, total_price: price })
      }
    }
  }

  return {
    items,
    supermarket_name,
    cnpj: cnpjMatch ? cnpjMatch[1] : null,
    date: dateMatch ? dateMatch[1] : null,
    total: totalMatch ? parseFloat(totalMatch[1].replace(",", ".")) : null,
    items_count: items.length,
  }
}
