import { createClient } from '@/lib/supabase/server'
import { NextRequest, NextResponse } from 'next/server'

export async function POST(req: NextRequest) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const { reserva_id } = await req.json()
  if (!reserva_id) return NextResponse.json({ error: 'reserva_id required' }, { status: 400 })

  // 1. Get the reservation with user info
  const { data: reserva, error: rErr } = await supabase
    .from('reservas')
    .select('id, data_reserva, status, area_id, user_id, condominio_id')
    .eq('id', reserva_id)
    .single()

  if (rErr || !reserva) return NextResponse.json({ error: 'Reserva não encontrada' }, { status: 404 })

  // 2. Get area name
  const { data: area } = await supabase
    .from('areas_comuns')
    .select('tipo_agenda')
    .eq('id', reserva.area_id)
    .single()

  // 3. Update status to cancelado
  const { error: updErr } = await supabase
    .from('reservas')
    .update({ status: 'cancelado', updated_at: new Date().toISOString() })
    .eq('id', reserva_id)

  if (updErr) return NextResponse.json({ error: updErr.message }, { status: 500 })

  // 4. Get morador info for WhatsApp notification
  const { data: morador } = await supabase
    .from('perfil')
    .select('nome_completo, whatsapp, botconversa_id')
    .eq('id', reserva.user_id)
    .single()

  // 5. Send WhatsApp notification via Edge Function
  let whatsappSent = false
  if (morador && (morador.botconversa_id || morador.whatsapp)) {
    const tipoEvento = area?.tipo_agenda ?? 'evento'
    const dataFormatada = new Date(reserva.data_reserva + 'T00:00:00').toLocaleDateString('pt-BR')
    const firstName = morador.nome_completo?.split(' ')[0] || 'Morador'

    const msg =
      `⚠️ *Condomeet — Reserva Cancelada*\n\n` +
      `Olá ${firstName}!\n\n` +
      `Sua reserva de *${tipoEvento}* para o dia *${dataFormatada}* foi *cancelada* pela administração do condomínio.\n\n` +
      `Em caso de dúvidas, entre em contato com o síndico.`

    try {
      const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
      const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY

      // Use the smartSend approach via botconversa-send or directly
      // Call the edge function with service role key for admin access
      const resp = await fetch(`${supabaseUrl}/functions/v1/botconversa-send`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${serviceRoleKey}`,
        },
        body: JSON.stringify({
          msg,
          tipo: 'text',
          condominio_id: reserva.condominio_id,
          modo_envio: 'por_morador',
          user_id: reserva.user_id,
        }),
      })

      if (resp.ok) {
        whatsappSent = true
        console.log(`[CANCEL] WhatsApp notification sent to ${firstName}`)
      } else {
        const errText = await resp.text()
        console.error(`[CANCEL] WhatsApp send failed: ${resp.status} ${errText}`)
      }
    } catch (err) {
      console.error('[CANCEL] WhatsApp notification error:', err)
    }
  }

  return NextResponse.json({
    success: true,
    whatsapp_sent: whatsappSent,
  })
}
