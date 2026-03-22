import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Android notification channel matching the FCM channel_id "avisos"
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'avisos', // Must match the channel_id sent from the server
    'Avisos',
    description: 'Notificações do Condomeet',
    importance: Importance.high,
    playSound: true,
  );

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
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        _logger.i('User granted provisional notification permission');
      } else {
        _logger.w(
            'User declined or has not accepted notification permission');
      }

      // ── iOS: show notification banners even when app is in foreground ──
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // ── Android: create the notification channel + init local plugin ──
      await _initLocalNotifications();

      setupHandlers();
    } catch (e) {
      _logger.e('Error initializing FCM: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(settings: initSettings);

    // Create the Android channel (idempotent)
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(_channel);
    }
  }

  @override
  Future<String?> getToken() async {
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
    // ── Foreground messages → show as local notification ──
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _logger.i(
          '🔔 Foreground message received: ${message.notification?.title}');

      final notification = message.notification;
      if (notification != null) {
        _showLocalNotification(
          title: notification.title ?? '',
          body: notification.body ?? '',
          data: message.data,
        );
      }
    });

    // Handle interaction when app is in background but not terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _logger.i('App opened via notification: ${message.data}');
    });
  }

  /// Show a local notification (used for foreground FCM messages on Android)
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: data?.toString(),
    );
  }

  @override
  void dispose() {
    // Clean up if necessary
  }
}
