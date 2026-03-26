import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';

// ─────────────────────────────────────────────
// Master catalog: ALL possible functions
// ─────────────────────────────────────────────

class _FunctionDef {
  final String id;
  final String icon;
  final String label;
  final String route;
  final Set<String> defaultRoles; // normalized role keys

  const _FunctionDef({
    required this.id,
    required this.icon,
    required this.label,
    required this.route,
    this.defaultRoles = const {},
  });
}

const _kAllFunctions = [
  _FunctionDef(id: 'authorize_visitor',  icon: 'how_to_reg',    label: 'Autorizar Visitante',     route: '/invitation-generator',      defaultRoles: {'morador'}),
  _FunctionDef(id: 'parcels',            icon: 'inventory_2',   label: 'Minhas Encomendas',       route: '/parcel-dashboard',           defaultRoles: {'morador'}),
  _FunctionDef(id: 'guest_checkin',      icon: 'qr_code',       label: 'Visitante c/ Autorização',route: '/guest-checkin',              defaultRoles: {'morador', 'portaria'}),
  _FunctionDef(id: 'occurrences',        icon: 'warning',       label: 'Ocorrências',             route: '/report-occurrence',          defaultRoles: {'morador', 'proprietario', 'inquilino', 'locatario', 'portaria', 'zelador', 'funcionario'}),
  _FunctionDef(id: 'occurrence_admin',   icon: 'book',          label: 'Livro de Ocorrências',    route: '/occurrence-admin',           defaultRoles: {'sindico', 'sub_sindico'}),
  _FunctionDef(id: 'bookings',           icon: 'calendar_month',label: 'Reservas',                route: '/area-booking',               defaultRoles: {'morador'}),
  _FunctionDef(id: 'documents',          icon: 'file_copy',     label: 'Documentos',              route: '/document-center',            defaultRoles: {'morador'}),
  _FunctionDef(id: 'parcel_history',     icon: 'history',       label: 'Histórico Encomendas',    route: '/parcel-history',             defaultRoles: {'morador'}),
  _FunctionDef(id: 'visitor_approval',   icon: 'how_to_reg',    label: 'Liberar Visitante Cadastrado',route: '/liberar-visitante-cadastrado',  defaultRoles: {'portaria'}),
  _FunctionDef(id: 'parcel_reg',         icon: 'add_box',       label: 'Registrar Encomenda',     route: '/parcel-registration',        defaultRoles: {'portaria'}),
  _FunctionDef(id: 'pending_del',        icon: 'local_shipping',label: 'Encomendas do Condomínio', route: '/pending-deliveries',         defaultRoles: {'portaria', 'sindico', 'sub_sindico'}),
  _FunctionDef(id: 'visitor_reg',        icon: 'person_add',    label: 'Registrar Visitante',     route: '/visitor-registration',       defaultRoles: {'portaria'}),
  _FunctionDef(id: 'approvals',          icon: 'check_circle',  label: 'Aprovações',              route: '/manager-approval',           defaultRoles: {'sindico'}),
  _FunctionDef(id: 'resident_search',    icon: 'person_search', label: 'Busca Moradores',         route: '/resident-search',            defaultRoles: {'sindico'}),
  _FunctionDef(id: 'condo_structure',    icon: 'apartment',     label: 'Estrutura do Condomínio', route: '/condo-structure',            defaultRoles: {'sindico'}),
  _FunctionDef(id: 'assemblies',         icon: 'groups',        label: 'Assembleias',             route: '/assemblies',                 defaultRoles: {'sindico'}),
  _FunctionDef(id: 'avisos',             icon: 'campaign',      label: 'Avisos',                  route: '/avisos',                     defaultRoles: {'morador', 'sindico'}),
  _FunctionDef(id: 'fale_sindico',       icon: 'forum',         label: 'Fale com o Síndico',      route: '/fale-sindico',               defaultRoles: {'morador'}),
  _FunctionDef(id: 'enquetes',           icon: 'bar_chart',     label: 'Enquetes',                route: '/enquetes',                   defaultRoles: {'morador'}),
  _FunctionDef(id: 'enquete_admin',      icon: 'bar_chart',     label: 'Enquetes',                route: '/enquete-admin',              defaultRoles: {'sindico'}),
  _FunctionDef(id: 'reservas_portaria',   icon: 'calendar_month',label: 'Reservas (Portaria)',      route: '/reservas-portaria',          defaultRoles: {'portaria', 'sindico', 'sub_sindico'}),
  _FunctionDef(id: 'visitor_register',    icon: 'badge',         label: 'Registrar Visitante',     route: '/registrar-visitante',        defaultRoles: {'portaria'}),
  _FunctionDef(id: 'portaria_authorize',  icon: 'how_to_reg',    label: 'Autorização Visitante (Portaria)', route: '/autorizar-visitante-portaria', defaultRoles: {'portaria'}),
  _FunctionDef(id: 'registro_turno',      icon: 'assignment',    label: 'Registro de Turno',       route: '/registro-turno',             defaultRoles: {'portaria'}),
  _FunctionDef(id: 'album_fotos',      icon: 'photo',         label: 'Álbum de Fotos',         route: '/album-fotos',                defaultRoles: {'morador'}),
  _FunctionDef(id: 'classificados',    icon: 'sell',          label: 'Classificados',           route: '/classificados',              defaultRoles: {'morador'}),
  _FunctionDef(id: 'indicacoes',       icon: 'favorite',      label: 'Indicações de Serviço', route: '/indicacoes',                 defaultRoles: {'morador'}),
  _FunctionDef(id: 'contracts',        icon: 'description',   label: 'Contratos',               route: '/contratos',                  defaultRoles: {'sindico', 'sub_sindico'}),
  _FunctionDef(id: 'visita_proprietario', icon: 'door_front', label: 'Visita Proprietário',     route: '/visita-proprietario',        defaultRoles: {'portaria'}),
  _FunctionDef(id: 'aluguel_vaga',       icon: 'local_parking', label: 'Garagem Inteligente',     route: '/garagem',                    defaultRoles: {'morador'}),
];

