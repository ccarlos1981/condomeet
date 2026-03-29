import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:geolocator/geolocator.dart';
import 'package:shimmer/shimmer.dart';
import 'package:condomeet/features/lista_mercado/lista_mercado_service.dart';

class ScannerReceiptScreen extends StatefulWidget {
  const ScannerReceiptScreen({super.key});

  @override
  State<ScannerReceiptScreen> createState() => _ScannerReceiptScreenState();
}

class _ScannerReceiptScreenState extends State<ScannerReceiptScreen> {
  final _service = ListaMercadoService();
  final _picker = ImagePicker();
  final _client = Supabase.instance.client;

  bool _processing = false;
  bool _saving = false;
  File? _imageFile;

  // OCR results
  List<Map<String, dynamic>> _extractedItems = [];
  String? _supermarketName;
  String? _matchedMarketId;
  String? _cnpj;
  String? _receiptDate;
  double? _receiptTotal;
  String? _errorMessage;

  // Selected items for import
  final Set<int> _selectedItems = {};

  // Location/Supermarket state
  List<Map<String, dynamic>> _supermarkets = [];
  bool _loadingSupermarkets = true;
  double? _userLat;
  double? _userLng;

  @override
  void initState() {
    super.initState();
    _loadSupermarketsWithLocation();
  }

