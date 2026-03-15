import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/features/community/domain/models/document.dart';
import 'package:condomeet/features/community/domain/repositories/document_repository.dart';

class DocumentRepositoryImpl implements DocumentRepository {
  final SupabaseClient _supabase;

  DocumentRepositoryImpl(this._supabase);

  @override
  Stream<List<CondoDocument>> watchDocuments(String condominioId) {
    // Poll every 15s — documents change infrequently.
    return Stream.fromIterable([0])
        .asyncExpand((_) async* {
          yield await _fetchDocuments(condominioId);
          await for (final _ in Stream.periodic(const Duration(seconds: 15))) {
            yield await _fetchDocuments(condominioId);
          }
        })
        .handleError((e) {
          print('❌ watchDocuments error: $e');
          return <CondoDocument>[];
        });
  }

  Future<List<CondoDocument>> _fetchDocuments(String condominioId) async {
    try {
      final rows = await _supabase
          .from('documentos')
          .select('id, condominio_id, titulo, pasta_id, arquivo_url, arquivo_nome, categoria, data_validade, data_expedicao, mostrar_moradores, descricao')
          .eq('condominio_id', condominioId)
          .eq('mostrar_moradores', true)
          .order('titulo');
      return (rows as List).map((r) => CondoDocument.fromMap(r as Map<String, dynamic>)).toList();
    } catch (e) {
      print('❌ _fetchDocuments error: $e');
      return [];
    }
  }
}
