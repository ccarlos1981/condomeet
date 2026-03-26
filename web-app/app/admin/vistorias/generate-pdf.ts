'use client'
import jsPDF from 'jspdf'
import autoTable from 'jspdf-autotable'

interface VistoriaData {
  titulo: string
  tipo_bem: string
  tipo_vistoria: string
  endereco: string | null
  cod_interno: string
  responsavel_nome: string | null
  proprietario_nome: string | null
  inquilino_nome: string | null
  plano: string
  status: string
  created_at: string
}

interface SecaoData { id: string; nome: string; icone_emoji: string; posicao: number }
interface ItemData { id: string; secao_id: string; nome: string; status: string; observacao: string | null; posicao: number }
interface FotoData { id: string; item_id: string; foto_url: string }
interface AssinaturaData { nome: string; papel: string; assinatura_url: string | null; assinado_em: string | null }

const TIPO_BEM_LABELS: Record<string, string> = {
  apartamento: 'Apartamento', casa: 'Casa', carro: 'Carro',
  moto: 'Moto', barco: 'Barco', equipamento: 'Equipamento', personalizado: 'Personalizado',
}

const TIPO_VISTORIA_LABELS: Record<string, string> = {
  entrada: 'Entrada', saida: 'Saída', periodica: 'Periódica',
}

const STATUS_LABELS: Record<string, string> = {
  ok: 'OK', atencao: 'Atenção', danificado: 'Danificado', nao_existe: 'Não existe',
  rascunho: 'Rascunho', em_andamento: 'Em andamento', concluida: 'Concluída', assinada: 'Assinada',
}

const STATUS_COLORS: Record<string, [number, number, number]> = {
  ok: [34, 197, 94],       // green
  atencao: [234, 179, 8],  // yellow
  danificado: [239, 68, 68], // red
  nao_existe: [156, 163, 175], // gray
}

async function loadImageAsBase64(url: string): Promise<string | null> {
  try {
    const res = await fetch(url)
    const blob = await res.blob()
    return new Promise((resolve) => {
      const reader = new FileReader()
      reader.onload = () => resolve(reader.result as string)
      reader.onerror = () => resolve(null)
      reader.readAsDataURL(blob)
    })
  } catch {
    return null
  }
}