/// Normalize papal_sistema → internal key: "Porteiro (a)" → "portaria"
String _normalizeRole(String raw) {
  final key = raw
      .toLowerCase()
      .replaceAll(RegExp(r'\s*\(.*?\)'), '') // remove (a)/(o)
      .replaceAll(RegExp(r'[^a-záàéíóúãõâêôç]'), '_')
      .trim();
  // Well-known aliases
  const aliases = <String, String>{
    'porteiro': 'portaria',
    'sindico': 'sindico',
    'síndico': 'sindico',
    'sub_sindico': 'sub_sindico',
    'sub_síndico': 'sub_sindico',
    'admin': 'admin',
    'zelador': 'zelador',
    'funcionario': 'funcionario',
    'funcionário': 'funcionario',
    'morador': 'morador',
    'proprietario': 'proprietario',
    'proprietário': 'proprietario',
    'proprietário_não_morador': 'proprietario_nao_morador',
    'proprietario_não_morador': 'proprietario_nao_morador',
    'proprietario_nao_morador': 'proprietario_nao_morador',
    'inquilino': 'inquilino',
    'locatario': 'locatario',
    'locatário': 'locatario',
    'locador': 'locador',
    'afiliado': 'afiliado',
    'terceirizado': 'terceirizado',
    'financeiro': 'financeiro',
    'servicos': 'servicos',
    'serviços': 'servicos',
  };
  return aliases[key] ?? key;
}

// ─────────────────────────────────────────────
// Working model
// ─────────────────────────────────────────────

class _RoleDef {
  final String key;   // normalized, e.g. 'portaria'
  final String label; // raw display, e.g. 'Porteiro (a)'
  _RoleDef(this.key, this.label);
}

class _FuncConfig {
  final String id;
  final String label;
  final String icon;
  final int order; // global display order (condominium-wide)
  // key = normalized role, value = {'visible': bool}
  final Map<String, Map<String, dynamic>> roles;

  _FuncConfig({required this.id, required this.label, required this.icon, this.order = 99, required this.roles});

  _FuncConfig copyWith({Map<String, Map<String, dynamic>>? roles, int? order}) =>
      _FuncConfig(id: id, label: label, icon: icon, order: order ?? this.order, roles: roles ?? this.roles);

  bool visibleFor(String roleKey) => roles[roleKey]?['visible'] as bool? ?? false;
}

// ─────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────

class ConfigureMenuScreen extends StatefulWidget {
  const ConfigureMenuScreen({super.key});

  @override
  State<ConfigureMenuScreen> createState() => _ConfigureMenuScreenState();
}

