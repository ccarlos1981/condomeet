import { createClient } from '@/lib/supabase/server'
import { NextRequest, NextResponse } from 'next/server'

/**
 * Extrai deterministicamente o caminho do objeto no bucket 'album-fotos'
 * a partir de uma URL pública gerada pelo Supabase Storage.
 */
function extractStoragePath(imageUrl: string): string | null {
  try {
    if (!imageUrl) return null
    if (!imageUrl.startsWith('http://') && !imageUrl.startsWith('https://')) {
      return imageUrl.trim()
    }
    const url = new URL(imageUrl)
    const marker = '/album-fotos/'
    const index = url.pathname.indexOf(marker)
    if (index !== -1) {
      const rawPath = url.pathname.substring(index + marker.length)
      return decodeURIComponent(rawPath).trim() || null
    }
    return null
  } catch {
    return null
  }
}

// POST — Criação Segura e Atômica do Álbum
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

  // 1. Validações preliminares
  if (!titulo?.trim() || !condominio_id?.trim()) {
    return NextResponse.json({ error: 'titulo e condominio_id são obrigatórios' }, { status: 400 })
  }

  if (titulo.trim().length > 100) {
    return NextResponse.json({ error: 'O título deve ter no máximo 100 caracteres' }, { status: 400 })
  }

  if (!files || files.length < 1) {
    return NextResponse.json({ error: 'É obrigatório enviar pelo menos 1 foto' }, { status: 400 })
  }

  if (files.length > 5) {
    return NextResponse.json({ error: 'Máximo de 5 fotos por álbum' }, { status: 400 })
  }

  let createdAlbumId: string | null = null
  const uploadedStoragePaths: string[] = []

  try {
    // 2. Inserir registro do álbum explicitamente em 'rascunho' (NÃO dispara Push)
    const { data: album, error: albumError } = await supabase
      .from('album_fotos')
      .insert({
        titulo: titulo.trim(),
        descricao: descricao?.trim() ?? '',
        tipo_evento: tipo_evento || 'evento',
        data_evento: data_evento || null,
        condominio_id: condominio_id.trim(),
        autor_id: user.id,
        status: 'rascunho',
      })
      .select()
      .single()

    if (albumError || !album) {
      return NextResponse.json({ error: albumError?.message ?? 'Erro ao criar registro do álbum' }, { status: 500 })
    }

    createdAlbumId = album.id

    // 3. Upload sequencial das fotos para o bucket 'album-fotos'
    const imageRecords = []
    for (let i = 0; i < files.length; i++) {
      const file = files[i]
      const ext = file.name.split('.').pop() || 'jpg'
      const path = `${condominio_id.trim()}/${createdAlbumId}/${Date.now()}_${i}.${ext}`

      const { error: uploadError } = await supabase.storage
        .from('album-fotos')
        .upload(path, file, { contentType: file.type || 'image/jpeg', upsert: true })

      if (uploadError) {
        throw new Error(`Falha no upload da foto ${i + 1}: ${uploadError.message}`)
      }

      uploadedStoragePaths.push(path)

      const { data: publicUrl } = supabase.storage
        .from('album-fotos')
        .getPublicUrl(path)

      imageRecords.push({
        album_id: createdAlbumId,
        imagem_url: publicUrl.publicUrl,
        ordem: i,
      })
    }

    // 4. Persistir registros na tabela album_fotos_imagens
    const { error: imgError } = await supabase
      .from('album_fotos_imagens')
      .insert(imageRecords)

    if (imgError) {
      throw new Error(`Falha ao registrar fotos do álbum: ${imgError.message}`)
    }

    // 5. Publicar o álbum (transição rascunho -> publicado aciona o trigger oficial de Push)
    const { data: publishedAlbum, error: pubError } = await supabase
      .from('album_fotos')
      .update({ status: 'publicado' })
      .eq('id', createdAlbumId)
      .select()
      .single()

    if (pubError) {
      throw new Error(`Falha ao publicar álbum: ${pubError.message}`)
    }

    return NextResponse.json(publishedAlbum, { status: 201 })
  } catch (err) {
    const errorMsg = err instanceof Error ? err.message : String(err)
    console.error('[POST /api/album-fotos] Falha no fluxo de criação:', errorMsg)

    // COMPENSAÇÃO DE ROLLBACK (BEST-EFFORT E OBSERVÁVEL)
    if (uploadedStoragePaths.length > 0) {
      try {
        const { error: storageRemoveErr } = await supabase.storage
          .from('album-fotos')
          .remove(uploadedStoragePaths)

        if (storageRemoveErr) {
          console.error('[POST /api/album-fotos] Falha ao compensar Storage:', storageRemoveErr.message)
        }
      } catch (storageCleanupErr) {
        console.error('[POST /api/album-fotos] Exceção ao limpar Storage na compensação:', storageCleanupErr)
      }
    }

    if (createdAlbumId) {
      try {
        const { error: dbDeleteErr } = await supabase
          .from('album_fotos')
          .delete()
          .eq('id', createdAlbumId)

        if (dbDeleteErr) {
          console.error('[POST /api/album-fotos] Falha ao excluir rascunho do banco:', dbDeleteErr.message)
        }
      } catch (dbCleanupErr) {
        console.error('[POST /api/album-fotos] Exceção ao limpar rascunho do banco:', dbCleanupErr)
      }
    }

    return NextResponse.json({ error: errorMsg }, { status: 500 })
  }
}

