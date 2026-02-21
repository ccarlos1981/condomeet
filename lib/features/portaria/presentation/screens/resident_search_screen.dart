import 'package:flutter/material.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/portaria/domain/repositories/resident_repository.dart';
import 'package:condomeet/features/portaria/data/repositories/resident_repository_impl.dart';

class ResidentSearchScreen extends StatefulWidget {
  const ResidentSearchScreen({super.key});

  @override
  State<ResidentSearchScreen> createState() => _ResidentSearchScreenState();
}

class _ResidentSearchScreenState extends State<ResidentSearchScreen> {
  final _searchController = TextEditingController();
  final ResidentRepository _repository = ResidentRepositoryImpl();
  List<Resident> _residents = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _onSearchChanged();
  }

  void _onSearchChanged() async {
    setState(() => _isLoading = true);
    final result = await _repository.searchResidents(_searchController.text);
    
    if (mounted) {
      if (result is Success<List<Resident>>) {
        setState(() => _residents = result.data);
      } else if (result is Failure<List<Resident>>) {
        _showError(result.message);
      }
      setState(() => _isLoading = false);
    }
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
            ),
          ),
          if (_isLoading)
            const LinearProgressIndicator(
              backgroundColor: AppColors.surface,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          Expanded(
            child: _residents.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _residents.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final resident = _residents[index];
                      return _buildResidentTile(resident);
                    },
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
      subtitle: Text('Bloco ${resident.block} • Unidade ${resident.unitNumber}', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.border),
      onTap: () {
        Navigator.of(context).pushNamed(
          '/parcel-registration',
          arguments: resident,
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_outlined, size: 64, color: AppColors.border),
          const SizedBox(height: 16),
          Text('Nenhum morador encontrado', style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
