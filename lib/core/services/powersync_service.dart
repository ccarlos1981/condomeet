import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import '../network/powersync_schema.dart' as psSchema;

class SupabaseConnector extends PowerSyncBackendConnector {
  final SupabaseClient supabase;

  SupabaseConnector(this.supabase);

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    final session = supabase.auth.currentSession;
    if (session == null) return null;

    final token = session.accessToken;
    final userId = session.user.id;

    return PowerSyncCredentials(
      endpoint: 'https://69a342260f29674a8633a165.powersync.journeyapps.com',
      token: token,
      userId: userId,
    );
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final batch = await database.getCrudBatch();
    if (batch == null) return;

    try {
      for (var row in batch.crud) {
        final table = row.table;
        final op = row.op;
        final data = Map<String, dynamic>.from(row.opData ?? {});
        data['id'] = row.id;



        try {
          if (op == UpdateType.put) {
            await supabase.from(table).upsert(data);
          } else if (op == UpdateType.patch) {
            await supabase.from(table).update(data).eq('id', row.id);
          } else if (op == UpdateType.delete) {
            await supabase.from(table).delete().eq('id', row.id);
          }
        } catch (e) {
          if (e is PostgrestException && e.code == '23505') {
            print('⚠️ PowerSync Sync: Duplicate key in $table ($e). Skipping.');
          } else if (e is PostgrestException && e.code == '23503') {
            print('❌ PowerSync Sync: FK Violation in $table. Skipping. Error: $e');
          } else if (e is PostgrestException && (e.code == '42501' || e.code == 'PGRST204' || e.code == 'PGRST200')) {
            // Error in schema (missing column/table) or RLS. Dropping to unblock.
            print('🛡️ PowerSync Outbox: Schema/RLS Error in $table (${e.code}). Dropping record.');
          } else if (e is PostgrestException && (e.code == '23503' || e.code == '23505')) {
            // FK or Duplicate key. Dropping to restore sync.
            print('🪝 PowerSync Outbox: Conflict/FK Error in $table (${e.code}). Dropping record.');
          } else {
            rethrow;
          }
        }
      }
      await batch.complete();
    } catch (e) {
      rethrow;
    }
  }
}

class PowerSyncService {
  late final PowerSyncDatabase db;

  Future<void> initialize(SupabaseClient supabase) async {
    final dir = await getApplicationSupportDirectory();
    final path = join(dir.path, 'condomeet.db');

    db = PowerSyncDatabase(
      schema: psSchema.psSchema,
      path: path,
    );

    await db.initialize();

    await db.connect(connector: SupabaseConnector(supabase));
  }
}
