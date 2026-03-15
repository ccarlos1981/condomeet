import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:condomeet/core/services/notification_service.dart';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

class FcmNotificationService implements NotificationService {
  FirebaseMessaging? _fcmInstance;
  FirebaseMessaging get _fcm {
    try {
      return _fcmInstance ??= FirebaseMessaging.instance;
    } catch (e) {
      throw Exception('Firebase Messaging not initialized: $e');
    }
  }
  final Logger _logger = Logger();

  @override
  Future<void> initialize() async {
    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        _logger.i('User granted notification permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        _logger.i('User granted provisional notification permission');
      } else {
        _logger.w('User declined or has not accepted notification permission');
      }

      setupHandlers();
    } catch (e) {
      _logger.e('Error initializing FCM: $e');
    }
  }

  @override
  Future<String?> getToken() async {
    // Em dispositivo físico real, sempre tenta o token Firebase diretamente
    // O dummy token só é fornecido no Simulator (onde APNS não funciona)
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        _logger.i('FCM token obtido: ${token.substring(0, 20)}...');
        return token;
      }
    } catch (e) {
      _logger.w('Não foi possível obter FCM token real: $e');
    }

    // Fallback: dummy token (Simulator ou erro irrecuperável)
    if (kDebugMode) {
      _logger.i('Usando dummy FCM token (provavelmente no Simulator)');
      return 'dummy_fcm_token_for_simulator_${DateTime.now().millisecondsSinceEpoch}';
    }
    return null;
  }

  @override
  void setupHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _logger.i('🔔 Foreground message received: ${message.notification?.title}');
      print('🔥 FCM MESSAGE DATA: ${message.data}');
      if (message.notification != null) {
        print('🔥 FCM NOTIFICATION: ${message.notification!.title} - ${message.notification!.body}');
      }
      // Handle foreground notification (e.g., show a snackbar or update UI)
    });

    // Handle interaction when app is in background but not terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _logger.i('App opened via notification: ${message.data}');
    });
  }

  @override
  void dispose() {
    // Clean up if necessary
  }
}
