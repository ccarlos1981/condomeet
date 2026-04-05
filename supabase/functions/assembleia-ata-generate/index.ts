import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") || "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { assembleia_id } = await req.json();

    if (!assembleia_id) {
      return new Response(JSON.stringify({ error: "assembleia_id é obrigatório" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!GEMINI_API_KEY) {
      return new Response(JSON.stringify({ error: "GEMINI_API_KEY não configurada" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Fetch Assembleia Data
    const { data: assembleia, error: assembleiaError } = await supabase
      .from("assembleias")
      .select("*")
      .eq("id", assembleia_id)
      .single();

    if (assembleiaError || !assembleia) {
      throw new Error(`Assembleia não encontrada: ${assembleiaError?.message}`);
    }

    // Fetch Condominio Data separately to avoid PostgREST relationship errors
    const { data: condominio, error: condominioError } = await supabase
      .from("condominios")
      .select("id, nome, cnpj, cidade, estado")
      .eq("id", assembleia.condominio_id)
      .single();

    // Injetamos o condominio no objeto assembleia para manter a compatibilidade com o resto do script
    assembleia.condominios = condominio || null;

    // Fetch Pautas
    const { data: pautas, error: pautasError } = await supabase
      .from("assembleia_pautas")
      .select("*")
      .eq("assembleia_id", assembleia_id)
      .order("ordem", { ascending: true });

    if (pautasError) throw new Error(pautasError.message);

    // Fetch Votos
    const { data: votos, error: votosError } = await supabase
      .from("assembleia_votos")
      .select("pauta_id, voto, peso_aplicado")
      .eq("assembleia_id", assembleia_id);

    if (votosError) throw new Error(votosError.message);

    // Fetch Presencas
    const { data: presencas, error: presencasError } = await supabase
      .from("assembleia_presencas")
      .select("unit_id")
      .eq("assembleia_id", assembleia_id);

    if (presencasError) throw new Error(presencasError.message);

    // Aggregate Presences (unique units)
    const uniqueUnitsSet = new Set(presencas?.map(p => p.unit_id));
    const totalPresentes = uniqueUnitsSet.size;

    // Aggregate Votes per Pauta
    const pautasComResultados = pautas?.map(pauta => {
      const votosDaPauta = votos?.filter(v => v.pauta_id === pauta.id) || [];
      const resultados: Record<string, number> = {};
      
      votosDaPauta.forEach(v => {
        // Usa o peso aplicado, que pode ser fracao_ideal ou unitario (1)
        const peso = v.peso_aplicado || 1;
        resultados[v.voto] = (resultados[v.voto] || 0) + peso;
      });

      return {
        titulo: pauta.titulo,
        descricao: pauta.descricao,
        resultados
      };
    });

    const dataAssembleia = assembleia.dt_1a_convocacao 
      ? new Date(assembleia.dt_1a_convocacao).toLocaleDateString("pt-BR")
      : "Data não definida";
      
    // Construir o payload de contexto para a IA
    const contextoParaIa = {
      condominio: assembleia.condominios?.nome,
      cidade: assembleia.condominios?.cidade,
      estado: assembleia.condominios?.estado,
      tipo_assembleia: assembleia.tipo === 'extraordinaria' ? 'Assembleia Geral Extraordinária' : 'Assembleia Geral Ordinária',
      data: dataAssembleia,
      presidente_mesa: assembleia.presidente_mesa || "[Presidente não informado]",
      secretario_mesa: assembleia.secretario_mesa || "[Secretário não informado]",
      total_unidades_presentes: totalPresentes,
      pautas_e_votacoes: pautasComResultados
    };

    const prompt = `Você é um advogado especialista em direito imobiliário e condomínios no Brasil.
Seu objetivo é redigir o corpo jurídico de uma "Ata de Reunião de Condomínio", de forma impecável, profissional, e legalmente concisa.
Não crie cabeçalhos, títulos ou campos de assinatura no texto, pois o layout da página já terá tudo isso. 
Concentre-se em gerar APENAS os parágrafos contínuos narrando os fatos ocorridos, na ordem padrão de uma ata cartorial.

Dados reais da assembleia:
${JSON.stringify(contextoParaIa, null, 2)}

Regras de Redação da ATA:
1. Comece diretamente com a narrativa da abertura (Ex: "Aos [data por extenso], realizou-se a ${contextoParaIa.tipo_assembleia} do condomínio ${contextoParaIa.condominio}...").
2. Mencione que o quórum de presença registrou ${totalPresentes} unidades representadas.
3. Mencione que a mesa foi presidida por ${contextoParaIa.presidente_mesa} e secretariada por ${contextoParaIa.secretario_mesa}.
4. Liste as pautas discutidas.
5. Para CADA pauta, explique que houve a deliberação e apresente de modo TEXTUAL (não use tabelas) os resultados numéricos da votação exata informados no JSON de dados. Se os valores tiverem casas decimais (fração ideal), explique que os votos representam as frações ideais correspondentes.
6. Encerre com a frase formal tradicional (Ex: "Nada mais havendo a tratar, o presidente determinou a lavratura desta ata, que lida e achada conforme, será assinada...").
7. Não adicione linhas pontilhadas para assinatura, pois a nossa tela geradora de PDF cuidará da parte visual das assinaturas. Retorne APENAS a redação contínua da ATA.
8. Formate em texto simples contínuo com quebras de linha normais entre os parágrafos (apenas \n). Não use formatações markdown exóticas (*, #, etc).`;

    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_API_KEY}`;
    
    // Invocando o Gemini 2.5 Flash
    const geminiResponse = await fetch(geminiUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [
          {
            parts: [{ text: prompt }]
          }
        ],
        generationConfig: {
          temperature: 0.2, // Baixa temperatura para texto jurídico preciso
          maxOutputTokens: 3000,
        },
      }),
    });

    const geminiData = await geminiResponse.json();
    let textContent = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text || "";

    if (!textContent) {
      throw new Error(`A Inteligência Artificial retornou vazio ou falhou. Detalhes do erro da IA: ${JSON.stringify(geminiData)}`);
    }

    // Optional: Update the generated ATA immediately in the database
    await supabase
      .from("assembleias")
      .update({ ata_texto: textContent.trim() })
      .eq("id", assembleia_id);

    // Biling Log for AI Usage
    const valor_cobrado = 9.90; // The fixed cost in reais (R$ 9,90) - representing 3x the base cost
    const { error: faturamentoError } = await supabase
      .from("consumo_extras")
      .insert({
        condominio_id: assembleia.condominios?.id || assembleia.condominio_id, // ensure condomínio ID is logged
        assembleia_id: assembleia_id,
        tipo_servico: 'ATA_IA',
        valor_cobrado: valor_cobrado,
        detalhes: {
           status: 'Sucesso',
           token_count_approx: textContent.length / 4 // an approximation of tokens used
        }
      });
      
    if (faturamentoError) {
      console.warn("Falha ao registrar consumo extra:", faturamentoError.message);
      // We don't throw an error here to prevent the user from losing their generated ATA 
      // just because the billing log failed. However, it's logged for debugging.
    }

    return new Response(JSON.stringify({ success: true, ata_texto: textContent.trim() }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error: any) {
    console.error("Error generating ATA:", error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
