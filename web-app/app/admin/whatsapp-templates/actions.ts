'use server'

import { createClient } from '@/lib/supabase/server'

export async function fetchTemplates() {
  try {
    const supabase = await createClient()
    const { data, error } = await supabase
      .from('whatsapp_meta_templates')
      .select('*')

    if (error) {
      console.error('Error fetching templates:', error)
      return { error: error.message }
    }
    return { data }
  } catch (e: any) {
    return { error: e.message || 'Error fetching templates' }
  }
}

export async function syncTemplates() {
  try {
    const supabase = await createClient()
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) return { error: 'Unauthorized' }

    const res = await fetch(`${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/whatsapp-template-manager`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${session.access_token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ action: 'sync' })
    })

    if (!res.ok) {
      const txt = await res.text()
      throw new Error(txt)
    }

    const result = await res.json()
    return { success: true, result }
  } catch (err: any) {
    return { error: err.message || 'Error during sync' }
  }
}
