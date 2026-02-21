import 'package:condomeet/core/errors/result.dart';
import '../models/broadcast.dart';

abstract class BroadcastRepository {
  /// Fetches active broadcasts for the resident.
  Future<Result<List<Broadcast>>> getActiveBroadcasts();

  /// Marks a broadcast as read.
  Future<Result<void>> markAsRead(String broadcastId);

  /// Fetches historical broadcasts.
  Future<Result<List<Broadcast>>> getBroadcastHistory();
}
