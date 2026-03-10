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
        { 'id': 'parcel_history', 'icon': 'history', 'label': 'Histórico Encomendas', 'route': '/parcel-history', 'visible': false, 'order': 8 }
      ],
      'admin_menu': [
        { 'id': 'approvals', 'icon': 'check_circle', 'label': 'Aprovações', 'route': '/manager-approval', 'visible': true, 'order': 1 },
        { 'id': 'resident_search', 'icon': 'how_to_reg', 'label': 'Busca Moradores', 'route': '/resident-search', 'visible': true, 'order': 2 },
        { 'id': 'parcel_history', 'icon': 'history', 'label': 'Histórico Entregas', 'route': '/parcel-history', 'visible': false, 'order': 3 }
      ],
      'porter_menu': [
        { 'id': 'visitor_approval', 'icon': 'how_to_reg', 'label': 'Liberar Visitante', 'route': '/portaria-visitor-approval', 'visible': true, 'order': 1 },
        { 'id': 'parcel_reg', 'icon': 'add_box', 'label': 'Registrar Encomenda', 'route': '/parcel-registration', 'visible': true, 'order': 2 },
        { 'id': 'pending_del', 'icon': 'local_shipping', 'label': 'Entregas Pendentes', 'route': '/pending-deliveries', 'visible': true, 'order': 3 },
        { 'id': 'guest_checkin', 'icon': 'qr_code', 'label': 'Check-in QR', 'route': '/guest-checkin', 'visible': false, 'order': 4 }
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
          { 'id': 'parcel_history', 'icon': 'history', 'label': 'Histórico Encomendas', 'route': '/parcel-history', 'visible': true, 'order': 8 }
        ],
        'admin_menu': [
          { 'id': 'approvals', 'icon': 'check_circle', 'label': 'Aprovações', 'route': '/manager-approval', 'visible': true, 'order': 1 },
          { 'id': 'parcel_history', 'icon': 'history', 'label': 'Histórico Entregas', 'route': '/parcel-history', 'visible': true, 'order': 2 },
          { 'id': 'resident_search', 'icon': 'how_to_reg', 'label': 'Busca Moradores', 'route': '/resident-search', 'visible': true, 'order': 3 }
        ],
        'porter_menu': [
          { 'id': 'visitor_approval', 'icon': 'how_to_reg', 'label': 'Liberar Visitante', 'route': '/portaria-visitor-approval', 'visible': true, 'order': 1 },
          { 'id': 'parcel_reg', 'icon': 'add_box', 'label': 'Registrar Encomenda', 'route': '/parcel-registration', 'visible': true, 'order': 2 },
          { 'id': 'pending_del', 'icon': 'local_shipping', 'label': 'Entregas Pendentes', 'route': '/pending-deliveries', 'visible': true, 'order': 3 },
          { 'id': 'guest_checkin', 'icon': 'qr_code', 'label': 'Check-in QR', 'route': '/guest-checkin', 'visible': true, 'order': 4 }
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
    // Normalize: strip parentheticals and lowercase
    // e.g. 'Morador(a)' → 'morador', 'Porteiro (a)' → 'porteiro', 'Síndico(a)' → 'síndico'
    final normalized = role
        .toLowerCase()
        .replaceAll(RegExp(r'\s*\(.*?\)'), '')
        .trim();

    // Map normalized role to menu config key
    String effectiveRole;
    if (['syndic', 'sindico', 'síndico', 'admin'].contains(normalized)) {
      effectiveRole = 'admin';
    } else if (['portaria', 'porteiro', 'porteira', 'zelador', 'zeladora',
                 'funcionario', 'funcionário', 'sub_sindico', 'sub_síndico'].contains(normalized)) {
      effectiveRole = 'porter';
    } else {
      // morador, resident, locatario, proprietario, etc. → resident menu
      effectiveRole = 'resident';
    }

    final key = '${effectiveRole}_menu';
    final menuList = featuresConfig[key];

    if (menuList == null || menuList is! List) return [];

    final items = menuList
        .map((item) => FeatureMenuItem.fromMap(Map<String, dynamic>.from(item as Map)))
        .where((item) => item.visible)
        .toList();

    // Sort by order ascending
    items.sort((a, b) => a.order.compareTo(b.order));
    return items;
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
