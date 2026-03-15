import 'package:condomeet/core/design_system/design_system.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import '../bloc/invitation_bloc.dart';
import '../bloc/invitation_event.dart';
import '../bloc/invitation_state.dart';

class InvitationGeneratorScreen extends StatefulWidget {
  final String residentId;
  const InvitationGeneratorScreen({super.key, required this.residentId});

  @override
  State<InvitationGeneratorScreen> createState() => _InvitationGeneratorScreenState();
}

class _InvitationGeneratorScreenState extends State<InvitationGeneratorScreen> {
  final _nameController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isGenerating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _presentDatePicker() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _generateInvitation() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, informe o nome do convidado')),
      );
      return;
    }

    final authState = context.read<AuthBloc>().state;
    if (authState.condominiumId == null || authState.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro: Usuário não identificado')),
      );
      return;
    }

    setState(() => _isGenerating = true);
    
    context.read<InvitationBloc>().add(CreateInvitationRequested(
      residentId: authState.userId!,
      condominiumId: authState.condominiumId!,
      guestName: _nameController.text.trim(),
      validityDate: _selectedDate,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerar Convite'),
        centerTitle: true,
      ),
      body: BlocConsumer<InvitationBloc, InvitationState>(
        listener: (context, state) {
          if (state is InvitationCreated) {
            setState(() => _isGenerating = false);
            _showSuccessDialog(state.invitation.qrData, state.invitation.guestName);
          } else if (state is InvitationError) {
            setState(() => _isGenerating = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
            );
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.qr_code_2,
                  size: 64,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Crie um acesso rápido para seu convidado',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),
                CondoInput(
                  controller: _nameController,
                  label: 'Nome do Convidado',
                  hint: 'Dê um nome para o convite (ex: Aniversário)',
                prefix: const Icon(Icons.edit_note),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _presentDatePicker,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Validade',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                CondoButton(
                  label: 'Gerar Convite',
                  onPressed: _isGenerating ? null : _generateInvitation,
                  isLoading: _isGenerating,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSuccessDialog(String qrData, String guestName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Convite Gerado!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Compartilhe o código com $guestName',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 200.0,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.primary),
              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.primary),
            ),
            const SizedBox(height: 32),
            CondoButton(
              label: 'Compartilhar',
              onPressed: () {
                HapticFeedback.mediumImpact();
                SharePlus.instance.share(
                  ShareParams(
                    text: 'Olá $guestName! Aqui está seu convite para entrar no condomínio: $qrData',
                    title: 'Convite para visita - Condomeet',
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ).then((_) => Navigator.pop(context));
  }
}
