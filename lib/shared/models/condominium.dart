import 'package:equatable/equatable.dart';

class Condominium extends Equatable {
  final String id;
  final String name;
  final String slug;
  final DateTime createdAt;

  const Condominium({
    required this.id,
    required this.name,
    required this.slug,
    required this.createdAt,
  });

  factory Condominium.fromJson(Map<String, dynamic> json) {
    return Condominium(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, name, slug, createdAt];
}
