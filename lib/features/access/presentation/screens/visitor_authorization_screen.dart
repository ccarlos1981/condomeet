import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_state.dart';
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
  bool _showTypeError = false;
  String _listSearchQuery = '';
  String? _listTypeFilter;
  DateTime _selectedDate = DateTime.now();
  final _phoneMask = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  final List<String> _visitorTypes = [
    'Uber ou Taxi',
    'Delivery',
    'Farmácia',
    'Diarista',
    'Visitante',
    'Mat. Obra',
    'Serviços',
    'Hóspedes',
    'Outros',
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
    final isTypeValid = _visitorType != null;
    if (!isTypeValid) setState(() => _showTypeError = true);
    if (_formKey.currentState!.validate() && isTypeValid) {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    
    return BlocListener<InvitationBloc, InvitationState>(
      listener: (context, state) {
        if (state is InvitationCreated) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Autorização para ${state.invitation.guestName} registrada com sucesso! ✅',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          _clearForm();
          Navigator.pop(context);
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
          title: Column(
            children: [
              Text(
                'Autorizar visitante',
                style: AppTypography.h2.copyWith(color: Colors.black87),
              ),
              Text(
                authState.userName ?? 'Morador',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade500, fontWeight: FontWeight.normal),
              ),
            ],
          ),
          centerTitle: true,
        ),
        body: ExcludeSemantics(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildForm(authState),
                _buildInvitationsList(authState),
              ],
            ),
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
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            
            // Dropdown Tipo - using custom dialog to avoid DropdownButtonFormField
            // semantics assertion bug (parentDataDirty freeze)
            GestureDetector(
              onTap: () async {
                final selected = await showDialog<String>(
                  context: context,
                  builder: (ctx) => SimpleDialog(
                    title: const Text('Tipo de visitante'),
                    children: _visitorTypes.map((type) => SimpleDialogOption(
                      onPressed: () => Navigator.pop(ctx, type),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(type, style: const TextStyle(fontSize: 16)),
                      ),
                    )).toList(),
                  ),
                );
                if (selected != null) setState(() => _visitorType = selected);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _visitorType == null && _showTypeError
                        ? Colors.red
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _visitorType ?? 'Escolha o tipo de visitante',
                      style: AppTypography.bodyMedium.copyWith(
                        color: _visitorType == null ? Colors.grey.shade400 : Colors.black87,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  ],
                ),
              ),
            ),
            if (_visitorType == null && _showTypeError)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  'Campo obrigatório',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
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
              // Nome do visitante is optional
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
        // Search field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Buscar por nome ou código...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            onChanged: (v) => setState(() => _listSearchQuery = v.toLowerCase()),
          ),
        ),
        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              _buildListFilterChip('Todos', null),
              ..._visitorTypes.map((t) => _buildListFilterChip(t, t)),
            ],
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
              var filtered = state.invitations.where((inv) {
                final matchesSearch = _listSearchQuery.isEmpty ||
                    inv.guestName.toLowerCase().contains(_listSearchQuery) ||
                    inv.qrData.toLowerCase().contains(_listSearchQuery);
                final matchesType = _listTypeFilter == null ||
                    inv.visitorType == _listTypeFilter;
                return matchesSearch && matchesType;
              }).toList();

              if (filtered.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: Text('Nenhuma autorização encontrada'),
                  ),
                );
              }

              return Column(
                children: [
                  ...filtered.map((inv) => _buildInvitationCard(inv)),
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

  Widget _buildListFilterChip(String label, String? type) {
    final isSelected = _listTypeFilter == type;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: TextStyle(
          fontSize: 11,
          color: isSelected ? Colors.white : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        )),
        selected: isSelected,
        onSelected: (_) => setState(() => _listTypeFilter = type),
        backgroundColor: Colors.grey.shade100,
        selectedColor: AppColors.primary,
        checkmarkColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
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
            color: Colors.black.withValues(alpha: 0.02),
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
                const SizedBox(height: 2),
                Text(
                  '${inv.visitorType ?? 'Visita'} · ${DateFormat('dd/MM/yyyy').format(inv.validityDate)}',
                  style: AppTypography.bodySmall.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '🔑 ${inv.qrData.length > 3 ? inv.qrData.substring(inv.qrData.length - 3).toUpperCase() : inv.qrData.toUpperCase()}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code, color: Colors.grey),
            onPressed: () {
              final shortCode = inv.qrData.length > 3
                  ? inv.qrData.substring(inv.qrData.length - 3).toUpperCase()
                  : inv.qrData.toUpperCase();
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (ctx) => ExcludeSemantics(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40, height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text('Autorização de Acesso', style: AppTypography.h2),
                          const SizedBox(height: 4),
                          Text(inv.guestName, style: AppTypography.h3.copyWith(color: Colors.grey.shade600)),
                          Text('Código: $shortCode', style: TextStyle(
                            color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18,
                          )),
                          const SizedBox(height: 12),
                          RepaintBoundary(
                            child: QrImageView(
                              data: inv.qrData,
                              version: QrVersions.auto,
                              size: 180.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Data da visita: ${DateFormat('dd/MM/yyyy').format(inv.validityDate)}',
                            style: AppTypography.bodySmall.copyWith(color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Fechar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
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
      _showTypeError = false;
      _selectedDate = DateTime.now();
    });
  }

  // ignore: unused_element
  void _showQrCodeDialog(Invitation invitation) {
    showDialog(
      context: context,
      builder: (context) => ExcludeSemantics(
        child: AlertDialog(
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
                'Data da visita: ${DateFormat('dd/MM/yyyy').format(invitation.validityDate)}',
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
      ),
    );
  }
}
