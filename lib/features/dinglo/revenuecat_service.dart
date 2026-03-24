
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'plano_service.dart';

/// RevenueCat integration for Meu Bolso subscriptions
class RevenueCatService {
  RevenueCatService._();

  // ── API Keys (per platform) ─────────────────────────────────────
  static const String _appleApiKey = 'appl_FiGmtGoojoEqZpjdEVkIdLrBcYY';
  static const String _googleApiKey = 'goog_yNWMDTdIUCKkyWaHcUhZ0pZiGfL';

  // ── Entitlement ID (configured in RevenueCat dashboard) ─────────
  static const String entitlementId = 'meu_bolso_plus';

  // ── Product IDs (configured in App Store Connect / Google Play Console)
  static const String monthlyProductId = 'meu_bolso_plus_monthly';
  static const String yearlyProductId = 'meu_bolso_plus_yearly';

  /// Get the correct API key based on platform
  static String get _apiKey =>
      Platform.isIOS || Platform.isMacOS ? _appleApiKey : _googleApiKey;

  /// Initialize RevenueCat SDK
  static Future<void> initialize() async {
    if (kIsWeb) return; // RevenueCat doesn't support web

    await Purchases.setLogLevel(LogLevel.debug);

    PurchasesConfiguration configuration = PurchasesConfiguration(_apiKey);

    // Set the Supabase user ID as the app user ID for consistency
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      configuration = PurchasesConfiguration(_apiKey)..appUserID = userId;
    }

    await Purchases.configure(configuration);
  }

  /// Login user (call after Supabase auth login)
  static Future<void> loginUser(String userId) async {
    if (kIsWeb) return;
    try {
      await Purchases.logIn(userId);
    } catch (e) {
      debugPrint('RevenueCat loginUser error: $e');
    }
  }

  /// Logout user (call after Supabase auth logout)
  static Future<void> logoutUser() async {
    if (kIsWeb) return;
    try {
      await Purchases.logOut();
    } catch (e) {
      debugPrint('RevenueCat logoutUser error: $e');
    }
  }

  /// Check if user has active premium entitlement
  static Future<bool> isPremium() async {
    if (kIsWeb) return false;
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active.containsKey(entitlementId);
    } catch (e) {
      debugPrint('RevenueCat isPremium error: $e');
      return false;
    }
  }

  /// Get available packages (offerings)
  static Future<List<Package>> getPackages() async {
    if (kIsWeb) return [];
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null) return [];
      return current.availablePackages;
    } catch (e) {
      debugPrint('RevenueCat getPackages error: $e');
      return [];
    }
  }

  /// Purchase a package
  static Future<bool> purchasePackage(Package package) async {
    if (kIsWeb) return false;
    try {
      final result = await Purchases.purchasePackage(package);
      final customerInfo = result.customerInfo;
      final isPremiumNow = customerInfo.entitlements.active.containsKey(entitlementId);

      if (isPremiumNow) {
        // Sync with Supabase
        await _syncPlanToSupabase('plus');
      }

      return isPremiumNow;
    } catch (e) {
      debugPrint('RevenueCat purchase error: $e');
      return false;
    }
  }

  /// Restore purchases (e.g. after reinstall)
  static Future<bool> restorePurchases() async {
    if (kIsWeb) return false;
    try {
      final customerInfo = await Purchases.restorePurchases();
      final isPremiumNow = customerInfo.entitlements.active.containsKey(entitlementId);

      if (isPremiumNow) {
        await _syncPlanToSupabase('plus');
      } else {
        await _syncPlanToSupabase('basico');
      }

      return isPremiumNow;
    } catch (e) {
      debugPrint('RevenueCat restore error: $e');
      return false;
    }
  }

  /// Sync the RevenueCat subscription status to Supabase
  static Future<void> _syncPlanToSupabase(String plano) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase.from('dinglo_plano_usuario').upsert({
      'user_id': userId,
      'plano': plano,
      'ativo': true,
      'data_inicio': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id');

    PlanoService.clearCache();
  }

  /// Listen for subscription changes in real-time
  static void listenForChanges() {
    if (kIsWeb) return;
    Purchases.addCustomerInfoUpdateListener((customerInfo) async {
      final isPremiumNow = customerInfo.entitlements.active.containsKey(entitlementId);
      await _syncPlanToSupabase(isPremiumNow ? 'plus' : 'basico');
    });
  }
}
