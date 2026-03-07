import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/access/presentation/bloc/invitation_bloc.dart';
import 'package:condomeet/features/access/presentation/bloc/invitation_event.dart';
import 'package:condomeet/features/access/presentation/bloc/invitation_state.dart';
import 'package:condomeet/features/access/domain/models/invitation.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:qr_flutter/qr_flutter.dart';

class VisitorAuthorizationScreen extends StatefulWidget {
  const VisitorAuthorizationScreen({super.key});

  @override
  State<VisitorAuthorizationScreen> createState() => _VisitorAuthorizationScreenState();
}

class _VisitorAuthorizationScreenState extends State<VisitorAuthorizationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _obsController = TextEditingController();
  
  String? _visitorType;
  DateTime _selectedDate = DateTime.now();
  final _phoneMask = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  final List<String> _visitorTypes = [
    'Visitante',
    'Prestador de Serviço',
    'Entrega/Delivery',
    'Familiar',
  ];

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState.userId != null) {
      context.read<InvitationBloc>().add(
        LoadResidentInvitationsPaginated(residentId: authState.userId!, isRefresh: true),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _obsController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate() && _visitorType != null) {
      final authState = context.read<AuthBloc>().state;
      context.read<InvitationBloc>().add(
        CreateInvitationRequested(
          residentId: authState.userId!,
          condominiumId: authState.condominiumId!,
          guestName: _nameController.text,
          validityDate: _selectedDate,
          visitorType: _visitorType,
          visitorPhone: _phoneController.text,
          observation: _obsController.text,
        ),
      );
    } else if (_visitorType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, escolha o tipo de visitante')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    
    return BlocListener<InvitationBloc, InvitationState>(
      listener: (context, state) {
        if (state is InvitationCreated) {
          _showQrCodeDialog(state.invitation);
          _clearForm();
          // Reload list
          context.read<InvitationBloc>().add(
            LoadResidentInvitationsPaginated(residentId: authState.userId!, isRefresh: true),
          );
        } else if (state is InvitationError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Aprovações Pendentes',
            style: AppTypography.h2.copyWith(color: Colors.black87),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              _buildForm(authState),
              _buildInvitationsList(authState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(AuthState authState) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Text(
              'Autorizado por ${authState.userName ?? 'Morador'}',
              style: AppTypography.h3.copyWith(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              'Acesso para:',
              style: AppTypography.h2.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Dropdown Tipo
            DropdownButtonFormField<String>(
              value: _visitorType,
              decoration: _inputDecoration('Escolha o tipo de visitante'),
              items: _visitorTypes.map((type) {
                return DropdownMenuItem(value: type, child: Text(type));
              }).toList(),
              onChanged: (value) => setState(() => _visitorType = value),
              validator: (v) => v == null ? 'Campo obrigatório' : null,
            ),
            const SizedBox(height: 12),
            
            // Data
            GestureDetector(
              onTap: () => _selectDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('dd/MM/yyyy').format(_selectedDate),
                      style: AppTypography.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Envie a autorização para seu visitante (Opcional).',
              style: AppTypography.bodySmall.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            
            // Nome
            TextFormField(
              controller: _nameController,
              decoration: _inputDecoration('Nome do visitante'),
              validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
            ),
            const SizedBox(height: 12),
            
            // Whatsapp
            TextFormField(
              controller: _phoneController,
              inputFormatters: [_phoneMask],
              keyboardType: TextInputType.phone,
              decoration: _inputDecoration('Whatsapp (00) 0 0000-0000'),
            ),
            const SizedBox(height: 12),
            
            // Observação
            TextFormField(
              controller: _obsController,
              maxLines: 3,
              decoration: _inputDecoration('Observação (Opcional)'),
            ),
            const SizedBox(height: 20),
            
            CondoButton(
              label: 'Registrar visita',
              onPressed: _handleSubmit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvitationsList(AuthState authState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            'Suas autorizações de acesso.',
            style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        BlocBuilder<InvitationBloc, InvitationState>(
          builder: (context, state) {
            if (state is InvitationLoading) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ));
            }
            
            if (state is InvitationLoaded) {
              if (state.invitations.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: Text('Nenhuma autorização encontrada'),
                  ),
                );
              }

              return Column(
                children: [
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.invitations.length,
                    itemBuilder: (context, index) {
                      final inv = state.invitations[index];
                      return _buildInvitationCard(inv);
                    },
                  ),
                  if (state.hasMore)
                    TextButton(
                      onPressed: () {
                        context.read<InvitationBloc>().add(
                          LoadResidentInvitationsPaginated(
                            residentId: authState.userId!,
                            offset: state.offset,
                          ),
                        );
                      },
                      child: const Text('Carregar mais'),
                    ),
                  const SizedBox(height: 32),
                ],
              );
            }
            
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildInvitationCard(Invitation inv) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_outline, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(inv.guestName, style: AppTypography.h3),
                Text(
                  '${inv.visitorType ?? 'Visita'} - ${DateFormat('dd/MM/yyyy').format(inv.validityDate)}',
                  style: AppTypography.bodySmall.copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code, color: Colors.grey),
            onPressed: () => _showQrCodeDialog(inv),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      hintText: label,
      hintStyle: AppTypography.bodyMedium.copyWith(color: Colors.grey.shade400),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primary),
      ),
    );
  }

  void _clearForm() {
    _nameController.clear();
    _phoneController.clear();
    _obsController.clear();
    setState(() {
      _visitorType = null;
      _selectedDate = DateTime.now();
    });
  }

  void _showQrCodeDialog(Invitation invitation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Autorização Gerada', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: invitation.qrData,
              version: QrVersions.auto,
              size: 200.0,
            ),
            const SizedBox(height: 16),
            Text(invitation.guestName, style: AppTypography.h3),
            Text(
              'Válido até: ${DateFormat('dd/MM/yyyy').format(invitation.validityDate)}',
              style: AppTypography.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}
