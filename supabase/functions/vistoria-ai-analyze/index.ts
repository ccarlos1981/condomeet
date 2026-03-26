import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") || "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { foto_id, foto_url, item_name } = await req.json();

    if (!foto_url) {
      return new Response(
        JSON.stringify({ error: "foto_url é obrigatório" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!GEMINI_API_KEY) {
      return new Response(
        JSON.stringify({ error: "GEMINI_API_KEY não configurada" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Fetch the image and convert to base64
    const imageResponse = await fetch(foto_url);
    const imageBuffer = await imageResponse.arrayBuffer();
    const base64Image = btoa(
      new Uint8Array(imageBuffer).reduce((data, byte) => data + String.fromCharCode(byte), "")
    );
    const mimeType = imageResponse.headers.get("content-type") || "image/jpeg";

    // Call Gemini Vision API
    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${GEMINI_API_KEY}`;

    const prompt = `Você é um inspetor especializado em vistorias de imóveis e bens.
Analise esta foto do item "${item_name || "item de vistoria"}" e forneça uma avaliação técnica.

Responda SOMENTE com um JSON válido no seguinte formato:
{
  "dano_detectado": true/false,
  "severidade": "nenhum" | "leve" | "moderado" | "grave",
  "descricao": "Descrição sucinta do estado do item em português",
  "recomendacao": "Recomendação de ação em português (ou 'Nenhuma ação necessária')",
  "confianca": 0.0 a 1.0
}

Seja preciso e objetivo. Analise sinais de desgaste, danos, manchas, rachaduras, infiltrações, etc.`;

    const geminiResponse = await fetch(geminiUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              { text: prompt },
              {
                inline_data: {
                  mime_type: mimeType,
                  data: base64Image,
                },
              },
            ],
          },
        ],
        generationConfig: {
          temperature: 0.2,
          maxOutputTokens: 500,
        },
      }),
    });

    const geminiData = await geminiResponse.json();
    const textContent = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text || "";

    // Parse JSON from response (handle markdown code blocks)
    let analysis;
    try {
      const jsonMatch = textContent.match(/\{[\s\S]*\}/);
      analysis = jsonMatch ? JSON.parse(jsonMatch[0]) : null;
    } catch {
      analysis = {
        dano_detectado: false,
        severidade: "nenhum",
        descricao: textContent.substring(0, 200),
        recomendacao: "Análise manual recomendada",
        confianca: 0.5,
      };
    }

    if (!analysis) {
      return new Response(
        JSON.stringify({ error: "Não foi possível analisar a imagem" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Save analysis to database if foto_id provided
    if (foto_id) {
      const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
      const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

      await fetch(`${supabaseUrl}/rest/v1/vistoria_fotos?id=eq.${foto_id}`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          apikey: serviceKey,
          Authorization: `Bearer ${serviceKey}`,
          Prefer: "return=minimal",
        },
        body: JSON.stringify({ ai_analise: analysis }),
      });
    }

    return new Response(
      JSON.stringify({ success: true, analysis }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
