import 'package:flutter/material.dart';
import 'package:condomeet/core/errors/result.dart';

abstract class MessagingService {
  /// Sends a notification to a resident about an event.
  /// Implementations should handle orchestration/fallbacks.
  Future<Result<void>> sendParcelAlert({
    required String residentName,
    required String residentPhone,
    required String unitNumber,
  });

  Future<Result<void>> sendPushNotification({
    required String residentName,
    required String unitNumber,
  });
}

class WhatsAppMessagingServiceMock implements MessagingService {
  @override
  Future<Result<void>> sendParcelAlert({
    required String residentName,
    required String residentPhone,
    required String unitNumber,
  }) async {
    // Simulate WhatsApp failure to trigger fallback (Story 2.5)
    // In a real scenario, this would be based on the result of the WhatsApp API call.
    final bool simulateWhatsAppFailure = DateTime.now().second % 2 == 0; 

    if (simulateWhatsAppFailure) {
      debugPrint('WHATSAPP: Falha simulada ao enviar para $residentPhone. Iniciando FALLBACK...');
      return await sendPushNotification(
        residentName: residentName,
        unitNumber: unitNumber,
      );
    }

    // WhatsApp Success
    await Future.delayed(const Duration(milliseconds: 500));
    debugPrint('SIMULATED WHATSAPP TO $residentPhone: [SUCCESS]');
    debugPrint('Olá $residentName, sua encomenda chegou na portaria para a unidade $unitNumber! 📦');
    return const Success(null);
  }

  @override
  Future<Result<void>> sendPushNotification({
    required String residentName,
    required String unitNumber,
  }) async {
    // Simulate Push Notification (FCM/Supabase)
    await Future.delayed(const Duration(milliseconds: 300));
    debugPrint('SIMULATED PUSH NOTIFICATION:');
    debugPrint('Condomeet: Olá $residentName, nova encomenda para a unidade $unitNumber! 📦');
    return const Success(null);
  }
}
