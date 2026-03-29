import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class VistoriaPdfGenerator {
  static Future<File> generate({
    required Map<String, dynamic> vistoria,
    required List<Map<String, dynamic>> secoes,
    required List<Map<String, dynamic>> itens,
    required List<Map<String, dynamic>> fotos,
    required List<Map<String, dynamic>> assinaturas,
  }) async {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
      ),
    );

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final createdAt = DateTime.tryParse(vistoria['created_at'] ?? '');
    final titulo = vistoria['titulo'] ?? 'Vistoria';
    final codInterno = vistoria['cod_interno'] ?? '';
    final tipoVistoria = (vistoria['tipo_vistoria'] as String? ?? 'entrada').toUpperCase();
    final tipoBem = vistoria['tipo_bem'] ?? '';
    final endereco = vistoria['endereco'] ?? '';
    final status = vistoria['status'] ?? 'rascunho';
    final responsavel = vistoria['responsavel_nome'] ?? '';
    final proprietario = vistoria['proprietario_nome'] ?? '';
    final inquilino = vistoria['inquilino_nome'] ?? '';

    // Pre-download photos (max 3 per item to keep PDF reasonable)
    final photoCache = <String, Uint8List>{};
    for (final foto in fotos) {
      final url = foto['foto_url'] as String? ?? '';
      if (url.isNotEmpty && !photoCache.containsKey(url)) {
        try {
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            photoCache[url] = response.bodyBytes;
          }
        } catch (_) {}
      }
    }

    // Pre-download signature images
    final sigCache = <String, Uint8List>{};
    for (final a in assinaturas) {
      final url = a['assinatura_url'] as String? ?? '';
      if (url.isNotEmpty) {
        try {
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            sigCache[url] = response.bodyBytes;
          }
        } catch (_) {}
      }
    }

    // ── Cover Page ──
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(height: 60),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(30),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(12),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'RELATÓRIO DE VISTORIA',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: tipoVistoria == 'ENTRADA'
                          ? PdfColors.green100
                          : PdfColors.orange100,
                      borderRadius: pw.BorderRadius.circular(20),
                    ),
                    child: pw.Text(
                      'VISTORIA DE $tipoVistoria',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: tipoVistoria == 'ENTRADA'
                            ? PdfColors.green800
                            : PdfColors.orange800,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Divider(color: PdfColors.grey300),
                  pw.SizedBox(height: 16),
                  _infoRow('Título', titulo),
                  _infoRow('Código', '#$codInterno'),
                  if (endereco.isNotEmpty) _infoRow('Endereço', endereco),
                  _infoRow('Tipo de Bem', _tipoBemLabel(tipoBem)),
                  _infoRow('Status', _statusLabel(status)),
                  if (createdAt != null)
                    _infoRow('Criado em', dateFormat.format(createdAt)),
                  pw.SizedBox(height: 16),
                  pw.Divider(color: PdfColors.grey300),
                  pw.SizedBox(height: 16),
                  pw.Text(
                    'PARTES ENVOLVIDAS',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  if (responsavel.isNotEmpty)
                    _infoRow('Responsável', responsavel),
                  if (proprietario.isNotEmpty)
                    _infoRow('Proprietário', proprietario),
                  if (inquilino.isNotEmpty)
                    _infoRow('Inquilino', inquilino),
                  if (responsavel.isEmpty &&
                      proprietario.isEmpty &&
                      inquilino.isEmpty)
                    pw.Text(
                      'Não informado',
                      style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.grey500,
                      ),
                    ),
                ],
              ),
            ),
            pw.Spacer(),
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'Condomeet',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey500,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Gerado em ${dateFormat.format(DateTime.now())}',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // ── Section Pages ──
    for (final secao in secoes) {
      final secaoItens = itens
          .where((i) => i['secao_id'] == secao['id'])
          .toList()
        ..sort((a, b) =>
            (a['posicao'] as int? ?? 0).compareTo(b['posicao'] as int? ?? 0));

      if (secaoItens.isEmpty) continue;

      final widgets = <pw.Widget>[
        // Section title
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey800,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Text(
            '${secao['icone_emoji'] ?? ''} ${secao['nome'] ?? ''}',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ),
        pw.SizedBox(height: 12),
      ];

      for (final item in secaoItens) {
        final itemFotos =
            fotos.where((f) => f['item_id'] == item['id']).toList();
        final statusText = _itemStatusLabel(item['status'] as String? ?? 'ok');
        final statusColor = _itemStatusColor(item['status'] as String? ?? 'ok');
        final obs = item['observacao'] as String? ?? '';

        widgets.add(
          pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.only(bottom: 8),
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Item header
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        item['nome'] ?? '',
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: pw.BoxDecoration(
                        color: statusColor,
                        borderRadius: pw.BorderRadius.circular(12),
                      ),
                      child: pw.Text(
                        statusText,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                // Observation
                if (obs.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Obs: $obs',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
                // Photos
                if (itemFotos.isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  pw.Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: itemFotos.take(4).map((f) {
                      final url = f['foto_url'] as String? ?? '';
                      final bytes = photoCache[url];
                      if (bytes != null) {
                        return pw.Container(
                          width: 120,
                          height: 90,
                          decoration: pw.BoxDecoration(
                            borderRadius: pw.BorderRadius.circular(6),
                            border: pw.Border.all(color: PdfColors.grey200),
                          ),
                          child: pw.ClipRRect(
                            horizontalRadius: 6,
                            verticalRadius: 6,
                            child: pw.Image(
                              pw.MemoryImage(bytes),
                              fit: pw.BoxFit.cover,
                            ),
                          ),
                        );
                      }
                      return pw.Container(
                        width: 120,
                        height: 90,
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey200,
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Center(
                          child: pw.Text('📷', style: const pw.TextStyle(fontSize: 20)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        );
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (context) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '$titulo — #$codInterno',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey500,
                  ),
                ),
                pw.Text(
                  'Condomeet',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey400,
                  ),
                ),
              ],
            ),
          ),
          footer: (context) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  dateFormat.format(DateTime.now()),
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400),
                ),
                pw.Text(
                  'Página ${context.pageNumber}/${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400),
                ),
              ],
            ),
          ),
          build: (context) => widgets,
        ),
      );
    }

    // ── Signatures Page ──
    if (assinaturas.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey800,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  '✍️ Assinaturas',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
              pw.SizedBox(height: 16),
              ...assinaturas.map((a) {
                final sigUrl = a['assinatura_url'] as String? ?? '';
                final sigBytes = sigCache[sigUrl];
                final assinadoEm = a['assinado_em'] != null
                    ? DateTime.tryParse(a['assinado_em'] as String)
                    : null;

                return pw.Container(
                  width: double.infinity,
                  margin: const pw.EdgeInsets.only(bottom: 16),
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            a['nome'] ?? '',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.grey200,
                              borderRadius: pw.BorderRadius.circular(10),
                            ),
                            child: pw.Text(
                              (a['papel'] as String? ?? '').toUpperCase(),
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 12),
                      if (sigBytes != null)
                        pw.Center(
                          child: pw.Container(
                            width: 200,
                            height: 80,
                            child: pw.Image(
                              pw.MemoryImage(sigBytes),
                              fit: pw.BoxFit.contain,
                            ),
                          ),
                        )
                      else
                        pw.Container(
                          width: double.infinity,
                          height: 60,
                          decoration: pw.BoxDecoration(
                            border: pw.Border(
                              bottom: pw.BorderSide(color: PdfColors.grey400),
                            ),
                          ),
                          child: pw.Center(
                            child: pw.Text(
                              'Assinatura pendente',
                              style: const pw.TextStyle(
                                color: PdfColors.grey400,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      pw.SizedBox(height: 8),
                      if (assinadoEm != null)
                        pw.Text(
                          'Assinado em: ${dateFormat.format(assinadoEm)}',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey500,
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      );
    }

    // Save to temp file
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/vistoria_${codInterno}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey600,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  static String _tipoBemLabel(String tipo) {
    const labels = {
      'apartamento': '🏢 Apartamento',
      'casa': '🏠 Casa',
      'sala_comercial': '🏪 Sala Comercial',
      'kitnet': '🛏️ Kitnet',
      'cobertura': '🌇 Cobertura',
      'loja': '🏬 Loja',
    };
    return labels[tipo] ?? tipo;
  }

  static String _statusLabel(String status) {
    const labels = {
      'rascunho': '📝 Rascunho',
      'em_andamento': '🔄 Em Andamento',
      'concluida': '✅ Concluída',
      'assinada': '✍️ Assinada',
    };
    return labels[status] ?? status;
  }

  static String _itemStatusLabel(String status) {
    const labels = {
      'ok': '✅ OK',
      'atencao': '⚠️ Atenção',
      'danificado': '❌ Danificado',
      'nao_existe': 'N/A',
    };
    return labels[status] ?? status;
  }

  static PdfColor _itemStatusColor(String status) {
    switch (status) {
      case 'ok':
        return PdfColors.green;
      case 'atencao':
        return PdfColors.amber;
      case 'danificado':
        return PdfColors.red;
      case 'nao_existe':
        return PdfColors.grey;
      default:
        return PdfColors.grey;
    }
  }
}