// PUT — Edição Segura (Substituição com Inversão de Ordem e Garantia de 1 a 5 fotos)
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
  const files = formData.getAll('fotos') as File[]

  if (!albumId) return NextResponse.json({ error: 'album_id é obrigatório' }, { status: 400 })

  let removedImageIds: string[] = []
  try {
    const raw = formData.get('removed_image_ids') as string
    removedImageIds = raw ? JSON.parse(raw) : []
    if (!Array.isArray(removedImageIds)) removedImageIds = []
  } catch {
    removedImageIds = []
  }

  // 1. Buscar a quantidade real atual de imagens no banco para este álbum
  const { data: currentImages, error: currentImgErr } = await supabase
    .from('album_fotos_imagens')
    .select('id, imagem_url, ordem')
    .eq('album_id', albumId)

  if (currentImgErr) {
    return NextResponse.json({ error: currentImgErr.message }, { status: 500 })
  }

  const existingImages = currentImages ?? []
  const existingIds = new Set(existingImages.map(img => img.id))

  // Validar que os IDs solicitados realmente pertencem a este álbum
  const validRemovedIds = removedImageIds.filter(id => existingIds.has(id))

  // 2. Calcular o saldo final e validar
  const totalFinal = existingImages.length - validRemovedIds.length + files.length

  if (totalFinal < 1) {
    return NextResponse.json(
      { error: 'O álbum deve conter pelo menos 1 foto. Não é permitido remover todas as fotos.' },
      { status: 400 }
    )
  }

  if (totalFinal > 5) {
    return NextResponse.json(
      { error: 'Máximo de 5 fotos por álbum' },
      { status: 400 }
    )
  }

  // 3. Atualizar metadados do álbum
  const updateData: Record<string, unknown> = {}
  if (titulo !== null && titulo !== undefined) updateData.titulo = titulo.trim()
  if (descricao !== null && descricao !== undefined) updateData.descricao = descricao.trim()
  if (tipo_evento) updateData.tipo_evento = tipo_evento
  if (data_evento !== null && data_evento !== undefined) updateData.data_evento = data_evento || null

  if (Object.keys(updateData).length > 0) {
    const { error: updateError } = await supabase
      .from('album_fotos')
      .update(updateData)
      .eq('id', albumId)

    if (updateError) return NextResponse.json({ error: updateError.message }, { status: 500 })
  }

  // 4. ORDEM DA SUBSTITUIÇÃO: PRIMEIRO UPLOAD E INSERT DAS NOVAS FOTOS
  const newUploadedPaths: string[] = []
  const newInsertedIds: string[] = []

  if (files.length > 0) {
    try {
      const imageRecords = []
      const baseOrder = existingImages.length
      for (let i = 0; i < files.length; i++) {
        const file = files[i]
        const ext = file.name.split('.').pop() || 'jpg'
        const condoFolder = condominio_id ? condominio_id.trim() : 'condo'
        const path = `${condoFolder}/${albumId}/${Date.now()}_${i}.${ext}`

        const { error: uploadError } = await supabase.storage
          .from('album-fotos')
          .upload(path, file, { contentType: file.type || 'image/jpeg', upsert: true })

        if (uploadError) {
          throw new Error(`Falha no upload da nova foto ${i + 1}: ${uploadError.message}`)
        }

        newUploadedPaths.push(path)

        const { data: publicUrl } = supabase.storage
          .from('album-fotos')
          .getPublicUrl(path)

        imageRecords.push({
          album_id: albumId,
          imagem_url: publicUrl.publicUrl,
          ordem: baseOrder + i,
        })
      }

      const { data: insertedData, error: insertError } = await supabase
        .from('album_fotos_imagens')
        .insert(imageRecords)
        .select('id')

      if (insertError) {
        throw new Error(`Falha ao registrar novas fotos: ${insertError.message}`)
      }

      if (insertedData) {
        newInsertedIds.push(...insertedData.map(d => d.id))
      }
    } catch (err) {
      // Compensar os novos uploads sem remover imagens antigas
      if (newUploadedPaths.length > 0) {
        try {
          await supabase.storage.from('album-fotos').remove(newUploadedPaths)
        } catch (storageCleanupErr) {
          console.error('[PUT /api/album-fotos] Falha ao compensar Storage:', storageCleanupErr)
        }
      }
      if (newInsertedIds.length > 0) {
        try {
          await supabase.from('album_fotos_imagens').delete().in('id', newInsertedIds)
        } catch (dbCleanupErr) {
          console.error('[PUT /api/album-fotos] Falha ao compensar DB:', dbCleanupErr)
        }
      }
      return NextResponse.json({ error: (err as Error).message }, { status: 500 })
    }
  }

  // 5. ORDEM DA SUBSTITUIÇÃO: DEPOIS REMOVER AS FOTOS ANTIGAS AUTORIZADAS
  if (validRemovedIds.length > 0) {
    const imagesToDelete = existingImages.filter(img => validRemovedIds.includes(img.id))
    const pathsToRemove = imagesToDelete
      .map(img => extractStoragePath(img.imagem_url))
      .filter((p): p is string => Boolean(p))

    if (pathsToRemove.length > 0) {
      const { error: storageRemoveErr } = await supabase.storage
        .from('album-fotos')
        .remove(pathsToRemove)

      if (storageRemoveErr) {
        console.error('[PUT /api/album-fotos] Falha ao remover arquivos antigos do Storage:', storageRemoveErr.message)
      }
    }

    const { error: dbDeleteErr } = await supabase
      .from('album_fotos_imagens')
      .delete()
      .in('id', validRemovedIds)

    if (dbDeleteErr) {
      return NextResponse.json({ error: dbDeleteErr.message }, { status: 500 })
    }
  }

  return NextResponse.json({ ok: true })
}

