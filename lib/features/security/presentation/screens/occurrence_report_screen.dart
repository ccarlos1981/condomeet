import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/features/security/domain/models/occurrence.dart';
import 'package:condomeet/features/security/presentation/bloc/occurrence_bloc.dart';
import 'package:condomeet/features/security/presentation/bloc/occurrence_event.dart';
import 'package:condomeet/features/security/presentation/bloc/occurrence_state.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';

class OccurrenceReportScreen extends StatefulWidget {
  final String residentId;

  const OccurrenceReportScreen({super.key, required this.residentId});

  @override
  State<OccurrenceReportScreen> createState() => _OccurrenceReportScreenState();
}

class _OccurrenceReportScreenState extends State<OccurrenceReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _assuntoController = TextEditingController();
  final _descriptionController = TextEditingController();
  OccurrenceCategory _selectedCategory = OccurrenceCategory.maintenance;
  XFile? _selectedPhoto;
  bool _isUploadingPhoto = false;

  @override
  void dispose() {
    _assuntoController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handlePhotoCapture() async {
    final picker = ImagePicker();
    final source = await _showPhotoSourceDialog();
    if (source == null) return;

    final photo = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );

    if (photo != null) {
      setState(() => _selectedPhoto = photo);
      HapticFeedback.lightImpact();
    }
  }

  Future<ImageSource?> _showPhotoSourceDialog() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                title: const Text('Tirar foto'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.primary),
                title: const Text('Escolher da galeria'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _uploadPhoto() async {
    if (_selectedPhoto == null) return null;

    try {
      setState(() => _isUploadingPhoto = true);
      final supabase = Supabase.instance.client;
      final bytes = await File(_selectedPhoto!.path).readAsBytes();
      final fileName = 'ocorrencia_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '${widget.residentId}/$fileName';

      await supabase.storage
          .from('ocorrencias-fotos')
          .uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));

      return supabase.storage.from('ocorrencias-fotos').getPublicUrl(path);
    } catch (e) {
      return null;
    } finally {
      setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final authState = context.read<AuthBloc>().state;
    if (authState.condominiumId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro: Condomínio não identificado.')),
      );
      return;
    }

    HapticFeedback.mediumImpact();

    // Upload photo if selected
    String? photoUrl;
    if (_selectedPhoto != null) {
      photoUrl = await _uploadPhoto();
    }

    if (!mounted) return;

    context.read<OccurrenceBloc>().add(
      ReportOccurrenceRequested(
        residentId: widget.residentId,
        condominiumId: authState.condominiumId!,
        assunto: _assuntoController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        photoUrl: photoUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OccurrenceBloc, OccurrenceState>(
      listener: (context, state) {
        if (state is OccurrenceSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ocorrência registrada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        } else if (state is OccurrenceError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is OccurrenceLoading || _isUploadingPhoto;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Nova Ocorrência'),
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
                    'Relate o problema para que a administração possa resolver.',
                    style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 32),

                  // Assunto
                  CondoInput(
                    label: 'Assunto',
                    hint: 'Ex: Lâmpada queimada, vazamento, barulho...',
                    controller: _assuntoController,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Informe o assunto'
                        : null,
                  ),

                  const SizedBox(height: 20),

                  // Categoria
                  Text('Categoria', style: AppTypography.label),
                  const SizedBox(height: 12),
                  _buildCategorySelector(),

                  const SizedBox(height: 20),

                  // Descrição
                  CondoInput(
                    label: 'Descrição da Ocorrência',
                    hint: 'Descreva o problema com detalhes...',
                    controller: _descriptionController,
                    maxLines: 4,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Descreva o problema'
                        : null,
                  ),

                  const SizedBox(height: 24),

                  // Foto
                  Text('Foto (Opcional)', style: AppTypography.label),
                  const SizedBox(height: 12),
                  _buildPhotoSection(),

                  const SizedBox(height: 48),

                  CondoButton(
                    label: isLoading
                        ? (_isUploadingPhoto ? 'Enviando foto...' : 'Registrando...')
                        : 'Enviar Ocorrência',
                    isLoading: isLoading,
                    onPressed: isLoading ? null : _handleSubmit,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategorySelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: OccurrenceCategory.values.map((category) {
        final isSelected = _selectedCategory == category;
        final names = {
          OccurrenceCategory.maintenance: 'Manutenção',
          OccurrenceCategory.security: 'Segurança',
          OccurrenceCategory.noise: 'Barulho',
          OccurrenceCategory.others: 'Outros',
        };

        return ChoiceChip(
          label: Text(names[category]!),
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

  Widget _buildPhotoSection() {
    if (_selectedPhoto != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(_selectedPhoto!.path),
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => setState(() => _selectedPhoto = null),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: _handlePhotoCapture,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.border,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 32),
            const SizedBox(height: 8),
            Text(
              'Adicionar foto',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.primary),
            ),
            Text(
              'Câmera ou galeria',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