class _ConfigureMenuScreenState extends State<ConfigureMenuScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  List<_FuncConfig> _functions = [];
  // Complete list of all possible profiles — always shown
  List<_RoleDef> _roles = [
    _RoleDef('morador',                'Morador (a)'),
    _RoleDef('proprietario',           'Proprietário (a)'),
    _RoleDef('proprietario_nao_morador','Proprietário não morador'),
    _RoleDef('inquilino',              'Inquilino (a)'),
    _RoleDef('locatario',              'Locatário (a)'),
    _RoleDef('funcionario',            'Funcionário (a)'),
    _RoleDef('portaria',               'Porteiro (a)'),
    _RoleDef('zelador',                'Zelador (a)'),
    _RoleDef('sindico',                'Síndico (a)'),
    _RoleDef('sub_sindico',            'Sub Síndico (a)'),
  ];
  int _selectedFnIndex = 0;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  // ── Lifecycle ────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadConfig();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // ── Load ─────────────────────────────────────────────────────────

  Future<void> _loadConfig() async {
    final condoId = context.read<AuthBloc>().state.condominiumId;
    if (condoId == null) return;

    setState(() { _isLoading = true; _error = null; });

    try {
      // 1. Load existing config
      final res = await Supabase.instance.client
          .from('condominios')
          .select('features_config')
          .eq('id', condoId)
          .maybeSingle();

      Map<String, dynamic> existing = {};
      if (res != null && res['features_config'] != null) {
        final raw = res['features_config'];
        final decoded = raw is String ? jsonDecode(raw) : raw as Map<String, dynamic>;
        existing = Map<String, dynamic>.from(decoded);
      }

      // 2. Load distinct roles from perfil — add any extra found in DB
      final baseRoleKeys = _roles.map((r) => r.key).toSet();
      try {
        final perfilData = await Supabase.instance.client
            .from('perfil')
            .select('papel_sistema')
            .eq('condominio_id', condoId)
            .not('papel_sistema', 'is', null);
        for (final row in (perfilData as List)) {
          final raw = row['papel_sistema'] as String? ?? '';
          if (raw.isEmpty) continue;
          final key = _normalizeRole(raw);
          if (!baseRoleKeys.contains(key)) {
            baseRoleKeys.add(key);
            _roles.add(_RoleDef(key, raw));
          }
        }
      } catch (_) {
        // Keep base roles on error
      }


      // 3. Build function list merging saved config
      final saved = existing['functions'] as List? ?? [];
      final savedMap = { for (final f in saved) (f as Map)['id'] as String: f };

      final newRoles = _roles;

      final newFunctions = _kAllFunctions.map((def) {
        final savedFn = savedMap[def.id];
        // Global order stored at function level
        final globalOrder = savedFn != null ? (savedFn['order'] as int? ?? 99) : 99;
        final roles = <String, Map<String, dynamic>>{};

        for (final roleDef in newRoles) {
          final rk = roleDef.key;
          if (savedFn != null) {
            final savedRole = (savedFn['roles'] as Map?)?[rk];
            roles[rk] = savedRole != null
                ? {'visible': savedRole['visible'] as bool? ?? false}
                : {'visible': false};
          } else {
            roles[rk] = _resolveFromLegacy(existing, def.id, rk, def.defaultRoles);
          }
        }

        return _FuncConfig(id: def.id, label: def.label, icon: def.icon, order: globalOrder, roles: roles);
      }).toList();

      if (mounted) setState(() {
        _roles = newRoles;
        _functions = newFunctions;
        _isLoading = false;
      });
    } catch (e) {
      // Even on error, build functions from defaults so UI still works
      if (mounted) setState(() {
        _functions = _kAllFunctions.map((def) {
          final roles = { for (final r in _roles) r.key: _resolveFromLegacy({}, def.id, r.key, def.defaultRoles) };
          return _FuncConfig(id: def.id, label: def.label, icon: def.icon, roles: roles);
        }).toList();
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _resolveFromLegacy(
      Map<String, dynamic> cfg, String fnId, String roleKey, Set<String> defaultRoles) {
    // Only the original 3 role keys should map to legacy menus.
    // New profiles (proprietario, inquilino, locatario, funcionario, zelador, sub_sindico)
    // default to false — admin must explicitly enable them.
    String? menuKey;
    if (roleKey == 'portaria') {
      menuKey = 'porter';
    } else if (roleKey == 'sindico') {
      menuKey = 'admin';
    } else if (roleKey == 'morador') {
      menuKey = 'resident';
    } else {
      // New profile types — no legacy mapping, use defaultRoles fallback only
      final visible = defaultRoles.contains(roleKey);
      return {'visible': visible};
    }
    final legacyList = cfg['${menuKey}_menu'] as List?;
    if (legacyList != null) {
      for (final item in legacyList) {
        if ((item as Map)['id'] == fnId) {
          return {
            'visible': item['visible'] as bool? ?? true,
          };
        }
      }
    }
    final visible = defaultRoles.contains(roleKey);
    return {'visible': visible};
  }

  // ── Save ─────────────────────────────────────────────────────────

  Future<void> _save() async {
    final condoId = context.read<AuthBloc>().state.condominiumId;
    if (condoId == null) return;
    setState(() => _isSaving = true);
    try {
      final functionsJson = _functions.map((fn) {
        final d = _kAllFunctions.firstWhere((d) => d.id == fn.id);
        return {
          'id': fn.id,
          'icon': d.icon,
          'label': fn.label,
          'route': d.route,
          'order': fn.order, // global order
          'roles': fn.roles,
        };
      }).toList();

      // Legacy menus — include all resident-type profiles for backwards compatibility
      final newConfig = {
        'functions': functionsJson,
        'resident_menu': _buildLegacyMenu(['morador', 'proprietario', 'proprietario_nao_morador', 'inquilino', 'locatario']),
        'porter_menu': _buildLegacyMenu(['portaria', 'funcionario', 'zelador']),
        'admin_menu': _buildLegacyMenu(['sindico', 'sub_sindico']),
      };

      await Supabase.instance.client
          .from('condominios')
          .update({'features_config': newConfig})
          .eq('id', condoId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Configurações salvas!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
        // Sort by global order ascending after save — keep current function selected
        final currentFnId = _functions[_selectedFnIndex].id;
        setState(() {
          _functions.sort((a, b) => a.order.compareTo(b.order));
          // Keep showing the same function after sort
          _selectedFnIndex = _functions.indexWhere((f) => f.id == currentFnId).clamp(0, _functions.length - 1);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  List<Map<String, dynamic>> _buildLegacyMenu(List<String> roleKeys) {
    return _functions.where((fn) {
      return roleKeys.any((rk) => fn.visibleFor(rk));
    }).map((fn) {
      final d = _kAllFunctions.firstWhere((d) => d.id == fn.id);
      return {
        'id': fn.id,
        'icon': d.icon,
        'label': fn.label,
        'route': d.route,
        'visible': true,
        'order': fn.order, // global order
      };
    }).toList()..sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));
  }

  // ── Toggle role visibility ────────────────────────────────────────

  void _toggleRole(int fnIndex, String roleKey, bool val) {
    setState(() {
      final newRoles = Map<String, Map<String, dynamic>>.from(_functions[fnIndex].roles);
      newRoles[roleKey] = {...?newRoles[roleKey], 'visible': val};
      _functions[fnIndex] = _functions[fnIndex].copyWith(roles: newRoles);
    });
  }


  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Configurar Menu'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
              : TextButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Salvar'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.lock_outline, size: 18), text: 'Acesso'),
            Tab(icon: Icon(Icons.sort, size: 18), text: 'Ordem'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : TabBarView(
                  controller: _tabs,
                  children: [_buildAccessTab(), _buildOrderTab()],
                ),
    );
  }

  // ── Function selector widget (dropdown + arrows) ─────────────────

  Widget _buildFunctionSelector() {
    final _ = _functions[_selectedFnIndex];
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(children: [
          // ← prev
          IconButton(
            onPressed: _selectedFnIndex > 0
                ? () => setState(() => _selectedFnIndex--)
                : null,
            icon: const Icon(Icons.chevron_left),
            color: AppColors.primary,
            disabledColor: AppColors.border,
          ),
          // Dropdown
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedFnIndex,
                isExpanded: true,
                icon: const Icon(Icons.expand_more, size: 18, color: AppColors.primary),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMain),
                onChanged: (val) => setState(() => _selectedFnIndex = val ?? 0),
                items: List.generate(_functions.length, (i) {
                  final f = _functions[i];
                  final icon = _iconFromString(f.icon);
                  final anyVisible = _roles.any((r) => f.visibleFor(r.key));
                  return DropdownMenuItem<int>(
                    value: i,
                    child: Row(children: [
                      Icon(icon, size: 18, color: anyVisible ? AppColors.primary : AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Flexible(child: Text(f.label, overflow: TextOverflow.ellipsis)),
                      if (anyVisible) ...[
                        const SizedBox(width: 4),
                        Container(
                          width: 6, height: 6,
                          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                        ),
                      ],
                    ]),
                  );
                }),
              ),
            ),
          ),
          // → next
          IconButton(
            onPressed: _selectedFnIndex < _functions.length - 1
                ? () => setState(() => _selectedFnIndex++)
                : null,
            icon: const Icon(Icons.chevron_right),
            color: AppColors.primary,
            disabledColor: AppColors.border,
          ),
        ]),
      ),
    );
  }

  // ── Aba: Acesso ──────────────────────────────────────────────────

  Widget _buildAccessTab() {
    if (_functions.isEmpty) return const SizedBox.shrink();
    final fn = _functions[_selectedFnIndex];
    return Column(children: [
      // Function selector
      _buildFunctionSelector(),

      // Role grid
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Perfis com acesso a "${fn.label}":',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _roles.map((role) {
                final isVisible = fn.visibleFor(role.key);
                return _RoleCard(
                  label: role.label,
                  checked: isVisible,
                  onChanged: (val) => _toggleRole(_selectedFnIndex, role.key, val),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Marque os perfis que poderão ver esta função no menu do app.\n'
              'Desmarcar remove a função do perfil automaticamente.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ]),
        ),
      ),
    ]);
  }

  // ── Aba: Ordem ───────────────────────────────────────────────────
  // One global order per function (condominium-wide), 2-column grid

  Widget _buildOrderTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Defina a posição de cada botão no app (menor número = aparece primeiro).',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        // 2-column grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.6,
          ),
          itemCount: _functions.length,
          itemBuilder: (context, i) {
            final fn = _functions[i];
            return _GlobalOrderCard(
              key: ValueKey(fn.id),
              label: fn.label,
              icon: _iconFromString(fn.icon),
              order: fn.order,
              onChanged: (newOrder) {
                setState(() {
                  _functions[i] = _functions[i].copyWith(order: newOrder);
                });
              },
            );
          },
        ),
        const SizedBox(height: 16),
        Text('A ordem é única por condomínio — vale para todos os perfis que têm acesso a cada função.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            textAlign: TextAlign.center),
      ]),
    );
  }

  IconData _iconFromString(String name) {
    const map = {
      'how_to_reg': Icons.how_to_reg,
      'inventory_2': Icons.inventory_2,
      'qr_code': Icons.qr_code,
      'warning': Icons.warning,
      'calendar_month': Icons.calendar_month,
      'file_copy': Icons.file_copy,
      'history': Icons.history,
      'add_box': Icons.add_box,
      'local_shipping': Icons.local_shipping,
      'check_circle': Icons.check_circle,
      'person_search': Icons.person_search,
      'apartment': Icons.apartment,
      'groups': Icons.groups,
      'chat': Icons.chat,
      'forum': Icons.forum_outlined,
      'campaign': Icons.campaign_outlined,
      'person_add': Icons.person_add,
      'bar_chart': Icons.bar_chart,
      'send': Icons.send,
      'book': Icons.book,
      'photo': Icons.photo,
      'sell': Icons.sell,
      'favorite': Icons.favorite_border,
      'door_front': Icons.door_front_door,
      'badge': Icons.badge,
      'assignment': Icons.assignment,
      'description': Icons.description,
      'local_parking': Icons.local_parking,
    };
    return map[name] ?? Icons.widgets;
  }
}

