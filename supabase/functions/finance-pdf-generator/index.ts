// deno-lint-ignore-file no-import-prefix
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.7.1'
import { PDFDocument, rgb } from 'https://esm.sh/pdf-lib'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { faturamento_id } = await req.json()
    if (!faturamento_id) throw new Error('faturamento_id is required')

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    )

    // 1. Fetch faturamento info
    const { data: faturamento, error: faturamentoErr } = await supabaseClient
      .from('faturamentos')
      .select('*, condominios(nome)')
      .eq('id', faturamento_id)
      .single()

    if (faturamentoErr || !faturamento) throw new Error('Faturamento não encontrado')

    // 2. Fetch DRE (Lançamentos do mês)
    const { data: lancamentos } = await supabaseClient
      .from('condominio_lancamentos')
      .select('*')
      .eq('condominio_id', faturamento.condominio_id)

    // 3. Create PDF "Transparência" Document
    const pdfDoc = await PDFDocument.create()
    const page = pdfDoc.addPage([600, 800])
    
    page.drawText(`Balancete de Transparência - ${faturamento.condominios?.nome}`, {
      x: 50,
      y: 750,
      size: 20,
      color: rgb(0.98, 0.33, 0.18), // Condomeet Orange (#FA542F)
    })

    let yOffset = 700;
    page.drawText('Receitas e Despesas do Mês:', { x: 50, y: yOffset, size: 14 })
    yOffset -= 30;

    let totalDespesas = 0;
    lancamentos?.forEach(l => {
      const color = l.tipo === 'receita' ? rgb(0, 0.5, 0) : rgb(0.8, 0, 0);
      if (l.tipo === 'despesa') totalDespesas += Number(l.valor);
      
      page.drawText(`${l.descricao} .................... R$ ${Number(l.valor).toFixed(2)}`, {
        x: 50,
        y: yOffset,
        size: 12,
        color: color
      })
      yOffset -= 20;
    })

    // 4. In a real scenario, we would fetch the Asaas Boleto PDF bytes here:
    // const asaasBoletoBytes = await fetch(faturamento.gateway_url).then(r => r.arrayBuffer())
    // const asaasDoc = await PDFDocument.load(asaasBoletoBytes)
    // const [asaasPage] = await pdfDoc.copyPages(asaasDoc, [0])
    // pdfDoc.addPage(asaasPage)
    
    // For now, we mock the Boleto page
    const boletoPage = pdfDoc.addPage([600, 800])
    boletoPage.drawText('BOLETO BANCÁRIO (SIMULAÇÃO ASAAS/IUGU)', { x: 50, y: 750, size: 20 })
    boletoPage.drawText(`Valor: R$ ${Number(faturamento.valor_total).toFixed(2)}`, { x: 50, y: 700, size: 16 })
    boletoPage.drawText(`Vencimento: ${new Date(faturamento.data_vencimento).toLocaleDateString('pt-BR')}`, { x: 50, y: 670, size: 14 })
    boletoPage.drawText('00000.00000 00000.000000 00000.000000 0 00000000000000', { x: 50, y: 600, size: 14 })

    // 5. Serialize and Upload to Supabase Storage (Bucket 'faturas')
    const pdfBytes = await pdfDoc.save()
    const fileName = `boleto_${faturamento_id}_${Date.now()}.pdf`
    
    const { data: uploadData, error: uploadError } = await supabaseClient
      .storage
      .from('faturas')
      .upload(fileName, pdfBytes, {
        contentType: 'application/pdf',
        upsert: true
      })

    if (uploadError) {
      console.error('Upload Error:', uploadError)
      throw new Error('Erro ao salvar o PDF')
    }

    // 6. Get Public URL
    const { data: { publicUrl } } = supabaseClient
      .storage
      .from('faturas')
      .getPublicUrl(fileName)

    // Update faturamento record with the new PDF URL
    await supabaseClient
      .from('faturamentos')
      .update({ pdf_url: publicUrl })
      .eq('id', faturamento_id)

    return new Response(
      JSON.stringify({ 
        success: true, 
        pdf_url: publicUrl,
        message: 'PDF gerado com sucesso' 
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    return new Response(JSON.stringify({ error: errorMsg }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
