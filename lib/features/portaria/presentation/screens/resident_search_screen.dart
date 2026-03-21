import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/core/di/injection_container.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/portaria/domain/repositories/resident_repository.dart';
import 'package:condomeet/core/utils/structure_helper.dart';
import 'package:url_launcher/url_launcher.dart';

class ResidentSearchScreen extends StatefulWidget {
  const ResidentSearchScreen({super.key});

  @override
  State<ResidentSearchScreen> createState() => _ResidentSearchScreenState();
}

class _ResidentSearchScreenState extends State<ResidentSearchScreen> {
  final _searchController = TextEditingController();
  late final ResidentRepository _repository;
  List<Resident> _residents = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _repository = sl<ResidentRepository>();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    // Cancel any pending debounce
    _debounce?.cancel();

    // Only search if query is not empty
    if (_searchController.text.isEmpty) {
      setState(() {
        _residents = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    // Debounce: wait 300ms after last keystroke before querying
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final authState = context.read<AuthBloc>().state;
      final condoId = authState.condominiumId;
      
      if (condoId == null) {
        _showError('Condomínio não identificado');
        setState(() => _isLoading = false);
        return;
      }

      final result = await _repository.searchResidents(_searchController.text, condoId);

      if (mounted) {
        if (result is Success<List<Resident>>) {
          setState(() => _residents = result.data);
        } else if (result is Failure<List<Resident>>) {
          _showError(result.message);
        }
        setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _openOcrScanner() async {
    final result = await Navigator.of(context).pushNamed('/ocr-scanner');
    
    if (result != null && result is String && mounted) {
      _searchController.text = result;
      _onSearchChanged();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar Morador'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: CondoInput(
              controller: _searchController,
              label: '',
              hint: 'Digite nome ou unidade...',
              prefix: const Icon(Icons.search, color: AppColors.textSecondary),
              suffix: IconButton(
                icon: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                onPressed: _openOcrScanner,
              ),
              onChanged: (_) => _onSearchChanged(),
              onFieldSubmitted: (_) => _onSearchChanged(),
            ),
          ),
          if (_isLoading)
            const LinearProgressIndicator(
              backgroundColor: AppColors.surface,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _residents.isEmpty && !_isLoading
                  ? _buildEmptyState()
                  : ListView.separated(
                      key: ValueKey(_residents.length),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _residents.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final resident = _residents[index];
                        return _buildResidentTile(resident);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResidentTile(Resident resident) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        child: Text(
          resident.fullName[0].toUpperCase(),
          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(resident.fullName, style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(StructureHelper.getFullUnitName(context.read<AuthBloc>().state.tipoEstrutura, resident.block ?? '?', resident.unitNumber ?? '?'), style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.border),
      onTap: () => _showResidentDetail(resident),
    );
  }

  void _showResidentDetail(Resident resident) {
    final tipoEstrutura = context.read<AuthBloc>().state.tipoEstrutura;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            // Avatar + name
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(resident.fullName[0].toUpperCase(),
                style: const TextStyle(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),
            Text(resident.fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain)),
            const SizedBox(height: 4),
            Text(
              StructureHelper.getFullUnitName(tipoEstrutura, resident.block ?? '—', resident.unitNumber ?? '—'),
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            if (resident.tipoMorador != null) ...[
              const SizedBox(height: 2),
              Text(resident.tipoMorador!, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            ],
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // Info rows
            if (resident.phoneNumber != null && resident.phoneNumber!.isNotEmpty)
              _detailRow(Icons.phone, 'Telefone', resident.phoneNumber!),
            if (resident.email != null && resident.email!.isNotEmpty)
              _detailRow(Icons.email_outlined, 'Email', resident.email!),
            _detailRow(Icons.badge_outlined, 'Perfil', resident.papelSistema ?? 'morador'),
            const SizedBox(height: 16),
            // Action buttons
            Row(
              children: [
                if (resident.phoneNumber != null && resident.phoneNumber!.isNotEmpty) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _launchUrl('tel:${resident.phoneNumber}'),
                      icon: const Icon(Icons.phone, size: 16),
                      label: const Text('Ligar', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _launchUrl('https://wa.me/55${resident.phoneNumber!.replaceAll(RegExp(r'[^0-9]'), '')}'),
                      icon: const Icon(Icons.chat, size: 16),
                      label: const Text('WhatsApp', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade400),
          const SizedBox(width: 10),
          Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMain))),
        ],
      ),
    );
  }

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildEmptyState() {
    final hasQuery = _searchController.text.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasQuery ? Icons.search_off_outlined : Icons.person_search_outlined,
            size: 64,
            color: AppColors.border,
          ),
          const SizedBox(height: 16),
          Text(
            hasQuery ? 'Nenhum morador encontrado' : 'Digite o nome ou número da unidade',
            style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          if (hasQuery) ...
            [
              const SizedBox(height: 8),
              Text(
                'Tente "João", "Jao" ou "101"',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.border),
                textAlign: TextAlign.center,
              ),
            ],
        ],
      ),
    );
  }
}