  Future<void> _loadSupermarketsWithLocation() async {
    setState(() {
      _loadingSupermarkets = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Serviço de localização desativado.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permissão negada.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permissão negada permanentemente.');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      _userLat = position.latitude;
      _userLng = position.longitude;

      final markets = await _service.getNearbySupermarkets(position.latitude, position.longitude);
      _sortByDistance(markets);
      
      if (mounted) {
        setState(() {
          _supermarkets = markets.take(15).toList();
          _loadingSupermarkets = false;
        });
      }
    } catch (e) {
      debugPrint('Erro GPS/Places: $e');
      try {
        final markets = await _service.getSupermarkets();
        if (mounted) {
          setState(() {
            _supermarkets = markets;
            _loadingSupermarkets = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() { _loadingSupermarkets = false; });
      }
    }
  }

  void _sortByDistance(List<Map<String, dynamic>> markets) {
    if (_userLat == null || _userLng == null) return;
    for (final m in markets) {
      final lat = m['latitude'] as num?;
      final lng = m['longitude'] as num?;
      if (lat != null && lng != null) {
        final dist = Geolocator.distanceBetween(
          _userLat!, _userLng!, lat.toDouble(), lng.toDouble(),
        );
        m['_distance'] = dist;
      } else {
        m['_distance'] = double.infinity;
      }
    }
    markets.sort((a, b) =>
      ((a['_distance'] as double?) ?? double.infinity)
          .compareTo((b['_distance'] as double?) ?? double.infinity));
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    return '${meters.round()} m';
  }

  void _showMarketSelector() {
    String localSearch = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final filteredMarkets = _supermarkets.where((m) {
              final name = (m['name'] as String?)?.toLowerCase() ?? '';
              return name.contains(localSearch.toLowerCase().trim());
            }).toList();

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.55,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Buscar mercado...',
                        prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      onChanged: (v) => setModalState(() => localSearch = v),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredMarkets.length,
                      itemBuilder: (context, index) {
                        final m = filteredMarkets[index];
                        final dist = m['_distance'] as double?;
                        final distText = dist != null && dist != double.infinity ? _formatDistance(dist) : null;
                        
                        return ListTile(
                          dense: true,
                          title: Text(m['name'] ?? '', style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.w600)),
                          trailing: distText != null 
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(distText, style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 12)),
                              )
                            : null,
                          onTap: () {
                            setState(() { _matchedMarketId = m['id']; });
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

  Future<void> _captureImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 2400,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() {
      _imageFile = File(picked.path);
      _extractedItems = [];
      _errorMessage = null;
    });

    _processImage();
  }

  Future<void> _processImage() async {
    if (_imageFile == null) return;

    setState(() => _processing = true);

    try {
      // Convert to base64
      final bytes = await _imageFile!.readAsBytes();
      final base64Image = base64Encode(bytes);
      debugPrint('[OCR] Image size: ${bytes.length} bytes, base64 length: ${base64Image.length}');

      // Call OCR edge function
      final response = await _client.functions.invoke(
        'lista-ocr-receipt',
        body: {'image_base64': base64Image},
      );

      debugPrint('[OCR] Response status: ${response.status}');

      if (response.status != 200) {
        final errorData = response.data;
        String errorMsg = 'Erro no OCR';
        if (errorData is Map) {
          errorMsg = errorData['error']?.toString() ?? 'desconhecido';
          final debug = errorData['debug'];
          if (debug != null) errorMsg += ' (debug: $debug)';
        }
        setState(() {
          _errorMessage = errorMsg;
          _processing = false;
        });
        return;
      }

      final data = response.data as Map<String, dynamic>;

      final rawItems = List<Map<String, dynamic>>.from(data['items'] ?? []);
      
      // Validação imediata: busca prévia no catálogo para saber quem ganha check verde vs novo
      for (var item in rawItems) {
        final results = await _service.searchProducts(item['name'] ?? '');
        if (results.isNotEmpty) {
          final variants = List<Map<String, dynamic>>.from(results.first['lista_product_variants'] ?? []);
          if (variants.isNotEmpty) {
            item['matched_variant_id'] = variants.first['id'];
          }
        }
      }

      setState(() {
        _extractedItems = rawItems;
        _supermarketName = data['supermarket_name'];
        _matchedMarketId = data['matched_supermarket_id'];
        _cnpj = data['cnpj'];
        _receiptDate = data['date'];
        _receiptTotal = data['total'] != null ? (data['total'] as num).toDouble() : null;
        _processing = false;
        // Select all by default
        _selectedItems.clear();
        for (int i = 0; i < _extractedItems.length; i++) {
          _selectedItems.add(i);
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro: $e';
        _processing = false;
      });
    }
  }

  Future<void> _importPrices() async {
    if (_selectedItems.isEmpty) return;

    final marketId = _matchedMarketId;
    if (marketId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o mercado primeiro'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _saving = true);
    int importedCount = 0;
    int suggestionsCount = 0;

    try {
      for (final idx in _selectedItems) {
        final item = _extractedItems[idx];
        final price = (item['unit_price'] as num?)?.toDouble() ?? (item['total_price'] as num?)?.toDouble();
        if (price == null || price <= 0) continue;

        final brand = item['brand'] as String?;
        final weightLabel = item['weight_label'] as String?;

        if (item['matched_variant_id'] != null) {
          await _service.submitPriceReport(
            variantId: item['matched_variant_id'],
            supermarketId: marketId,
            price: price,
            brand: brand,
            weightLabel: weightLabel,
          );
          importedCount++;
        } else {
          await _service.submitProductSuggestion(
            rawName: item['name'] ?? 'Desconhecido',
            supermarketId: marketId,
            unitPrice: (item['unit_price'] as num?)?.toDouble(),
            totalPrice: (item['total_price'] as num?)?.toDouble(),
            quantity: (item['quantity'] as num?)?.toDouble(),
            brand: brand,
            weightLabel: weightLabel,
          );
          suggestionsCount++;
        }
      }

      int totalHandled = importedCount + suggestionsCount;

      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$totalHandled itens processados! +${totalHandled * 10} pontos'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
        if (totalHandled > 0) Navigator.pop(context, totalHandled);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: IconThemeData(color: Colors.grey.shade800),
        title: Row(
          children: [
            Icon(Icons.document_scanner, color: Colors.grey.shade800, size: 22),
            const SizedBox(width: 8),
            Text('Escanear Cupom', style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: _extractedItems.isEmpty && !_processing
          ? _buildCaptureView()
          : _processing
              ? _buildProcessingView()
              : _buildResultsView(),
    );
  }

  Widget _buildCaptureView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Center(child: Icon(Icons.receipt_long, size: 60, color: Colors.green.shade700)),
            ),
            const SizedBox(height: 24),
            Text('Escaneie seu cupom fiscal', style: TextStyle(color: Colors.grey.shade900, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Tire uma foto do cupom e importamos os preços automaticamente',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
            const SizedBox(height: 32),

            // Camera button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _captureImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt, color: Colors.white),
                label: const Text('Tirar Foto', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Gallery button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => _captureImage(ImageSource.gallery),
                icon: Icon(Icons.photo_library, color: Colors.green.shade700),
                label: Text('Da Galeria', style: TextStyle(color: Colors.green.shade700, fontSize: 16, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.green.shade700),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700, fontSize: 13), textAlign: TextAlign.center),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image preview
          if (_imageFile != null)
            Container(
              width: 200, height: 280,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(_imageFile!, fit: BoxFit.cover),
              ),
            ),
          const CircularProgressIndicator(color: Color(0xFF2E7D32)),
          const SizedBox(height: 16),
          Text('Lendo cupom...', style: TextStyle(color: Colors.grey.shade900, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Extraindo produtos e preços', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildResultsView() {
    return Column(
      children: [
        // Header com info do cupom
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.receipt_long, color: Colors.grey.shade700, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_supermarketName ?? 'Mercado não identificado',
                            style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.bold, fontSize: 16)),
                        if (_receiptDate != null || _cnpj != null)
                          Text('${_receiptDate ?? ''} ${_cnpj != null ? '• CNPJ: $_cnpj' : ''}',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (_receiptTotal != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Total', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                        Text('R\$ ${_receiptTotal!.toStringAsFixed(2)}',
                            style: TextStyle(color: Colors.green.shade700, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // Market selection if not matched
              if (_matchedMarketId == null)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  child: _loadingSupermarkets
                      ? Shimmer.fromColors(
                          baseColor: Colors.grey.shade200,
                          highlightColor: Colors.white,
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                          ),
                        )
                      : GestureDetector(
                          onTap: _showMarketSelector,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _matchedMarketId == null 
                                      ? 'Selecione o mercado' 
                                      : (_supermarkets.firstWhere((m) => m['id'] == _matchedMarketId, orElse: () => {'name': 'Mercado alterado'})['name'] ?? ''),
                                    style: TextStyle(color: _matchedMarketId == null ? Colors.orange.shade700 : Colors.grey.shade900, 
                                    fontSize: 13, fontWeight: _matchedMarketId == null ? FontWeight.normal : FontWeight.w600),
                                  ),
                                ),
                                Icon(Icons.keyboard_arrow_down, color: Colors.orange.shade700, size: 20),
                              ],
                            ),
                          ),
                        ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF2E7D32).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text('${_extractedItems.length} itens encontrados', style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_selectedItems.length == _extractedItems.length) {
                          _selectedItems.clear();
                        } else {
                          _selectedItems.clear();
                          for (int i = 0; i < _extractedItems.length; i++) _selectedItems.add(i);
                        }
                      });
                    },
                    child: Text(
                      _selectedItems.length == _extractedItems.length ? 'Desmarcar todos' : 'Selecionar todos',
                      style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Items list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: _extractedItems.length,
            itemBuilder: (ctx, i) => _buildExtractedItem(i, _extractedItems[i]),
          ),
        ),

        // Bottom action bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              // Retry
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.grey.shade600),
                onPressed: () => setState(() { _extractedItems = []; _imageFile = null; _errorMessage = null; }),
              ),
              const SizedBox(width: 8),
              // Import button
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saving || _selectedItems.isEmpty ? null : _importPrices,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      disabledBackgroundColor: Colors.grey.shade200,
                    ),
                    child: _saving
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        : Text(
                            'Importar ${_selectedItems.length} preços (+${_selectedItems.length * 10} pts)',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExtractedItem(int index, Map<String, dynamic> item) {
    final isSelected = _selectedItems.contains(index);
    final name = item['name'] ?? '';
    final qty = item['quantity'] ?? 1;
    final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0;
    final totalPrice = (item['total_price'] as num?)?.toDouble() ?? 0;
    final isMatched = item['matched_variant_id'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isSelected ? const Color(0xFF2E7D32).withValues(alpha: 0.3) : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Checkbox
          GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) { _selectedItems.remove(index); } else { _selectedItems.add(index); }
              });
            },
            child: Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF2E7D32) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isSelected ? const Color(0xFF2E7D32) : Colors.grey.shade400, width: 2),
              ),
              child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(name, 
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: isSelected ? Colors.grey.shade900 : Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (isMatched)
                      const Tooltip(message: 'Item reconhecido no catálogo', child: Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 14))
                    else
                      const Tooltip(message: 'Item novo! Envie para catalogar', child: Icon(Icons.new_releases_rounded, color: Colors.orange, size: 14)),
                  ],
                ),
                Text('${qty}x • R\$ ${unitPrice.toStringAsFixed(2)}/un',
                    style: TextStyle(color: isSelected ? Colors.grey.shade500 : Colors.grey.shade400, fontSize: 11)),
              ],
            ),
          ),
          // Total
          Text('R\$ ${totalPrice.toStringAsFixed(2)}',
              style: TextStyle(color: isSelected ? Colors.green.shade700 : Colors.grey.shade400, fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }
}
