import { createClient } from '@/lib/supabase/server'
import { NextRequest, NextResponse } from 'next/server'

// POST — Create album
export async function POST(req: NextRequest) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const formData = await req.formData()
  const titulo = formData.get('titulo') as string
  const descricao = formData.get('descricao') as string
  const tipo_evento = formData.get('tipo_evento') as string
  const data_evento = formData.get('data_evento') as string
  const condominio_id = formData.get('condominio_id') as string
  const files = formData.getAll('fotos') as File[]

  if (!titulo || !condominio_id) {
    return NextResponse.json({ error: 'titulo e condominio_id são obrigatórios' }, { status: 400 })
  }

  if (files.length > 5) {
    return NextResponse.json({ error: 'Máximo de 5 fotos por álbum' }, { status: 400 })
  }

  // 1. Create album record
  const { data: album, error: albumError } = await supabase
    .from('album_fotos')
    .insert({
      titulo: titulo.trim(),
      descricao: descricao?.trim() ?? '',
      tipo_evento: tipo_evento || 'evento',
      data_evento: data_evento || null,
      condominio_id,
      autor_id: user.id,
    })
    .select()
    .single()

  if (albumError) return NextResponse.json({ error: albumError.message }, { status: 500 })

  // 2. Upload photos to storage and create image records
  const imageRecords = []
  for (let i = 0; i < files.length; i++) {
    const file = files[i]
    const ext = file.name.split('.').pop() || 'jpg'
    const path = `${condominio_id}/${album.id}/${i}.${ext}`

    const { error: uploadError } = await supabase.storage
      .from('album-fotos')
      .upload(path, file, { contentType: file.type, upsert: true })

    if (uploadError) {
      console.error('Upload error:', uploadError)
      continue
    }

    const { data: publicUrl } = supabase.storage
      .from('album-fotos')
      .getPublicUrl(path)

    imageRecords.push({
      album_id: album.id,
      imagem_url: publicUrl.publicUrl,
      ordem: i,
    })
  }

  if (imageRecords.length > 0) {
    await supabase.from('album_fotos_imagens').insert(imageRecords)
  }

  return NextResponse.json(album, { status: 201 })
}

// PUT — Update album metadata + manage images
export async function PUT(req: NextRequest) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const formData = await req.formData()
  const albumId = formData.get('album_id') as string
  const titulo = formData.get('titulo') as string
  const descricao = formData.get('descricao') as string
  const tipo_evento = formData.get('tipo_evento') as string
  const data_evento = formData.get('data_evento') as string
  const condominio_id = formData.get('condominio_id') as string
  const removedImageIds = JSON.parse((formData.get('removed_image_ids') as string) || '[]')
  const files = formData.getAll('fotos') as File[]

  if (!albumId) return NextResponse.json({ error: 'album_id é obrigatório' }, { status: 400 })

  // Update album metadata
  const updateData: Record<string, unknown> = {}
  if (titulo) updateData.titulo = titulo.trim()
  if (descricao !== null) updateData.descricao = descricao?.trim() ?? ''
  if (tipo_evento) updateData.tipo_evento = tipo_evento
  if (data_evento) updateData.data_evento = data_evento

  if (Object.keys(updateData).length > 0) {
    const { error } = await supabase
      .from('album_fotos')
      .update(updateData)
      .eq('id', albumId)

    if (error) return NextResponse.json({ error: error.message }, { status: 500 })
  }

  // Remove deleted images
  if (removedImageIds.length > 0) {
    // Get image URLs to delete from storage
    const { data: imagesToDelete } = await supabase
      .from('album_fotos_imagens')
      .select('imagem_url')
      .in('id', removedImageIds)

    if (imagesToDelete) {
      for (const img of imagesToDelete) {
        const url = new URL(img.imagem_url)
        const storagePath = url.pathname.split('/album-fotos/')[1]
        if (storagePath) {
          await supabase.storage.from('album-fotos').remove([decodeURIComponent(storagePath)])
        }
      }
    }

    await supabase.from('album_fotos_imagens').delete().in('id', removedImageIds)
  }

  // Upload new photos
  if (files.length > 0) {
    // Get current image count
    const { count } = await supabase
      .from('album_fotos_imagens')
      .select('*', { count: 'exact', head: true })
      .eq('album_id', albumId)

    const currentCount = count ?? 0
    if (currentCount + files.length > 5) {
      return NextResponse.json({ error: 'Máximo de 5 fotos por álbum' }, { status: 400 })
    }

    const imageRecords = []
    for (let i = 0; i < files.length; i++) {
      const file = files[i]
      const ext = file.name.split('.').pop() || 'jpg'
      const path = `${condominio_id}/${albumId}/${Date.now()}_${i}.${ext}`

      const { error: uploadError } = await supabase.storage
        .from('album-fotos')
        .upload(path, file, { contentType: file.type, upsert: true })

      if (uploadError) continue

      const { data: publicUrl } = supabase.storage
        .from('album-fotos')
        .getPublicUrl(path)

      imageRecords.push({
        album_id: albumId,
        imagem_url: publicUrl.publicUrl,
        ordem: currentCount + i,
      })
    }

    if (imageRecords.length > 0) {
      await supabase.from('album_fotos_imagens').insert(imageRecords)
    }
  }

  return NextResponse.json({ ok: true })
}

// DELETE — Delete album (cascade)
export async function DELETE(req: NextRequest) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const id = req.nextUrl.searchParams.get('id')
  if (!id) return NextResponse.json({ error: 'id é obrigatório' }, { status: 400 })

  // Get all images to delete from storage
  const { data: images } = await supabase
    .from('album_fotos_imagens')
    .select('imagem_url')
    .eq('album_id', id)

  if (images) {
    const paths = images.map(img => {
      const url = new URL(img.imagem_url)
      const storagePath = url.pathname.split('/album-fotos/')[1]
      return storagePath ? decodeURIComponent(storagePath) : null
    }).filter(Boolean) as string[]

    if (paths.length > 0) {
      await supabase.storage.from('album-fotos').remove(paths)
    }
  }

  const { error } = await supabase.from('album_fotos').delete().eq('id', id)
  if (error) return NextResponse.json({ error: error.message }, { status: 500 })
  return NextResponse.json({ ok: true })
}
