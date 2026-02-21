import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/security/domain/models/broadcast.dart';
import 'package:condomeet/features/security/domain/repositories/broadcast_repository.dart';

class BroadcastRepositoryImpl implements BroadcastRepository {
  final List<Broadcast> _mockBroadcasts = [
    Broadcast(
      id: '1',
      title: 'Manutenção na Piscina',
      content: 'A piscina ficará interditada para limpeza nesta segunda-feira das 08h às 17h.',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      priority: BroadcastPriority.normal,
    ),
    Broadcast(
      id: '2',
      title: 'Falta de Água Programada',
      content: 'A Sabesp informou que perderemos pressão no bairro amanhã. Economizem água!',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      priority: BroadcastPriority.important,
    ),
    Broadcast(
      id: '3',
      title: 'REUNIÃO EXTRAORDINÁRIA',
      content: 'Pauta urgente: Instalação de câmeras de reconhecimento facial. Hoje às 19h no salão.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      priority: BroadcastPriority.critical,
    ),
  ];

  @override
  Future<Result<List<Broadcast>>> getActiveBroadcasts() async {
    await Future.delayed(const Duration(milliseconds: 100));
    final results = _mockBroadcasts.where((b) => !b.isRead).toList();
    return Success(results);
  }

  @override
  Future<Result<void>> markAsRead(String broadcastId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return const Success(null);
  }

  @override
  Future<Result<List<Broadcast>>> getBroadcastHistory() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return Success(_mockBroadcasts);
  }
}
