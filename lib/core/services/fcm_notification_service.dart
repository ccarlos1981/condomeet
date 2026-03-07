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
    // Simulator doesn't support APNS tokens easily, providing a dummy for dev testing
    if (kDebugMode && defaultTargetPlatform == TargetPlatform.iOS) {
      _logger.i('Running on iOS Simulator/Debug - providing dummy FCM token');
      return 'dummy_fcm_token_for_simulator_${DateTime.now().millisecondsSinceEpoch}';
    }

    try {
      return await _fcm.getToken();
    } catch (e) {
      _logger.e('Error getting FCM token: $e');
      return null;
    }
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
