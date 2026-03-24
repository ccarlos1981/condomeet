import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

/**
 * LGPD Auto-Archive Edge Function
 * 
 * Executa diariamente via pg_cron. Responsável por:
 * 1. Encomendas com status 'delivered' criadas há mais de 90 dias → status 'archived'
 *    - Remove foto da encomenda e comprovante de retirada do Storage
 * 2. Convites com status 'used' ou 'expired' criados há mais de 90 dias → deleta
 * 
 * Conformidade LGPD: dados pessoais de visitantes e fotos de encomendas
 * não devem ser retidos indefinidamente.
 */

const ARCHIVE_DAYS = 90

serve(async (_req) => {
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const cutoffDate = new Date()
    cutoffDate.setDate(cutoffDate.getDate() - ARCHIVE_DAYS)
    const cutoff = cutoffDate.toISOString()

    // ── 1. ENCOMENDAS: archive delivered parcels older than 90 days ──
    // First, get records to archive (need photo URLs for Storage cleanup)
    const { data: oldParcels, error: fetchError } = await supabase
      .from('encomendas')
      .select('id, photo_url, pickup_proof_url')
      .eq('status', 'delivered')
      .lt('created_at', cutoff)

    if (fetchError) {
      console.error('❌ Error fetching old parcels:', fetchError.message)
    }

    let parcelsArchived = 0
    let photosRemoved = 0

    if (oldParcels && oldParcels.length > 0) {
      // Remove photos from Storage
      const photoPathsToRemove: string[] = []
      for (const parcel of oldParcels) {
        for (const urlField of [parcel.photo_url, parcel.pickup_proof_url]) {
          if (urlField) {
            // Extract storage path from public URL
            // Format: .../storage/v1/object/public/bucket/path
            const match = urlField.match(/\/storage\/v1\/object\/public\/(.+)$/)
            if (match) {
              const fullPath = match[1] // "bucket/path/to/file"
              const slashIndex = fullPath.indexOf('/')
              if (slashIndex > 0) {
                const bucket = fullPath.substring(0, slashIndex)
                const filePath = fullPath.substring(slashIndex + 1)
                const { error: removeError } = await supabase.storage
                  .from(bucket)
                  .remove([filePath])
                if (!removeError) photosRemoved++
              }
            }
          }
        }
      }

      // Archive the records (soft-delete: set status to 'archived', clear personal data)
      const ids = oldParcels.map(p => p.id)
      const { count, error: updateError } = await supabase
        .from('encomendas')
        .update({
          status: 'archived',
          photo_url: null,
          pickup_proof_url: null,
        })
        .in('id', ids)

      if (updateError) {
        console.error('❌ Error archiving parcels:', updateError.message)
      } else {
        parcelsArchived = count ?? ids.length
      }
    }

    // ── 2. CONVITES: delete used/expired invitations older than 90 days ──
    const { count: convitesDeleted, error: convitesError } = await supabase
      .from('convites')
      .delete({ count: 'exact' })
      .in('status', ['used', 'expired'])
      .lt('created_at', cutoff)

    if (convitesError) {
      console.error('❌ Error deleting old convites:', convitesError.message)
    }

    const summary = {
      cutoff_date: cutoff,
      encomendas_archived: parcelsArchived,
      photos_removed: photosRemoved,
      convites_deleted: convitesDeleted ?? 0,
      executed_at: new Date().toISOString(),
    }

    console.log('✅ LGPD Archive complete:', JSON.stringify(summary))

    return new Response(JSON.stringify(summary), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    console.error('❌ LGPD Archive error:', error)
    return new Response(JSON.stringify({ error: String(error) }), {
      headers: { 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
