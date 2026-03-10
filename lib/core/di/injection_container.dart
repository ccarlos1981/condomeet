import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/services/powersync_service.dart';
import 'package:condomeet/core/services/security_service.dart';
import 'package:condomeet/core/services/notification_service.dart';
import 'package:condomeet/core/services/fcm_notification_service.dart';

// Repositories
import 'package:condomeet/shared/repositories/condominium_repository.dart';
import 'package:condomeet/features/access/domain/repositories/invitation_repository.dart';
import 'package:condomeet/features/access/data/repositories/invitation_repository_impl.dart';
import 'package:condomeet/features/auth/domain/repositories/consent_repository.dart';
import 'package:condomeet/features/auth/data/repositories/consent_repository_impl.dart';
import 'package:condomeet/features/auth/domain/repositories/auth_repository.dart';
import 'package:condomeet/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:condomeet/features/portaria/domain/repositories/parcel_repository.dart';
import 'package:condomeet/features/portaria/data/repositories/parcel_repository_impl.dart';
import 'package:condomeet/features/portaria/domain/repositories/resident_repository.dart';
import 'package:condomeet/features/portaria/data/repositories/resident_repository_impl.dart';
import 'package:condomeet/features/security/domain/repositories/sos_repository.dart';
import 'package:condomeet/features/security/data/repositories/sos_repository_impl.dart';
import 'package:condomeet/features/security/domain/repositories/occurrence_repository.dart';
import 'package:condomeet/features/security/data/repositories/occurrence_repository_impl.dart';
import 'package:condomeet/features/security/domain/repositories/chat_repository.dart';
import 'package:condomeet/features/security/data/repositories/chat_repository_impl.dart';
import 'package:condomeet/features/community/domain/repositories/booking_repository.dart';
import 'package:condomeet/features/community/data/repositories/booking_repository_impl.dart';
import 'package:condomeet/features/community/domain/repositories/document_repository.dart';
import 'package:condomeet/features/community/data/repositories/document_repository_impl.dart';
import 'package:condomeet/features/admin/domain/repositories/inventory_repository.dart';
import 'package:condomeet/features/admin/data/repositories/inventory_repository_impl.dart';
import 'package:condomeet/features/admin/domain/repositories/assembly_repository.dart';
import 'package:condomeet/features/admin/data/repositories/assembly_repository_impl.dart';
import 'package:condomeet/features/admin/domain/repositories/structure_repository.dart';
import 'package:condomeet/features/admin/data/repositories/structure_repository_impl.dart';

// Blocs
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/access/presentation/bloc/invitation_bloc.dart';
import 'package:condomeet/features/parcels/presentation/bloc/parcel_bloc.dart';
import 'package:condomeet/features/security/presentation/bloc/sos_bloc.dart';
import 'package:condomeet/features/security/presentation/bloc/occurrence_bloc.dart';
import 'package:condomeet/features/security/presentation/bloc/chat_bloc.dart';
import 'package:condomeet/features/community/presentation/bloc/booking_bloc.dart';
import 'package:condomeet/features/community/presentation/bloc/document_bloc.dart';
import 'package:condomeet/features/admin/presentation/bloc/inventory_bloc.dart';
import 'package:condomeet/features/admin/presentation/bloc/assembly_bloc.dart';
import 'package:condomeet/features/admin/presentation/bloc/structure_bloc.dart';
import 'package:condomeet/features/admin/presentation/bloc/structure_event.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // External
  sl.registerLazySingleton(() => Supabase.instance.client);

  // Core Services
  sl.registerLazySingleton(() => SecurityService());
  
  // Storage & Sync
  final powerSyncService = PowerSyncService();
  await powerSyncService.initialize(sl());
  sl.registerLazySingleton(() => powerSyncService);

  // Notifications
  sl.registerLazySingleton<NotificationService>(() => FcmNotificationService());

  // Repositories
  sl.registerLazySingleton<CondominiumRepository>(
    () => CondominiumRepositoryImpl(sl(), sl()),
  );
  sl.registerLazySingleton<InvitationRepository>(
    () => InvitationRepositoryImpl(sl(), sl()),
  );
  sl.registerLazySingleton<ConsentRepository>(
    () => ConsentRepositoryImpl(sl(), sl()),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(supabase: sl()),
  );
  sl.registerLazySingleton<ParcelRepository>(
    () => ParcelRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<ResidentRepository>(
    () => ResidentRepositoryImpl(sl(), sl(), sl()),
  );
  sl.registerLazySingleton<SOSRepository>(
    () => SOSRepositoryImpl(sl(), sl()),
  );
  sl.registerLazySingleton<OccurrenceRepository>(
    () => OccurrenceRepositoryImpl(),
  );
  sl.registerLazySingleton<ChatRepository>(
    () => ChatRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<BookingRepository>(
    () => BookingRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<DocumentRepository>(
    () => DocumentRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<InventoryRepository>(
    () => InventoryRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<AssemblyRepository>(
    () => AssemblyRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<StructureRepository>(
    () => StructureRepositoryImpl(sl<PowerSyncService>().db, sl<SupabaseClient>()),
  );

  // Blocs
  sl.registerLazySingleton(
    () => AuthBloc(
      authRepository: sl(),
      securityService: sl(),
      consentRepository: sl(),
    ),
  );
  sl.registerFactory(
    () => InvitationBloc(invitationRepository: sl()),
  );
  sl.registerFactory(
    () => SOSBloc(sosRepository: sl()),
  );
  sl.registerFactory(
    () => OccurrenceBloc(occurrenceRepository: sl()),
  );
  sl.registerFactory(
    () => ChatBloc(chatRepository: sl()),
  );
  sl.registerFactory(
    () => ParcelBloc(sl()),
  );
  sl.registerFactory(
    () => BookingBloc(bookingRepository: sl()),
  );
  sl.registerFactory(
    () => DocumentBloc(documentRepository: sl()),
  );
  sl.registerFactory(
    () => InventoryBloc(inventoryRepository: sl()),
  );
  sl.registerFactory(
    () => AssemblyBloc(assemblyRepository: sl()),
  );
  sl.registerFactory(
    () => StructureBloc(structureRepository: sl()),
  );
}
