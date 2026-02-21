import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/access/domain/models/invitation.dart';
import 'package:condomeet/features/access/domain/repositories/invitation_repository.dart';
import 'package:condomeet/features/access/data/repositories/invitation_repository_impl.dart';

class InvitationGeneratorScreen extends StatefulWidget {
  final String residentId;

  const InvitationGeneratorScreen({super.key, required this.residentId});

  @override
  State<InvitationGeneratorScreen> createState() => _InvitationGeneratorScreenState();
}

class _InvitationGeneratorScreenState extends State<InvitationGeneratorScreen> {
  final InvitationRepository _repository = InvitationRepositoryImpl();
  final TextEditingController _nameController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isGenerating = false;

  Future<void> _handleGenerate() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, informe o nome do convidado.')),
      );
      return;
    }

    setState(() => _isGenerating = true);
    
    final result = await _repository.createInvitation(
      residentId: widget.residentId,
      guestName: _nameController.text,
      validityDate: _selectedDate,
    );

    if (mounted) {
      setState(() => _isGenerating = false);
      if (result is Success<Invitation>) {
        _showSuccess(result.data);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao gerar convite.')),
        );
      }
    }
  }

  void _showSuccess(Invitation invitation) {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildSuccessSheet(invitation),
    );
  }

  Widget _buildSuccessSheet(Invitation invitation) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
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
          const SizedBox(height: 24),
          const Icon(Icons.check_circle, color: Colors.green, size: 64),
          const SizedBox(height: 16),
          Text('Convite Gerado!', style: AppTypography.h2),
          const SizedBox(height: 8),
          Text(
            'Compartilhe com seu convidado para agilizar a entrada na portaria.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.qr_code_2, size: 48, color: AppColors.textMain),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(invitation.guestName, style: AppTypography.h3),
                      Text(
                        'Válido até: ${_selectedDate.day}/${_selectedDate.month}',
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          CondoButton(
            label: 'Compartilhar Convite',
            onPressed: () {
              Navigator.pop(context);
              // Simulated share logic
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Abrindo menu de compartilhamento...')),
              );
            },
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fechar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Convite'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quem é o convidado?', style: AppTypography.h2),
            const SizedBox(height: 24),
            CondoInput(
              label: 'Nome do Convidado',
              hint: 'Ex: João Silva',
              controller: _nameController,
              prefix: const Icon(Icons.person_outline),
            ),
            const SizedBox(height: 32),
            Text('Quando ele vem?', style: AppTypography.h2),
            const SizedBox(height: 16),
            _buildDateOption('Hoje', DateTime.now()),
            const SizedBox(height: 12),
            _buildDateOption('Amanhã', DateTime.now().add(const Duration(days: 1))),
            const SizedBox(height: 12),
            _buildDateOption('Outra Data', null, isCustom: true),
            const SizedBox(height: 64),
            CondoButton(
              label: 'Gerar Convite Digital',
              isLoading: _isGenerating,
              onPressed: _handleGenerate,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateOption(String label, DateTime? date, {bool isCustom = false}) {
    final isSelected = !isCustom && _selectedDate.day == date?.day && _selectedDate.month == date?.month;
    
    return InkWell(
      onTap: () {
        if (isCustom) {
          showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 30)),
          ).then((value) {
            if (value != null) setState(() => _selectedDate = value);
          });
        } else if (date != null) {
          setState(() => _selectedDate = date);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isCustom ? Icons.calendar_today_outlined : Icons.event_available,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 16),
            Text(
              isSelected && !isCustom ? label : (isCustom ? 'Selecionar no calendário' : label),
              style: AppTypography.bodyLarge.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textMain,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