export async function generateVistoriaPDF(
  vistoria: VistoriaData,
  secoes: SecaoData[],
  itens: ItemData[],
  fotos: FotoData[],
  assinaturas: AssinaturaData[],
  includePhotos: boolean = true,
) {
  const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' })
  const pageWidth = doc.internal.pageSize.getWidth()
  const margin = 15
  let y = 15

  // ── Header ──
  doc.setFillColor(252, 89, 49) // #FC5931
  doc.rect(0, 0, pageWidth, 38, 'F')

  doc.setTextColor(255, 255, 255)
  doc.setFontSize(20)
  doc.setFont('helvetica', 'bold')
  doc.text('RELATÓRIO DE VISTORIA', margin, 18)

  doc.setFontSize(10)
  doc.setFont('helvetica', 'normal')
  doc.text(`${TIPO_BEM_LABELS[vistoria.tipo_bem] ?? vistoria.tipo_bem} • ${TIPO_VISTORIA_LABELS[vistoria.tipo_vistoria] ?? vistoria.tipo_vistoria}`, margin, 26)
  doc.text(`Código: #${vistoria.cod_interno}`, margin, 32)

  // Brand
  doc.setFontSize(9)
  doc.text('Condomeet Check', pageWidth - margin, 32, { align: 'right' })

  y = 45

  // ── Info Box ──
  doc.setTextColor(0, 0, 0)
  doc.setDrawColor(230, 230, 230)
  doc.setFillColor(250, 250, 250)
  doc.roundedRect(margin, y, pageWidth - 2 * margin, 36, 3, 3, 'FD')

  doc.setFontSize(14)
  doc.setFont('helvetica', 'bold')
  doc.text(vistoria.titulo, margin + 5, y + 9)

  doc.setFontSize(9)
  doc.setFont('helvetica', 'normal')
  doc.setTextColor(100, 100, 100)

  const infoLines: string[] = []
  if (vistoria.endereco) infoLines.push(`Endereço: ${vistoria.endereco}`)
  if (vistoria.responsavel_nome) infoLines.push(`Responsável: ${vistoria.responsavel_nome}`)
  if (vistoria.proprietario_nome) infoLines.push(`Proprietário: ${vistoria.proprietario_nome}`)
  if (vistoria.inquilino_nome) infoLines.push(`Inquilino: ${vistoria.inquilino_nome}`)
  infoLines.push(`Data: ${new Date(vistoria.created_at).toLocaleDateString('pt-BR')}`)
  infoLines.push(`Status: ${STATUS_LABELS[vistoria.status] ?? vistoria.status}`)

  const col1 = infoLines.slice(0, 3)
  const col2 = infoLines.slice(3)
  col1.forEach((line, i) => doc.text(line, margin + 5, y + 17 + i * 5))
  col2.forEach((line, i) => doc.text(line, pageWidth / 2, y + 17 + i * 5))

  y += 42

  // ── Summary Stats ──
  const totalItens = itens.length
  const okCount = itens.filter(i => i.status === 'ok').length
  const atencaoCount = itens.filter(i => i.status === 'atencao').length
  const danificadoCount = itens.filter(i => i.status === 'danificado').length

  const statsBoxWidth = (pageWidth - 2 * margin - 9) / 4
  const statsData = [
    { label: 'Total', value: totalItens.toString(), color: [59, 130, 246] as [number, number, number] },
    { label: 'OK', value: okCount.toString(), color: [34, 197, 94] as [number, number, number] },
    { label: 'Atenção', value: atencaoCount.toString(), color: [234, 179, 8] as [number, number, number] },
    { label: 'Danificado', value: danificadoCount.toString(), color: [239, 68, 68] as [number, number, number] },
  ]

  statsData.forEach((stat, i) => {
    const x = margin + (statsBoxWidth + 3) * i
    doc.setFillColor(stat.color[0], stat.color[1], stat.color[2])
    doc.roundedRect(x, y, statsBoxWidth, 16, 2, 2, 'F')
    doc.setTextColor(255, 255, 255)
    doc.setFontSize(14)
    doc.setFont('helvetica', 'bold')
    doc.text(stat.value, x + statsBoxWidth / 2, y + 8, { align: 'center' })
    doc.setFontSize(7)
    doc.setFont('helvetica', 'normal')
    doc.text(stat.label, x + statsBoxWidth / 2, y + 13, { align: 'center' })
  })

  y += 22

  // ── Sections and Items Table ──
  const sortedSecoes = [...secoes].sort((a, b) => a.posicao - b.posicao)

  for (const secao of sortedSecoes) {
    const secaoItens = itens
      .filter(i => i.secao_id === secao.id)
      .sort((a, b) => a.posicao - b.posicao)

    if (secaoItens.length === 0) continue

    // Check if we need a new page
    if (y > 250) { doc.addPage(); y = 15 }

    // Section header
    doc.setFillColor(243, 244, 246)
    doc.roundedRect(margin, y, pageWidth - 2 * margin, 8, 2, 2, 'F')
    doc.setTextColor(55, 65, 81)
    doc.setFontSize(11)
    doc.setFont('helvetica', 'bold')
    doc.text(`${secao.icone_emoji ?? '🏠'} ${secao.nome}`, margin + 4, y + 6)
    y += 11

    // Items table
    const tableData = secaoItens.map(item => {
      const statusLabel = STATUS_LABELS[item.status] ?? item.status
      return [item.nome, statusLabel, item.observacao || '—']
    })

    autoTable(doc, {
      startY: y,
      head: [['Item', 'Status', 'Observação']],
      body: tableData,
      margin: { left: margin, right: margin },
      theme: 'grid',
      headStyles: {
        fillColor: [252, 89, 49],
        textColor: [255, 255, 255],
        fontSize: 8,
        fontStyle: 'bold',
      },
      bodyStyles: { fontSize: 8, cellPadding: 3 },
      columnStyles: {
        0: { cellWidth: 45, fontStyle: 'bold' },
        1: { cellWidth: 25, halign: 'center' },
        2: { cellWidth: 'auto' },
      },
      didParseCell: (data) => {
        // Color code status cells
        if (data.section === 'body' && data.column.index === 1) {
          const statusText = data.cell.text[0]
          if (statusText === 'OK') {
            data.cell.styles.textColor = STATUS_COLORS.ok
            data.cell.styles.fontStyle = 'bold'
          } else if (statusText === 'Atenção') {
            data.cell.styles.textColor = STATUS_COLORS.atencao
            data.cell.styles.fontStyle = 'bold'
          } else if (statusText === 'Danificado') {
            data.cell.styles.textColor = STATUS_COLORS.danificado
            data.cell.styles.fontStyle = 'bold'
          } else if (statusText === 'Não existe') {
            data.cell.styles.textColor = STATUS_COLORS.nao_existe
          }
        }
      },
    })

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    y = (doc as any).lastAutoTable.finalY + 4

    // Photos for items in this section (if Plus plan)
    if (includePhotos) {
      const secaoFotos = fotos.filter(f => secaoItens.some(i => i.id === f.item_id))

      if (secaoFotos.length > 0) {
        if (y > 240) { doc.addPage(); y = 15 }

        doc.setFontSize(8)
        doc.setFont('helvetica', 'bold')
        doc.setTextColor(100, 100, 100)
        doc.text('Fotos:', margin, y + 3)
        y += 6

        let photoX = margin
        const photoSize = 35

        for (const foto of secaoFotos) {
          if (photoX + photoSize > pageWidth - margin) {
            photoX = margin
            y += photoSize + 3
          }
          if (y + photoSize > 280) { doc.addPage(); y = 15; photoX = margin }

          try {
            const base64 = await loadImageAsBase64(foto.foto_url)
            if (base64) {
              doc.addImage(base64, 'JPEG', photoX, y, photoSize, photoSize)
              doc.setDrawColor(220, 220, 220)
              doc.roundedRect(photoX, y, photoSize, photoSize, 1, 1, 'S')
            }
          } catch {
            doc.setFillColor(240, 240, 240)
            doc.roundedRect(photoX, y, photoSize, photoSize, 1, 1, 'F')
            doc.setFontSize(6)
            doc.setTextColor(150, 150, 150)
            doc.text('Foto', photoX + photoSize / 2, y + photoSize / 2, { align: 'center' })
          }
          photoX += photoSize + 3
        }
        y += photoSize + 6
      }
    }

    y += 2
  }

  // ── Signatures Section ──
  if (assinaturas.length > 0) {
    if (y > 220) { doc.addPage(); y = 15 }

    doc.setFillColor(243, 244, 246)
    doc.roundedRect(margin, y, pageWidth - 2 * margin, 8, 2, 2, 'F')
    doc.setTextColor(55, 65, 81)
    doc.setFontSize(11)
    doc.setFont('helvetica', 'bold')
    doc.text('✍️ Assinaturas', margin + 4, y + 6)
    y += 12

    const sigWidth = (pageWidth - 2 * margin - 6) / 2

    for (let i = 0; i < assinaturas.length; i++) {
      const sig = assinaturas[i]
      const x = margin + (i % 2) * (sigWidth + 6)

      if (i % 2 === 0 && i > 0) y += 35
      if (y > 260) { doc.addPage(); y = 15 }

      doc.setDrawColor(220, 220, 220)
      doc.roundedRect(x, y, sigWidth, 30, 2, 2, 'S')

      if (sig.assinatura_url) {
        try {
          const sigBase64 = await loadImageAsBase64(sig.assinatura_url)
          if (sigBase64) {
            doc.addImage(sigBase64, 'PNG', x + 2, y + 2, sigWidth - 4, 16)
          }
        } catch { /* ignore */ }
      }

      doc.setFontSize(8)
      doc.setFont('helvetica', 'bold')
      doc.setTextColor(60, 60, 60)
      doc.text(sig.nome, x + 4, y + 22)

      doc.setFontSize(7)
      doc.setFont('helvetica', 'normal')
      doc.setTextColor(130, 130, 130)
      const papel = sig.papel.charAt(0).toUpperCase() + sig.papel.slice(1)
      doc.text(papel, x + 4, y + 26)

      if (sig.assinado_em) {
        doc.text(new Date(sig.assinado_em).toLocaleDateString('pt-BR'), x + sigWidth - 4, y + 26, { align: 'right' })
      }
    }
    y += 35
  }

  // ── Footer ──
  const totalPages = doc.getNumberOfPages()
  for (let i = 1; i <= totalPages; i++) {
    doc.setPage(i)
    const pageH = doc.internal.pageSize.getHeight()

    doc.setDrawColor(230, 230, 230)
    doc.line(margin, pageH - 12, pageWidth - margin, pageH - 12)

    doc.setFontSize(7)
    doc.setFont('helvetica', 'normal')
    doc.setTextColor(150, 150, 150)
    doc.text(`Condomeet Check — Gerado em ${new Date().toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' })}`, margin, pageH - 7)
    doc.text(`Página ${i} de ${totalPages}`, pageWidth - margin, pageH - 7, { align: 'right' })
  }

  // Save
  const filename = `Vistoria_${vistoria.cod_interno}_${vistoria.titulo.replace(/[^a-zA-Z0-9]/g, '_').substring(0, 30)}.pdf`
  doc.save(filename)
}
