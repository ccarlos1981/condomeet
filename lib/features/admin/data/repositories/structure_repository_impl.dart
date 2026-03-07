import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/shared/models/bloco.dart';
import 'package:condomeet/shared/models/apartamento.dart';
import 'package:condomeet/shared/models/unidade.dart';
import 'package:condomeet/features/admin/domain/repositories/structure_repository.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:rxdart/rxdart.dart';

class StructureRepositoryImpl implements StructureRepository {
  final PowerSyncDatabase _db;
  final SupabaseClient _supabase;
  final _uuid = const Uuid();

  // Subjects para forçar atualização da UI
  final _blocosSubject = BehaviorSubject<List<Bloco>>();
  final _aptosSubject = BehaviorSubject<List<Apartamento>>();
  final _unidadesSubject = BehaviorSubject<List<Unidade>>();

  StructureRepositoryImpl(this._db, this._supabase);

  // Helper para gerar ID determinístico baseado no nome e condomínio
  String _generateId(String prefix, String condoId, String name) {
    final value = '$prefix|$condoId|$name';
    final bytes = utf8.encode(value);
    final hash = sha1.convert(bytes).toString();
    return _uuid.v5(Uuid.NAMESPACE_URL, hash);
  }

  // ── BLOCOS ──

  @override
  Stream<List<Bloco>> watchBlocos(String condominiumId) {
    print('🔍 [StructureRepo] watchBlocos logic starting...');
    
    Future<void> refreshRemote() async {
      try {
        final remote = await _supabase
            .from('blocos')
            .select()
            .eq('condominio_id', condominiumId)
            .order('nome_ou_numero');
        
        final list = (remote as List).map((row) => Bloco.fromJson(row)).toList();
        _blocosSubject.add(list);
      } catch (e) {
        print('❌ [StructureRepo] Remote blocos refresh error: $e');
      }
    }

    refreshRemote();

    return Rx.combineLatest2<List<Bloco>, List<Bloco>, List<Bloco>>(
      _db.watch('SELECT * FROM blocos WHERE condominio_id = ? ORDER BY nome_ou_numero ASC', parameters: [condominiumId])
          .map((rows) => rows.map((row) => Bloco.fromJson(row)).toList()),
      _blocosSubject.stream,
      (local, remote) {
        final Map<String, Bloco> merged = {};
        for (var b in local) { merged[b.id] = b; }
        for (var b in remote) { merged[b.id] = b; }
        return merged.values.toList()..sort((a, b) => a.nomeOuNumero.compareTo(b.nomeOuNumero));
      }
    ).asBroadcastStream();
  }

  @override
  Future<void> addBloco(String condominiumId, String nomeOuNumero) async {
    final id = _generateId('bloco', condominiumId, nomeOuNumero);
    print('➕ [StructureRepo] Proactive Add Bloco: $nomeOuNumero');
    
    await _supabase.from('blocos').insert({
      'id': id,
      'condominio_id': condominiumId,
      'nome_ou_numero': nomeOuNumero,
      'created_at': DateTime.now().toIso8601String(),
    });

    final remote = await _supabase
        .from('blocos')
        .select()
        .eq('condominio_id', condominiumId)
        .order('nome_ou_numero');
    
    final list = (remote as List).map((row) => Bloco.fromJson(row)).toList();
    _blocosSubject.add(list);
  }

  @override
  Future<void> deleteBloco(String blocoId) async {
    print('🗑️ [StructureRepo] Deleting Bloco: $blocoId');
    await _supabase.from('unidades').delete().eq('bloco_id', blocoId);
    await _supabase.from('blocos').delete().eq('id', blocoId);
  }

  // ── APARTAMENTOS ──

  @override
  Stream<List<Apartamento>> watchApartamentos(String condominiumId) {
    Future<void> refreshRemote() async {
      try {
        final remote = await _supabase
            .from('apartamentos')
            .select()
            .eq('condominio_id', condominiumId)
            .order('numero');
        
        final list = (remote as List).map((row) => Apartamento.fromJson(row)).toList();
        _aptosSubject.add(list);
      } catch (e) {
        print('❌ [StructureRepo] Remote aptos refresh error: $e');
      }
    }

    refreshRemote();

    return Rx.combineLatest2<List<Apartamento>, List<Apartamento>, List<Apartamento>>(
      _db.watch('SELECT * FROM apartamentos WHERE condominio_id = ? ORDER BY numero ASC', parameters: [condominiumId])
          .map((rows) => rows.map((row) => Apartamento.fromJson(row)).toList()),
      _aptosSubject.stream,
      (local, remote) {
        final Map<String, Apartamento> merged = {};
        for (var a in local) { merged[a.id] = a; }
        for (var a in remote) { merged[a.id] = a; }
        return merged.values.toList()..sort((a, b) => a.numero.compareTo(b.numero));
      }
    ).asBroadcastStream();
  }

