import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/core/di/injection_container.dart';
import 'package:condomeet/features/community/presentation/screens/booking_form_screen.dart';

/// Portaria booking screen — shows available areas immediately,
/// bloco/apto selection happens inside the BookingFormScreen.
class PortariaBookingScreen extends StatefulWidget {
  const PortariaBookingScreen({super.key});

  @override
  State<PortariaBookingScreen> createState() => _PortariaBookingScreenState();
}

class _PortariaBookingScreenState extends State<PortariaBookingScreen> {
  final _supabase = sl<SupabaseClient>();
  List<Map<String, dynamic>> _areas = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = _supabase.auth.currentUser;
    if (user == null) { setState(() => _loading = false); return; }

    final profile = await _supabase
        .from('perfil')
        .select('condominio_id')
        .eq('id', user.id)
        .maybeSingle();

    final condoId = profile?['condominio_id'] as String?;
    if (condoId == null) { setState(() => _loading = false); return; }

    final areas = await _supabase
        .from('areas_comuns')
        .select('id, tipo_agenda, local, outro_local, tipo_reserva, capacidade, hrs_cancelar, instrucao_uso, aprovacao_automatica, precos')
        .eq('condominio_id', condoId)
        .eq('ativo', true)
        .order('tipo_agenda');

    setState(() {
      _areas = List<Map<String, dynamic>>.from(areas as List);
      _loading = false;
    });
  }

  IconData _iconFor(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'salão de festa': return Icons.celebration;
      case 'churrasqueira': return Icons.outdoor_grill;
      case 'piscina': return Icons.pool;
      case 'academia': return Icons.fitness_center;
      case 'sauna': return Icons.hot_tub;
      case 'quadra de tênis':
      case 'campo de futebol': return Icons.sports;
      default: return Icons.location_on;
    }
  }

  void _openBooking(Map<String, dynamic> area) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingFormScreen(
          area: area,
          portariaMode: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Reservas (Portaria)',
          style: TextStyle(color: AppColors.textMain, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 20),
            onPressed: () { setState(() => _loading = true); _load(); },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: _areas.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 80),
                      Icon(Icons.location_city, size: 48, color: AppColors.disabledIcon),
                      SizedBox(height: 12),
                      Text(
                        'Nenhuma área disponível para reserva.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textHint, fontSize: 13),
                      ),
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _areas.length + 1,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Selecione o espaço para reservar em nome do morador',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                            ),
                          );
                        }
                        return _buildAreaCard(_areas[i - 1]);
                      },
                    ),
            ),
    );
  }

  Widget _buildAreaCard(Map<String, dynamic> area) {
    final tipo = area['tipo_agenda'] as String? ?? '—';
    final local = area['local'] as String? ?? '';
    final displayLocal = local == 'Outro' ? (area['outro_local'] as String? ?? 'Outro') : local;
    final cap = area['capacidade']?.toString() ?? '0';
    final tipoReserva = area['tipo_reserva'] as String? ?? 'por_dia';
    final isPorHora = tipoReserva == 'por_hora';
    final hrsCancelar = area['hrs_cancelar']?.toString() ?? '0';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconFor(tipo), color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tipo, style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textMain,
                  )),
                  const SizedBox(height: 2),
                  Row(children: [
                    Text(displayLocal, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isPorHora ? Colors.blue.shade50 : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isPorHora ? 'Por Hora' : 'Por Dia',
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: isPorHora ? Colors.blue.shade700 : Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ]),
                ],
              )),
              Column(children: [
                Text('Cap.', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                Text(cap, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ]),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.access_time, size: 12, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text('Cancelamento: ${hrsCancelar}h antes',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ]),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  _openBooking(area);
                },
                icon: const Icon(Icons.calendar_month, size: 18),
                label: const Text('Reservar', style: TextStyle(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
