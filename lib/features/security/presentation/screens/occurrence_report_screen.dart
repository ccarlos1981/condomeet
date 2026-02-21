import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/security/domain/models/occurrence.dart';
import 'package:condomeet/features/security/domain/repositories/occurrence_repository.dart';
import 'package:condomeet/features/security/data/repositories/occurrence_repository_impl.dart';

class OccurrenceReportScreen extends StatefulWidget {
  final String residentId;

  const OccurrenceReportScreen({super.key, required this.residentId});

  @override
  State<OccurrenceReportScreen> createState() => _OccurrenceReportScreenState();
}

class _OccurrenceReportScreenState extends State<OccurrenceReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final OccurrenceRepository _repository = OccurrenceRepositoryImpl();
  OccurrenceCategory _selectedCategory = OccurrenceCategory.maintenance;
  bool _isLoading = false;
  final List<String> _simulatedPhotos = [];

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    final result = await _repository.reportOccurrence(
      residentId: widget.residentId,
      description: _descriptionController.text,
      category: _selectedCategory,
      photoPaths: _simulatedPhotos,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result is Success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ocorrência registrada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao registrar ocorrência.')),
        );
      }
    }
  }

  void _simulatePhotoCapture() {
    if (_simulatedPhotos.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Máximo de 3 fotos atingido.')),
      );
      return;
    }
    setState(() {
      _simulatedPhotos.add('mock_photo_${_simulatedPhotos.length + 1}.jpg');
    });
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Ocorrência'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('O que aconteceu?', style: AppTypography.h1),
              const SizedBox(height: 8),
              Text(
                'Relate problemas de forma clara para que a administração possa resolvê-los.',
                style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              
              Text('Categoria', style: AppTypography.label),
              const SizedBox(height: 12),
              _buildCategorySelector(),
              
              const SizedBox(height: 24),
              
              CondoInput(
                label: 'Descrição do Problema',
                hint: 'Ex: Lâmpada do 5º andar queimada ou barulho excessivo vindo da unidade 302...',
                controller: _descriptionController,
                maxLines: 4,
                validator: (value) => value == null || value.isEmpty ? 'Descreva o problema' : null,
              ),
              
              const SizedBox(height: 32),
              
              Text('Evidências Visuais (Opcional)', style: AppTypography.label),
              const SizedBox(height: 12),
              _buildPhotoEvidenceSection(),
              
              const SizedBox(height: 48),
              
              CondoButton(
                label: 'Enviar Relato',
                isLoading: _isLoading,
                onPressed: _handleSubmit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: OccurrenceCategory.values.map((category) {
        final isSelected = _selectedCategory == category;
        final occurrence = Occurrence(
          id: '', residentId: '', description: '', 
          category: category, timestamp: DateTime.now()
        );

        return ChoiceChip(
          label: Text(occurrence.categoryName),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) setState(() => _selectedCategory = category);
          },
          selectedColor: AppColors.primary.withValues(alpha: 0.2),
          labelStyle: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textMain,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPhotoEvidenceSection() {
    return Row(
      children: [
        InkWell(
          onTap: _simulatePhotoCapture,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, style: BorderStyle.solid),
            ),
            child: const Icon(Icons.add_a_photo_outlined, color: AppColors.primary),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _simulatedPhotos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(Icons.image, color: AppColors.textSecondary),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _simulatedPhotos.removeAt(index)),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
