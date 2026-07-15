// deno-lint-ignore-file no-import-prefix
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface TaxaExtra {
  valor: number
  descricao?: string
}

interface PerfilSimples {
  id: string
  nome_completo: string | null
}

interface UnidadePerfilSimples {
  perfil: PerfilSimples | null
}

interface BlocoSimples {
  nome_ou_numero: string | null
}

interface ApartamentoSimples {
  numero: string | null
}

interface UnidadeSimulada {
  id: string
  blocos: BlocoSimples | null
  apartamentos: ApartamentoSimples | null
  unidade_perfil: UnidadePerfilSimples[] | null
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    const body = await req.json()
    const { condominio_id, mes_referencia, modelo, valor_base, taxas_extras } = body

    if (!condominio_id || !mes_referencia) {
      throw new Error('condominio_id and mes_referencia are required')
    }

    // Calcular Base
    let valorRateioBase = 0;
    if (modelo === 'rateio') {
        const { data: lancamentos } = await supabaseClient
          .from('condominio_lancamentos')
          .select('valor')
          .eq('condominio_id', condominio_id)
          .eq('tipo', 'despesa')

        let totalDespesas = 0;
        lancamentos?.forEach(l => totalDespesas += Number(l.valor));

        const { count } = await supabaseClient
          .from('unidades')
          .select('*', { count: 'exact', head: true })
          .eq('condominio_id', condominio_id)
        
        const numUnidades = count || 1;
        valorRateioBase = totalDespesas / numUnidades;
    } else {
        valorRateioBase = Number(valor_base || 0);
    }

    // Calcular Extra Global
    let totalExtraGlobal = 0;
    if (taxas_extras && Array.isArray(taxas_extras)) {
        taxas_extras.forEach((t: TaxaExtra) => totalExtraGlobal += Number(t.valor || 0));
    }

    const valorFixoGlobal = valorRateioBase + totalExtraGlobal;

    // Buscar Unidades e consumos individuais
    const { data: unidades, error: unidadesErr } = await supabaseClient
      .from('unidades')
      .select(`
        id, 
        blocos(nome_ou_numero), 
        apartamentos(numero),
        unidade_perfil(perfil(id, nome_completo))
      `)
      .eq('condominio_id', condominio_id)

    if (unidadesErr) {
        console.error("Erro ao buscar unidades:", unidadesErr);
    }

    if (!unidades || unidades.length === 0) {
      throw new Error('Nenhuma unidade encontrada')
    }

    const rawUnidades = unidades as unknown as UnidadeSimulada[];

    const simulação = [];
    let valorTotalCondominio = 0;

    for (const unidade of rawUnidades) {
       let valorFinal = valorFixoGlobal;
       let multasValor = 0;
       let reservasValor = 0;
       
       const { data: multas } = await supabaseClient
         .from('notificacoes_multas')
         .select('valor, titulo')
         .eq('unidade_id', unidade.id)
         .eq('tipo', 'MULTA')
         .eq('status', 'pendente')
       
       multas?.forEach(m => multasValor += Number(m.valor || 0));

        const morador = unidade.unidade_perfil?.[0]?.perfil;
        const userIds = unidade.unidade_perfil
          ?.map((up) => up.perfil?.id)
          .filter(Boolean) || [];

        if (userIds.length > 0) {
          const { data: reservas } = await supabaseClient
            .from('reservas')
            .select('valor_reserva')
            .in('user_id', userIds)
            .eq('status', 'aprovado')
            .eq('status_pagamento', 'pendente');
          
          reservas?.forEach(r => reservasValor += Number(r.valor_reserva || 0));
        }

       valorFinal += multasValor + reservasValor;

       if (valorFinal > 0) {
            valorTotalCondominio += valorFinal;
            simulação.push({
                unidade_id: unidade.id,
                bloco: unidade.blocos?.nome_ou_numero || '',
                apto: unidade.apartamentos?.numero || '',
                morador_nome: morador?.nome_completo || 'Sem morador',
                valor_base: valorRateioBase,
                taxas_extras: totalExtraGlobal,
                multas: multasValor,
                reservas: reservasValor,
                valor_total: valorFinal
            });
       }
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        simulacao: simulação,
        resumo: {
            total_unidades: simulação.length,
            valor_total_arrecadar: valorTotalCondominio
        }
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    return new Response(
      JSON.stringify({ error: errorMsg }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})