// ─────────────────────────────────────────────
// Role card with checkbox
// ─────────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  final String label;
  final bool checked;
  final ValueChanged<bool> onChanged;

  const _RoleCard({required this.label, required this.checked, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!checked),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: (MediaQuery.of(context).size.width - 52) / 2,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: checked ? AppColors.primaryLight : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: checked ? AppColors.primary : AppColors.border,
            width: checked ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Checkbox(
            value: checked,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: AppColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: checked ? FontWeight.bold : FontWeight.normal,
              color: checked ? AppColors.primary : AppColors.textMain,
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Global order card (2-column grid)
// ─────────────────────────────────────────────

class _GlobalOrderCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final int order;
  final ValueChanged<int> onChanged;
  const _GlobalOrderCard({super.key, required this.label, required this.icon, required this.order, required this.onChanged});

  @override
  State<_GlobalOrderCard> createState() => _GlobalOrderCardState();
}

class _GlobalOrderCardState extends State<_GlobalOrderCard> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.order == 99 ? '' : '${widget.order}');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_GlobalOrderCard old) {
    super.didUpdateWidget(old);
    if (old.order != widget.order && !_ctrl.text.isNotEmpty) {
      _ctrl.text = widget.order == 99 ? '' : '${widget.order}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Label + icon
          Row(children: [
            Icon(widget.icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                widget.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ]),
          // Number input centered
          Center(
            child: SizedBox(
              width: 60,
              child: TextField(
                controller: _ctrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMain,
                ),
                decoration: InputDecoration(
                  hintText: '—',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  isDense: true,
                ),
                onChanged: (v) => widget.onChanged(int.tryParse(v) ?? 99),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