  @override
  Future<void> addApartamento(String condominiumId, String numero) async {
    final id = _generateId('apto', condominiumId, numero);
    print('➕ [StructureRepo] Proactive Add Apto: $numero');
    
    await _supabase.from('apartamentos').insert({
      'id': id,
      'condominio_id': condominiumId,
      'numero': numero,
      'created_at': DateTime.now().toIso8601String(),
    });

    final remote = await _supabase
        .from('apartamentos')
        .select()
        .eq('condominio_id', condominiumId)
        .order('numero');
    
    final list = (remote as List).map((row) => Apartamento.fromJson(row)).toList();
    _aptosSubject.add(list);
  }

  @override
  Future<void> deleteApartamento(String apartamentoId) async {
    await _supabase.from('unidades').delete().eq('apartamento_id', apartamentoId);
    await _supabase.from('apartamentos').delete().eq('id', apartamentoId);
  }

  // ── UNIDADES ──

  @override
  Stream<List<Unidade>> watchUnidades(String condominiumId) {
    Future<void> refreshRemote() async {
      try {
        print('⏳ [StructureRepo] Proactive Remote Fetch for Unidades...');
        final remote = await _supabase
            .from('unidades')
            .select('*, apartamentos(numero), blocos(nome_ou_numero)')
            .eq('condominio_id', condominiumId)
            .order('created_at', ascending: false);
        
        final list = (remote as List).map((row) {
          final aptoData = row['apartamentos'];
          final blocoData = row['blocos'];
          return Unidade.fromJson(row).copyWith(
            aptoNumero: aptoData is Map ? aptoData['numero']?.toString() : null,
            blocoNome: blocoData is Map ? blocoData['nome_ou_numero']?.toString() : null,
          );
        }).toList();
        _unidadesSubject.add(list);
      } catch (e) {
        print('❌ [StructureRepo] Remote unidades refresh error: $e');
      }
    }

    refreshRemote();

    return Rx.combineLatest2<List<Unidade>, List<Unidade>, List<Unidade>>(
      _db.watch('''
        SELECT 
          u.*,
          a.numero as apto_numero,
          b.nome_ou_numero as bloco_nome
        FROM unidades u
        LEFT JOIN apartamentos a ON u.apartamento_id = a.id
        LEFT JOIN blocos b ON u.bloco_id = b.id
        WHERE u.condominio_id = ?
        ORDER BY u.created_at DESC
      ''', parameters: [condominiumId]).map((rows) => rows.map((row) => Unidade.fromJson(row)).toList()),
      _unidadesSubject.stream,
      (local, remote) {
        final Map<String, Unidade> merged = {};
        for (var u in local) { merged[u.id] = u; }
        for (var u in remote) { merged[u.id] = u; }
        return merged.values.toList()..sort((a, b) => b.id.compareTo(a.id));
      }
    ).asBroadcastStream();
  }

  @override
  Future<void> generateUnidades({
    required String condominiumId,
    required List<String> blocoIds,
    required List<String> apartamentoIds,
  }) async {
    final List<Map<String, dynamic>> payload = [];
    print('⚡ [StructureRepo] Generating ${blocoIds.length * apartamentoIds.length} units...');
    
    for (final blocoId in blocoIds) {
      for (final aptoId in apartamentoIds) {
        final unitId = _generateId('unidade', blocoId, aptoId);
        payload.add({
          'id': unitId,
          'condominio_id': condominiumId,
          'bloco_id': blocoId,
          'apartamento_id': aptoId,
          'bloqueada': false,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    }
    
    await _supabase.from('unidades').upsert(
      payload,
      onConflict: 'condominio_id,bloco_id,apartamento_id',
    );
    print('✅ [StructureRepo] Units generated/upserted in Supabase.');

    final remote = await _supabase
        .from('unidades')
        .select('*, apartamentos(numero), blocos(nome_ou_numero)')
        .eq('condominio_id', condominiumId);
    
    final list = (remote as List).map((row) {
      final aptoData = row['apartamentos'];
      final blocoData = row['blocos'];
      return Unidade.fromJson(row).copyWith(
        aptoNumero: aptoData is Map ? aptoData['numero']?.toString() : null,
        blocoNome: blocoData is Map ? blocoData['nome_ou_numero']?.toString() : null,
      );
    }).toList();
    _unidadesSubject.add(list);
  }

  @override
  Future<void> deleteUnidade(String unidadeId) async {
    await _supabase.from('unidades').delete().eq('id', unidadeId);
  }
}
