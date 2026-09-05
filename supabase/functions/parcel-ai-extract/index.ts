import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ── CORS Headers ─────────────────────────────────────────────────────────────
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ── Configuration ────────────────────────────────────────────────────────────
const MODEL_ID = "gemini-2.5-flash-lite";
const MAX_PAYLOAD_BYTES = 7 * 1024 * 1024; // ~7MB base64 string (~5MB binary image)
const GEMINI_TIMEOUT_MS = 15000; // 15 seconds timeout

// ── System Prompt & Strict Extraction Rules ──────────────────────────────────
const SYSTEM_PROMPT = `Você é um extrator óptico de dados (OCR) de alta precisão especializado em interpretar identificações de unidades residenciais (Bloco/Torre/Quadra e Apartamento/Casa/Lote) em etiquetas de encomendas e pacotes residenciais.

Sua tarefa é extrair exclusivamente o BLOCO e o APARTAMENTO/UNIDADE presentes na imagem, interpretando a estrutura visual e textual da etiqueta mesmo quando não constarem palavras explícitas como "Bloco" ou "Apto".

============================================================
HIERARQUIA DE LEITURA E INTERPRETAÇÃO SEMÂNTICA
============================================================

1. PRIORIDADE 1 — IDENTIFICAÇÃO EXPLÍCITA:
   Quando houver identificadores claros (Bloco, Bl., BL, Torre, Apto, Apt, Ap, Apartamento, Unidade, Un., Casa, Quadra, Qd., Q, Lote, Lt., L), extraia os dados limpos:
   - "Bloco B Apto 301" -> bloco: "B", apartamento: "301"
   - "BL 36 AP 302" -> bloco: "36", apartamento: "302"
   - "TORRE ALFA AP 201" -> bloco: "Alfa", apartamento: "201"
   - "QUADRA 12 LOTE 04" -> bloco: "12", apartamento: "4"

2. PRIORIDADE 2 — PADRÕES ALFANUMÉRICOS CONCATENADOS (E-COMMERCE):
   Reconheça combinações onde o número do apartamento e a letra do bloco estejam unidos por sufixo, prefixo ou separador:
   - "301B", "301-B", "301/B", "301 B" -> bloco: "B", apartamento: "301"
   - "B301", "B-301", "B/301", "B 301" -> bloco: "B", apartamento: "301"
   - Extraia a letra como bloco e o número como apartamento.

3. PRIORIDADE 3 — BLOCO NOMINAL / TEXTUAL:
   Blocos podem ser palavras ou nomes (ex: Alfa, Gama, Sul, Norte, Flores).
   - "ALFA 201", "ALFA / 201", "BL ALFA 201" -> bloco: "Alfa", apartamento: "201"
   - Extraia a palavra como bloco e o número como apartamento.

4. PRIORIDADE 4 — CONDOMÍNIO HORIZONTAL (QUADRA E LOTE/CASA):
   Em loteamentos e condomínios de casas:
   - "QD 12 LT 4", "Q12 L04", "Casa 15 Quadra 2" -> bloco: "12" (Quadra), apartamento: "4" (Lote/Casa)

5. PRIORIDADE 5 — PADRÕES PURAMENTE NUMÉRICOS (EXIGE CONTEXTO SEGURO):
   NÃO interprete automaticamente qualquer par de números aleatórios como Bloco + Apartamento.
   Apenas interprete pares numéricos (ex: "36 302", "36/302", "36-302") quando houver contexto claro de endereço/complemento residencial na etiqueta (ex: campo "Complemento", linha de endereço ou delimitador claro).
   - Com contexto seguro: "36/302" ou "Complemento: 36 302" -> bloco: "36", apartamento: "302".
   - Sem contexto de unidade ou ambíguo: NÃO assuma bloco.

6. LEITURA DE ENDEREÇO E COMPLEMENTO:
   Analise com atenção os campos "Complemento", "Dados de Entrega", "Observações", linhas próximas ao destinatário e o final da linha de endereço.
   - Exemplo: "Complemento: 301B" -> bloco: "B", apartamento: "301".

============================================================
REGRAS ABSOLUTAS DE NÃO-INVENÇÃO (ZERO ALUCINAÇÃO)
============================================================
1. NUNCA invente, deduza ou adivinhe informações ausentes na imagem.
2. Se apenas o apartamento estiver visível (ex: "301" ou "Apto 301"): retorne bloco: null, apartamento: "301". NUNCA deduza um bloco.
3. Se apenas o bloco estiver visível (ex: "Bloco B"): retorne bloco: "B", apartamento: null.
4. Uma letra isolada sem contexto (ex: "B") NÃO deve ser transformada em unidade.
5. Números cortados, borrados ou parcialmente visíveis NUNCA devem ser completados -> retorne null para o campo ilegível.
6. Se a imagem for ilegível ou não contiver etiqueta: retorne bloco: null, apartamento: null, leitura_ok: false e confianca baixa (0.0 a 0.2).
7. NORMALIZAÇÃO LIMPA: Retorne apenas o identificador essencial (ex: bloco: "B", apartamento: "301"; e NÃO "Bloco B" ou "Apto 301").`;

