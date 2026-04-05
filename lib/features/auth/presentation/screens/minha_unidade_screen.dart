import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/app_colors.dart';

class MinhaUnidadeScreen extends StatefulWidget {
  final String userId;
  final String condominioId;

  const MinhaUnidadeScreen({
    super.key,
    required this.userId,
    required this.condominioId,
  });

  @override
  State<MinhaUnidadeScreen> createState() => _MinhaUnidadeScreenState();
}

class _MinhaUnidadeScreenState extends State<MinhaUnidadeScreen> {
  bool _isLoading = true;
  String? _blocoTxt;
  String? _aptoTxt;
  List<Map<String, dynamic>> _residents = [];
  
  // Dummy data for vehicles and pets for now
  final List<Map<String, dynamic>> _vehicles = [];
  final List<Map<String, dynamic>> _pets = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch current user's profile to get their bloco and apto
      final userProfile = await Supabase.instance.client
          .from('perfil')
          .select('bloco_txt, apto_txt')
          .eq('id', widget.userId)
          .single();

      _blocoTxt = userProfile['bloco_txt'];
      _aptoTxt = userProfile['apto_txt'];

      if (_blocoTxt != null && _aptoTxt != null) {
        // 2. Fetch all residents for this unit
        final data = await Supabase.instance.client
            .from('perfil')
            .select('nome_completo, tipo_morador, bloco_txt, apto_txt, email, whatsapp, created_at')
            .eq('condominio_id', widget.condominioId)
            .eq('bloco_txt', _blocoTxt!)
            .eq('apto_txt', _aptoTxt!)
            .order('nome_completo');
            
        setState(() {
          _residents = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint('Error loading minha unidade: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha Unidade', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_blocoTxt != null && _aptoTxt != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        'Unidade: ${_blocoTxt != 'N/A' ? _blocoTxt : ''} - $_aptoTxt',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                  
                  // Residents
                  _buildSectionHeader('Moradores da Unidade', Icons.people_outline),
                  if (_residents.isEmpty) 
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Nenhum morador encontrado.'),
                    )
                  else
                    ..._residents.map((r) => _buildResidentCard(r)),

                  const SizedBox(height: 24),
                  
                  // Vehicles
                  _buildSectionHeader('Veículos', Icons.directions_car_outlined),
                  if (_vehicles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Nenhum veículo cadastrado.', style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ..._vehicles.map((v) => _buildVehicleCard(v)),

                  const SizedBox(height: 24),

                  // Pets
                  _buildSectionHeader('Animais de Estimação', Icons.pets_outlined),
                  if (_pets.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Nenhum animal cadastrado.', style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ..._pets.map((p) => _buildPetCard(p)),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildResidentCard(Map<String, dynamic> resident) {
    final nome = resident['nome_completo'] ?? 'Sem nome';
    final perfil = resident['tipo_morador'] ?? 'Morador';
    final email = resident['email'] ?? 'Não informado';
    final whatsapp = resident['whatsapp'] ?? 'Não informado';
    final createdAt = resident['created_at'] != null 
        ? DateTime.tryParse(resident['created_at'])?.toLocal().toString().split(' ')[0] ?? 'Desconhecida'
        : 'Desconhecida';
        
    // Format date string to dd/mm/yyyy
    String formattedDate = createdAt;
    if (createdAt != 'Desconhecida' && createdAt.contains('-')) {
      final parts = createdAt.split('-');
      if (parts.length == 3) {
        formattedDate = '${parts[2]}/${parts[1]}/${parts[0]}';
      }
    }

    final bool isPrivileged = perfil.toLowerCase().contains('síndico') || 
                              perfil.toLowerCase().contains('sindico') || 
                              perfil.toLowerCase().contains('admin');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isPrivileged ? AppColors.primary.withOpacity(0.5) : Colors.grey.shade200,
          width: isPrivileged ? 1.5 : 1.0,
        ),
      ),
      elevation: 0,
      color: isPrivileged ? AppColors.primary.withOpacity(0.02) : Colors.white,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          collapsedIconColor: AppColors.primary,
          iconColor: AppColors.primary,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isPrivileged ? AppColors.primary.withOpacity(0.2) : AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPrivileged ? Icons.admin_panel_settings : Icons.person, 
                  color: AppColors.primary, 
                  size: 20
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nome,
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 15,
                        color: isPrivileged ? AppColors.primary : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      perfil,
                      style: TextStyle(
                        color: isPrivileged ? AppColors.primary : Colors.grey.shade600, 
                        fontSize: 13,
                        fontWeight: isPrivileged ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isPrivileged ? AppColors.primary.withOpacity(0.3) : Colors.grey.shade200
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow(Icons.email_outlined, 'E-mail:', email),
                    const SizedBox(height: 8),
                    _infoRow(Icons.phone_outlined, 'WhatsApp:', whatsapp),
                    const SizedBox(height: 8),
                    _infoRow(Icons.calendar_today_outlined, 'Data de cadastro:', formattedDate),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade700),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleCard(Map<String, dynamic> vehicle) {
    return const SizedBox();
  }

  Widget _buildPetCard(Map<String, dynamic> pet) {
    return const SizedBox();
  }
}
