import 'dart:convert';
import 'package:equatable/equatable.dart';

class Condominium extends Equatable {
  final String id;
  final String name;
  final String slug;
  final String tipoEstrutura;
  final Map<String, dynamic> featuresConfig;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const Condominium({
    required this.id,
    required this.name,
    required this.slug,
    this.tipoEstrutura = 'predio',
    this.featuresConfig = const {
      'resident_menu': [
        { 'id': 'authorize_visitor', 'icon': 'how_to_reg', 'label': 'Autorizar Visitante', 'route': '/invitation-generator', 'visible': true, 'order': 1 },
        { 'id': 'parcels', 'icon': 'inventory_2', 'label': 'Minhas Encomendas', 'route': '/parcel-dashboard', 'visible': true, 'order': 2 },
        { 'id': 'guest_checkin', 'icon': 'qr_code', 'label': 'Visitante c/ autorização', 'route': '/guest-checkin', 'visible': true, 'order': 3 },
        { 'id': 'occurrences', 'icon': 'warning', 'label': 'Ocorrências', 'route': '/report-occurrence', 'visible': false, 'order': 4 },
        { 'id': 'chat', 'icon': 'chat', 'label': 'Chat Oficial', 'route': '/official-chat', 'visible': false, 'order': 5 },
        { 'id': 'bookings', 'icon': 'calendar_month', 'label': 'Reservas', 'route': '/area-booking', 'visible': false, 'order': 6 },
        { 'id': 'documents', 'icon': 'file_copy', 'label': 'Documentos', 'route': '/document-center', 'visible': false, 'order': 7 },
        { 'id': 'parcel_history', 'icon': 'history', 'label': 'Histórico Encomendas', 'route': '/parcel-history', 'visible': false, 'order': 8 },
        { 'id': 'fale_sindico', 'icon': 'forum', 'label': 'Fale com o Síndico', 'route': '/official-chat', 'visible': true, 'order': 9 }
      ],
      'admin_menu': [
        { 'id': 'approvals', 'icon': 'check_circle', 'label': 'Aprovações', 'route': '/manager-approval', 'visible': true, 'order': 1 },
        { 'id': 'resident_search', 'icon': 'how_to_reg', 'label': 'Busca Moradores', 'route': '/resident-search', 'visible': true, 'order': 2 },
        { 'id': 'parcel_history', 'icon': 'history', 'label': 'Histórico Entregas', 'route': '/parcel-history', 'visible': true, 'order': 3 },
        { 'id': 'fale_conosco', 'icon': 'forum', 'label': 'Fale Conosco', 'route': '/fale-conosco', 'visible': true, 'order': 4 },
        { 'id': 'occurrences', 'icon': 'warning', 'label': 'Ocorrências', 'route': '/report-occurrence', 'visible': true, 'order': 5 },
        { 'id': 'bookings', 'icon': 'calendar_month', 'label': 'Reservas', 'route': '/area-booking', 'visible': true, 'order': 6 },
        { 'id': 'documents', 'icon': 'file_copy', 'label': 'Documentos', 'route': '/document-center', 'visible': true, 'order': 7 },
        { 'id': 'avisos', 'icon': 'campaign', 'label': 'Avisos', 'route': '/avisos', 'visible': true, 'order': 8 }
      ],
      'porter_menu': [
        { 'id': 'visitor_approval', 'icon': 'how_to_reg', 'label': 'Liberar Visitante', 'route': '/portaria-visitor-approval', 'visible': true, 'order': 1 },
        { 'id': 'parcel_reg', 'icon': 'add_box', 'label': 'Registrar Encomenda', 'route': '/parcel-registration', 'visible': true, 'order': 2 },
        { 'id': 'pending_del', 'icon': 'local_shipping', 'label': 'Entregas Pendentes', 'route': '/pending-deliveries', 'visible': true, 'order': 3 },
        { 'id': 'guest_checkin', 'icon': 'qr_code', 'label': 'Check-in QR', 'route': '/guest-checkin', 'visible': true, 'order': 4 },
        { 'id': 'visitor_reg', 'icon': 'person_add', 'label': 'Registrar Visitante', 'route': '/visitor-registration', 'visible': true, 'order': 5 }
      ]
    },
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory Condominium.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> parsedConfig = {};
    if (json['features_config'] != null) {
      try {
        if (json['features_config'] is String) {
          final decoded = jsonDecode(json['features_config']);
          if (decoded is Map) {
            parsedConfig = Map<String, dynamic>.from(decoded);
          }
        } else if (json['features_config'] is Map) {
          parsedConfig = Map<String, dynamic>.from(json['features_config']);
        }
      } catch (e) {
        print('Error parsing features_config: $e');
      }
    }

    return Condominium(
      id: json['id'] as String,
      name: (json['nome'] ?? json['name']) as String,
      slug: (json['apelido'] ?? json['slug']) ?? '',
      tipoEstrutura: json['tipo_estrutura'] as String? ?? 'predio',
      // Only override defaults if DB actually has config
      featuresConfig: parsedConfig.isNotEmpty ? parsedConfig : const {
        'resident_menu': [
          { 'id': 'authorize_visitor', 'icon': 'how_to_reg', 'label': 'Autorizar Visitante', 'route': '/invitation-generator', 'visible': true, 'order': 1 },
          { 'id': 'documents', 'icon': 'file_copy', 'label': 'Documentos', 'route': '/document-center', 'visible': true, 'order': 2 },
          { 'id': 'bookings', 'icon': 'calendar_month', 'label': 'Reservas', 'route': '/area-booking', 'visible': true, 'order': 3 },
          { 'id': 'occurrences', 'icon': 'warning', 'label': 'Ocorrências', 'route': '/report-occurrence', 'visible': true, 'order': 4 },
          { 'id': 'parcels', 'icon': 'inventory_2', 'label': 'Minhas Encomendas', 'route': '/parcel-dashboard', 'visible': true, 'order': 5 },
          { 'id': 'chat', 'icon': 'chat', 'label': 'Chat Oficial', 'route': '/official-chat', 'visible': true, 'order': 6 },
          { 'id': 'guest_checkin', 'icon': 'qr_code', 'label': 'Visitante com autorização', 'route': '/guest-checkin', 'visible': true, 'order': 7 },
          { 'id': 'parcel_history', 'icon': 'history', 'label': 'Histórico Encomendas', 'route': '/parcel-history', 'visible': true, 'order': 8 },
          { 'id': 'fale_sindico', 'icon': 'forum', 'label': 'Fale com o Síndico', 'route': '/official-chat', 'visible': true, 'order': 9 },
          { 'id': 'enquetes', 'icon': 'bar_chart', 'label': 'Enquetes', 'route': '/enquetes', 'visible': true, 'order': 10 }
        ],
        'admin_menu': [
          { 'id': 'approvals', 'icon': 'check_circle', 'label': 'Aprovações', 'route': '/manager-approval', 'visible': true, 'order': 1 },
          { 'id': 'resident_search', 'icon': 'how_to_reg', 'label': 'Busca Moradores', 'route': '/resident-search', 'visible': true, 'order': 2 },
          { 'id': 'parcel_history', 'icon': 'history', 'label': 'Histórico Entregas', 'route': '/parcel-history', 'visible': true, 'order': 3 },
          { 'id': 'fale_conosco', 'icon': 'forum', 'label': 'Fale Conosco', 'route': '/fale-conosco', 'visible': true, 'order': 4 },
          { 'id': 'occurrences', 'icon': 'warning', 'label': 'Ocorrências', 'route': '/report-occurrence', 'visible': true, 'order': 5 },
          { 'id': 'bookings', 'icon': 'calendar_month', 'label': 'Reservas', 'route': '/area-booking', 'visible': true, 'order': 6 },
          { 'id': 'documents', 'icon': 'file_copy', 'label': 'Documentos', 'route': '/document-center', 'visible': true, 'order': 7 },
          { 'id': 'avisos', 'icon': 'campaign', 'label': 'Avisos', 'route': '/avisos', 'visible': true, 'order': 8 },
          { 'id': 'enquete_admin', 'icon': 'bar_chart', 'label': 'Enquetes', 'route': '/enquete-admin', 'visible': true, 'order': 9 }
        ],
        'porter_menu': [
          { 'id': 'visitor_approval', 'icon': 'how_to_reg', 'label': 'Liberar Visitante', 'route': '/portaria-visitor-approval', 'visible': true, 'order': 1 },
          { 'id': 'parcel_reg', 'icon': 'add_box', 'label': 'Registrar Encomenda', 'route': '/parcel-registration', 'visible': true, 'order': 2 },
          { 'id': 'pending_del', 'icon': 'local_shipping', 'label': 'Entregas Pendentes', 'route': '/pending-deliveries', 'visible': true, 'order': 3 },
          { 'id': 'guest_checkin', 'icon': 'qr_code', 'label': 'Check-in QR', 'route': '/guest-checkin', 'visible': true, 'order': 4 },
          { 'id': 'visitor_reg', 'icon': 'person_add', 'label': 'Registrar Visitante', 'route': '/visitor-registration', 'visible': true, 'order': 5 }
        ]
      },
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : DateTime.now(),
      deletedAt: json['deleted_at'] != null ? DateTime.parse(json['deleted_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'tipo_estrutura': tipoEstrutura,
      'features_config': jsonEncode(featuresConfig),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  /// Helper to get the menu for a specific role
  List<FeatureMenuItem> getMenuForRole(String role) {
    final normalized = _normalizeRoleKey(role);

    // ── Try NEW format: features_config.functions[] with per-role visibility
    final functionsList = featuresConfig['functions'];
    if (functionsList != null && functionsList is List && functionsList.isNotEmpty) {
      final items = <FeatureMenuItem>[];
      for (final fn in functionsList) {
        final fnMap = fn as Map<String, dynamic>;
        final roles = fnMap['roles'] as Map?;
        if (roles == null) continue;
        final roleConfig = roles[normalized] as Map?;
        final isVisible = roleConfig?['visible'] as bool? ?? false;
        if (isVisible) {
          items.add(FeatureMenuItem.fromMap(Map<String, dynamic>.from(fnMap)));
        }
      }
      items.sort((a, b) => a.order.compareTo(b.order));
      return items;
    }

    // ── Fallback: LEGACY format (resident_menu / porter_menu / admin_menu)
    String effectiveRole;
    if (['syndic', 'sindico', 'admin'].contains(normalized)) {
      effectiveRole = 'admin';
    } else if (['portaria', 'zelador', 'funcionario', 'sub_sindico'].contains(normalized)) {
      effectiveRole = 'porter';
    } else {
      effectiveRole = 'resident';
    }

    final key = '${effectiveRole}_menu';
    final menuList = featuresConfig[key];
    if (menuList == null || menuList is! List) return [];

    final items = menuList
        .map((item) => FeatureMenuItem.fromMap(Map<String, dynamic>.from(item as Map)))
        .where((item) => item.visible)
        .toList();
    items.sort((a, b) => a.order.compareTo(b.order));
    return items;
  }

  /// Normalize role string to canonical key matching configure_menu_screen
  static String _normalizeRoleKey(String raw) {
    final key = raw
        .toLowerCase()
        .replaceAll(RegExp(r'\s*\(.*?\)'), '')
        .replaceAll(RegExp(r'[^a-z\u00e1\u00e0\u00e9\u00ed\u00f3\u00fa\u00e3\u00f5\u00e2\u00ea\u00f4\u00e7]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_\$'), '')
        .trim();
    const aliases = <String, String>{
      'porteiro': 'portaria',
      'síndico': 'sindico',
      'sub_síndico': 'sub_sindico',
      'funcionário': 'funcionario',
      'proprietário': 'proprietario',
      'proprietário_não_morador': 'proprietario_nao_morador',
      'proprietario_não_morador': 'proprietario_nao_morador',
      'locatário': 'locatario',
      'serviços': 'servicos',
      'sindico': 'sindico',
      'admin': 'admin',
      'zelador': 'zelador',
      'funcionario': 'funcionario',
      'morador': 'morador',
      'proprietario': 'proprietario',
      'proprietario_nao_morador': 'proprietario_nao_morador',
      'inquilino': 'inquilino',
      'locatario': 'locatario',
      'locador': 'locador',
      'afiliado': 'afiliado',
      'terceirizado': 'terceirizado',
      'financeiro': 'financeiro',
      'servicos': 'servicos',
    };
    return aliases[key] ?? key;
  }

  @override
  List<Object?> get props => [id, name, slug, tipoEstrutura, featuresConfig, createdAt, updatedAt, deletedAt];
}

class FeatureMenuItem extends Equatable {
  final String id;
  final String icon;
  final String label;
  final String route;
  final bool visible;
  final int order;

  const FeatureMenuItem({
    required this.id,
    required this.icon,
    required this.label,
    required this.route,
    this.visible = true,
    this.order = 99,
  });

  factory FeatureMenuItem.fromMap(Map<String, dynamic> map) {
    return FeatureMenuItem(
      id: map['id'] ?? '',
      icon: map['icon'] ?? 'widgets',
      label: map['label'] ?? '',
      route: map['route'] ?? '',
      visible: map['visible'] ?? true,
      order: map['order'] ?? 99,
    );
  }

  @override
  List<Object?> get props => [id, icon, label, route, visible, order];
}
