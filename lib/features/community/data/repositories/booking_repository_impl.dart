import 'dart:async';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/community/domain/models/common_area.dart';
import 'package:condomeet/features/community/domain/repositories/booking_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Uses Supabase directly (tables: areas_comuns, reservas).
/// The legacy PowerSync-backed BookingRepositoryImpl used the old 'reservas_areas'
/// table (schema 2.0) which is obsolete. The current DB schema uses 'reservas'
/// (migration 20260308g).
class BookingRepositoryImpl implements BookingRepository {
  final SupabaseClient _supabase;

  BookingRepositoryImpl(this._supabase);

  @override
  Stream<List<CommonArea>> watchCommonAreas(String condominiumId) {
    return Stream.fromIterable([0])
        .asyncExpand((_) async* {
          yield await _fetchCommonAreas(condominiumId);
          await for (final _ in Stream.periodic(const Duration(seconds: 15))) {
            yield await _fetchCommonAreas(condominiumId);
          }
        })
        .handleError((e) => print('❌ watchCommonAreas error: $e'));
  }

  Future<List<CommonArea>> _fetchCommonAreas(String condominiumId) async {
    final response = await _supabase
        .from('areas_comuns')
        .select('*')
        .eq('condominio_id', condominiumId)
        .eq('ativo', true)
        .order('tipo_agenda');
    return (response as List).map((r) => CommonArea.fromMap(r as Map<String, dynamic>)).toList();
  }

  @override
  Stream<List<AvailabilitySlot>> watchAvailability({
    required String condominiumId,
    required String areaId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return Stream.fromIterable([0])
        .asyncExpand((_) async* {
          yield await _fetchAvailability(
            areaId: areaId,
            startDate: startDate,
            endDate: endDate,
          );
          await for (final _ in Stream.periodic(const Duration(seconds: 15))) {
            yield await _fetchAvailability(
              areaId: areaId,
              startDate: startDate,
              endDate: endDate,
            );
          }
        })
        .handleError((e) => print('❌ watchAvailability error: $e'));
  }

  Future<List<AvailabilitySlot>> _fetchAvailability({
    required String areaId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final startStr = startDate.toIso8601String().split('T')[0];
    final endStr = endDate.toIso8601String().split('T')[0];

    final rows = await _supabase
        .from('reservas')
        .select('data_reserva')
        .eq('area_id', areaId)
        .inFilter('status', ['pendente', 'aprovado'])
        .gte('data_reserva', startStr)
        .lte('data_reserva', endStr);

    final bookedDates =
        (rows as List).map((r) => r['data_reserva'] as String).toSet();

    final slots = <AvailabilitySlot>[];
    for (int i = 0; i <= endDate.difference(startDate).inDays; i++) {
      final date = startDate.add(Duration(days: i));
      final dateStr = date.toIso8601String().split('T')[0];
      slots.add(AvailabilitySlot(
        date: date,
        isAvailable: !bookedDates.contains(dateStr),
      ));
    }
    return slots;
  }

  @override
  Future<Result<void>> createBooking({
    required String residentId,
    required String condominiumId,
    required String areaId,
    required DateTime date,
  }) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final bookingDate = DateTime(date.year, date.month, date.day);

      if (bookingDate.isBefore(today)) {
        return const Failure('Não é possível realizar reservas para datas passadas.');
      }

      final dateStr = bookingDate.toIso8601String().split('T')[0];

      // Check if date is already taken
      final existing = await _supabase
          .from('reservas')
          .select('id')
          .eq('area_id', areaId)
          .eq('data_reserva', dateStr)
          .inFilter('status', ['pendente', 'aprovado'])
          .maybeSingle();

      if (existing != null) {
        return const Failure('Esta data já está reservada por outro morador.');
      }

      // Check if resident already has an active booking for this area
      final residentFuture = await _supabase
          .from('reservas')
          .select('id')
          .eq('area_id', areaId)
          .eq('user_id', residentId)
          .gte('data_reserva', today.toIso8601String().split('T')[0])
          .inFilter('status', ['pendente', 'aprovado'])
          .maybeSingle();

      if (residentFuture != null) {
        return const Failure('Você já possui uma reserva ativa para este espaço.');
      }

      // Fetch area to check aprovacao_automatica
      final areaData = await _supabase
          .from('areas_comuns')
          .select('aprovacao_automatica')
          .eq('id', areaId)
          .maybeSingle();

      final autoApprove = areaData?['aprovacao_automatica'] == true;

      await _supabase.from('reservas').insert({
        'id': const Uuid().v4(),
        'area_id': areaId,
        'user_id': residentId,
        'condominio_id': condominiumId,
        'data_reserva': dateStr,
        'status': autoApprove ? 'aprovado' : 'pendente',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      return const Success(null);
    } catch (e) {
      return Failure('Erro ao realizar reserva: $e');
    }
  }

  @override
  Future<Result<void>> cancelBooking({
    required String bookingId,
    required String residentId,
  }) async {
    try {
      final booking = await _supabase
          .from('reservas')
          .select('user_id')
          .eq('id', bookingId)
          .maybeSingle();

      if (booking == null) {
        return const Failure('Reserva não encontrada.');
      }

      if (booking['user_id'] != residentId) {
        return const Failure('Você não tem permissão para cancelar esta reserva.');
      }

      await _supabase
          .from('reservas')
          .update({'status': 'cancelado', 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', bookingId);

      return const Success(null);
    } catch (e) {
      return Failure('Erro ao cancelar reserva: $e');
    }
  }
}