// ── JSON Schema Definition for Gemini Structured Output ──────────────────────
const RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    leitura_ok: {
      type: "BOOLEAN",
      description: "True se pelo menos o bloco ou apartamento foi identificado com clareza na imagem.",
    },
    bloco: {
      type: "STRING",
      nullable: true,
      description: "Identificador do bloco/torre extraído da etiqueta ou null se ausente/ilegível.",
    },
    apartamento: {
      type: "STRING",
      nullable: true,
      description: "Número do apartamento/unidade extraído da etiqueta ou null se ausente/ilegível.",
    },
    confianca: {
      type: "NUMBER",
      description: "Grau de certeza da leitura visual, variando de 0.0 a 1.0.",
    },
  },
  required: ["leitura_ok", "confianca"],
};

// ── Helper: JSON Response Builder ────────────────────────────────────────────
function jsonResponse(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

// ── Helper: Sanitize Strings ─────────────────────────────────────────────────
function sanitizeField(val: unknown): string | null {
  if (typeof val !== "string") return null;
  const trimmed = val.trim();
  if (
    !trimmed ||
    trimmed.toLowerCase() === "null" ||
    trimmed.toLowerCase() === "none" ||
    trimmed.toLowerCase() === "n/a" ||
    trimmed.toLowerCase() === "indefinido" ||
    trimmed === "?" ||
    trimmed === "-"
  ) {
    return null;
  }
  return trimmed;
}

// ── Main Handler ─────────────────────────────────────────────────────────────
Deno.serve(async (req: Request) => {
  const startTime = Date.now();

  // 1. CORS Preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse(405, {
      leitura_ok: false,
      bloco: null,
      apartamento: null,
      confianca: 0.0,
      error: "Método não permitido. Utilize POST.",
      fallback_manual: true,
    });
  }

  try {
    // 2. Authentication Verification
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse(401, {
        leitura_ok: false,
        bloco: null,
        apartamento: null,
        confianca: 0.0,
        error: "UNAUTHORIZED: Token de autenticação não fornecido.",
        fallback_manual: true,
      });
    }

    const token = authHeader.replace("Bearer ", "").trim();
    if (!token) {
      return jsonResponse(401, {
        leitura_ok: false,
        bloco: null,
        apartamento: null,
        confianca: 0.0,
        error: "UNAUTHORIZED: Formato de token inválido.",
        fallback_manual: true,
      });
    }

    // Token existence already validated above

    // 3. Payload Validation & Size Check
    let bodyText: string;
    try {
      bodyText = await req.text();
    } catch {
      return jsonResponse(400, {
        leitura_ok: false,
        bloco: null,
        apartamento: null,
        confianca: 0.0,
        error: "Erro ao processar o corpo da requisição.",
        fallback_manual: true,
      });
    }

    if (bodyText.length > MAX_PAYLOAD_BYTES) {
      return jsonResponse(413, {
        leitura_ok: false,
        bloco: null,
        apartamento: null,
        confianca: 0.0,
        error: "PAYLOAD_TOO_LARGE: Imagem excede o limite máximo permitido (5MB).",
        fallback_manual: true,
      });
    }

    let parsedBody: Record<string, unknown>;
    try {
      parsedBody = JSON.parse(bodyText);
    } catch {
      return jsonResponse(400, {
        leitura_ok: false,
        bloco: null,
        apartamento: null,
        confianca: 0.0,
        error: "JSON inválido no corpo da requisição.",
        fallback_manual: true,
      });
    }

    let imageBase64 = typeof parsedBody.image_base64 === "string" ? parsedBody.image_base64.trim() : "";
    if (!imageBase64) {
      return jsonResponse(400, {
        leitura_ok: false,
        bloco: null,
        apartamento: null,
        confianca: 0.0,
        error: "O campo 'image_base64' é obrigatório.",
        fallback_manual: true,
      });
    }

    // 4. Clean Base64 and Detect MIME Type
    let mimeType = "image/jpeg";
    if (imageBase64.startsWith("data:")) {
      const commaIdx = imageBase64.indexOf(",");
      if (commaIdx !== -1) {
        const header = imageBase64.substring(5, commaIdx);
        if (header.includes("image/png")) mimeType = "image/png";
        else if (header.includes("image/webp")) mimeType = "image/webp";
        else if (header.includes("image/gif")) mimeType = "image/gif";
        else if (header.includes("image/jpeg") || header.includes("image/jpg")) mimeType = "image/jpeg";
        imageBase64 = imageBase64.substring(commaIdx + 1);
      }
    } else {
      if (imageBase64.startsWith("iVBOR")) mimeType = "image/png";
      else if (imageBase64.startsWith("UklGR")) mimeType = "image/webp";
      else if (imageBase64.startsWith("R0lGOD")) mimeType = "image/gif";
      else if (imageBase64.startsWith("/9j/")) mimeType = "image/jpeg";
    }

    // 5. Secret Key Verification
    const geminiKey = Deno.env.get("GEMINI_API_KEY") || Deno.env.get("GOOGLE_AI_API_KEY");
    if (!geminiKey) {
      console.error("[parcel-ai-extract] GEMINI_API_KEY não configurada no ambiente servidor.");
      return jsonResponse(500, {
        leitura_ok: false,
        bloco: null,
        apartamento: null,
        confianca: 0.0,
        error: "Serviço de IA indisponível (chave não configurada).",
        fallback_manual: true,
      });
    }

    // 6. Dynamic Gemini Model Resolution & Call
    const geminiPayload = {
      contents: [
        {
          parts: [
            { text: SYSTEM_PROMPT },
            {
              inline_data: {
                mime_type: mimeType,
                data: imageBase64,
              },
            },
          ],
        },
      ],
      generationConfig: {
        temperature: 0.0,
        responseMimeType: "application/json",
        responseSchema: RESPONSE_SCHEMA,
      },
    };

    let selectedModel = "models/gemini-2.5-flash";
    let availableModelNames: string[] = [];
    try {
      const listRes = await fetch(`https://generativelanguage.googleapis.com/v1beta/models?key=${geminiKey}`);
      if (listRes.ok) {
        const listData = await listRes.json();
        const availableModels: Array<{ name: string; supportedGenerationMethods?: string[] }> = listData.models || [];
        availableModelNames = availableModels.map((m) => m.name);
        const preferred = availableModels.find(
          (m) =>
            m.supportedGenerationMethods?.includes("generateContent") &&
            (m.name.includes("flash") || m.name.includes("gemini"))
        );
        if (preferred) {
          selectedModel = preferred.name.startsWith("models/") ? preferred.name : `models/${preferred.name}`;
        }
      }
    } catch (listErr) {
      console.warn("[parcel-ai-extract] Model list warning, using default:", listErr);
    }

    const geminiEndpoint = `https://generativelanguage.googleapis.com/v1beta/${selectedModel}:generateContent?key=${geminiKey}`;
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), GEMINI_TIMEOUT_MS);

    let geminiResponse: Response;
    try {
      geminiResponse = await fetch(geminiEndpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(geminiPayload),
        signal: controller.signal,
      });
    } catch (fetchErr: unknown) {
      clearTimeout(timeoutId);
      const isTimeout = fetchErr instanceof Error && fetchErr.name === "AbortError";
      const errMsg = fetchErr instanceof Error ? fetchErr.message : String(fetchErr);
      console.error(`[parcel-ai-extract] Erro ao chamar ${selectedModel}:`, isTimeout ? "Timeout" : fetchErr);
      return jsonResponse(504, {
        leitura_ok: false,
        bloco: null,
        apartamento: null,
        confianca: 0.0,
        error: isTimeout ? "Timeout ao analisar a foto." : `Erro de comunicação com o serviço de IA: ${errMsg}`,
        fallback_manual: true,
      });
    } finally {
      clearTimeout(timeoutId);
    }

    if (!geminiResponse.ok) {
      const errText = await geminiResponse.text();
      console.error(`[parcel-ai-extract] Gemini API error HTTP ${geminiResponse.status}:`, errText);
      return jsonResponse(502, {
        leitura_ok: false,
        bloco: null,
        apartamento: null,
        confianca: 0.0,
        error: `Serviço de IA retornou erro HTTP ${geminiResponse.status}.`,
        fallback_manual: true,
      });
    }

    // 7. Parse & Validate Gemini Response
    const geminiData = await geminiResponse.json();
    const rawText = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text || "{}";

    let parsedResult: Record<string, unknown>;
    try {
      parsedResult = JSON.parse(rawText);
    } catch {
      console.error("[parcel-ai-extract] Falha no parse do JSON do Gemini:", rawText);
      return jsonResponse(200, {
        leitura_ok: false,
        bloco: null,
        apartamento: null,
        confianca: 0.0,
        error: "Resposta da IA em formato inválido.",
        fallback_manual: true,
      });
    }

    // 8. Sanitize & Structure Output
    const bloco = sanitizeField(parsedResult.bloco);
    const apartamento = sanitizeField(parsedResult.apartamento);
    let confianca = typeof parsedResult.confianca === "number" ? parsedResult.confianca : 0.0;
    confianca = Math.max(0.0, Math.min(1.0, confianca));

    // Determine leitura_ok strictly
    const hasAnyField = bloco !== null || apartamento !== null;
    const leituraOk = Boolean(parsedResult.leitura_ok) && hasAnyField && confianca >= 0.35;

    // Tokens & Performance Metrics
    const latencyMs = Date.now() - startTime;
    const usage = geminiData?.usageMetadata || {};
    const tokens = {
      prompt: usage.promptTokenCount || 0,
      candidates: usage.candidatesTokenCount || 0,
      total: usage.totalTokenCount || 0,
    };

    // Structured Log (Sanitized — zero sensitive data or image contents)
    console.log(
      `[parcel-ai-extract] Concluído em ${latencyMs}ms | status=200 | leitura_ok=${leituraOk} | bloco=${bloco ?? "null"} | apto=${apartamento ?? "null"} | confianca=${confianca.toFixed(2)} | tokens_in=${tokens.prompt} | tokens_out=${tokens.candidates}`
    );

    return jsonResponse(200, {
      leitura_ok: leituraOk,
      bloco: bloco,
      apartamento: apartamento,
      confianca: Number(confianca.toFixed(2)),
      latency_ms: latencyMs,
      tokens,
    });
  } catch (globalErr: unknown) {
    const latencyMs = Date.now() - startTime;
    console.error("[parcel-ai-extract] Erro não tratado:", globalErr);
    return jsonResponse(500, {
      leitura_ok: false,
      bloco: null,
      apartamento: null,
      confianca: 0.0,
      latency_ms: latencyMs,
      error: "Erro interno durante o processamento da imagem.",
      fallback_manual: true,
    });
  }
});