// DELETE — Exclusão Segura (Remoção física no Storage antes da remoção no Banco)
export async function DELETE(req: NextRequest) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const id = req.nextUrl.searchParams.get('id')
  if (!id) return NextResponse.json({ error: 'id é obrigatório' }, { status: 400 })

  // 1. Obter todas as imagens associadas
  const { data: images, error: imagesErr } = await supabase
    .from('album_fotos_imagens')
    .select('imagem_url')
    .eq('album_id', id)

  if (imagesErr) {
    return NextResponse.json({ error: imagesErr.message }, { status: 500 })
  }

  // 2. Determinar os paths determinísticos no bucket 'album-fotos'
  const paths = (images ?? [])
    .map(img => extractStoragePath(img.imagem_url))
    .filter((p): p is string => Boolean(p))

  // 3. Remover arquivos físicos do Storage primeiro (não tolerar órfãos conhecidos)
  if (paths.length > 0) {
    const { error: storageErr } = await supabase.storage
      .from('album-fotos')
      .remove(paths)

    if (storageErr) {
      console.error('[DELETE /api/album-fotos] Falha ao remover arquivos do Storage:', storageErr.message)
      return NextResponse.json(
        { error: `Falha ao remover fotos do Storage: ${storageErr.message}. Exclusão abortada para evitar arquivos órfãos.` },
        { status: 500 }
      )
    }
  }

  // 4. Excluir o registro de album_fotos no banco (ON DELETE CASCADE cuidará das filhas)
  const { error: deleteErr } = await supabase
    .from('album_fotos')
    .delete()
    .eq('id', id)

  if (deleteErr) {
    return NextResponse.json({ error: deleteErr.message }, { status: 500 })
  }

  return NextResponse.json({ ok: true })
}
