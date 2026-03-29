import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages Lista Inteligente subscription: trial, premium, and coupons.
class ListaSubscriptionService {
  ListaSubscriptionService._();

  static final _client = Supabase.instance.client;

  // ── RevenueCat Entitlement ────────────────────────────
  static const String entitlementId = 'lista_inteligente_premium';

  // ── Cache ─────────────────────────────────────────────
  static Map<String, dynamic>? _cachedSub;
  static DateTime? _cacheTime;

  static void clearCache() {
    _cachedSub = null;
    _cacheTime = null;
  }

  static String? get _userId => _client.auth.currentUser?.id;

  // ══════════════════════════════════════════════════════
  // TRIAL & SUBSCRIPTION STATUS
  // ══════════════════════════════════════════════════════

  /// Ensures the trial row exists. Call on first Lista Inteligente open.
  static Future<void> ensureTrialStarted() async {
    if (_userId == null) return;

    final existing = await _client
        .from('lista_user_subscription')
        .select()
        .eq('user_id', _userId!)
        .maybeSingle();

    if (existing == null) {
      await _client.from('lista_user_subscription').insert({
        'user_id': _userId,
      });
      clearCache();
    }
  }

  /// Get the subscription data (cached for 60 seconds)
  static Future<Map<String, dynamic>?> getSubscription() async {
    if (_userId == null) return null;

    // Return cache if fresh
    if (_cachedSub != null && _cacheTime != null) {
      if (DateTime.now().difference(_cacheTime!).inSeconds < 60) {
        return _cachedSub;
      }
    }

    final data = await _client
        .from('lista_user_subscription')
        .select()
        .eq('user_id', _userId!)
        .maybeSingle();

    _cachedSub = data;
    _cacheTime = DateTime.now();
    return data;
  }

  /// Check if user has premium access (trial active OR subscription active)
  static Future<bool> hasAccess() async {
    // 1) Check RevenueCat first (real subscription)
    if (!kIsWeb) {
      try {
        final customerInfo = await Purchases.getCustomerInfo();
        if (customerInfo.entitlements.active.containsKey(entitlementId)) {
          // Sync to Supabase
          _syncPremiumStatus(true, 'revenuecat');
          return true;
        }
      } catch (e) {
        debugPrint('ListaSubscription RevenueCat check error: $e');
      }
    }

    // 2) Check Supabase subscription row
    final sub = await getSubscription();
    if (sub == null) return true; // No row = hasn't opened Lista yet, allow

    // is_premium flag (set by coupon or RevenueCat sync)
    if (sub['is_premium'] == true) return true;

    // Trial check
    final trialEnds = DateTime.tryParse(sub['trial_ends_at'] ?? '');
    if (trialEnds != null && trialEnds.isAfter(DateTime.now())) {
      return true; // Trial still active
    }

    return false; // Trial expired, no subscription
  }

  /// Check if currently in trial period
  static Future<bool> isInTrial() async {
    final sub = await getSubscription();
    if (sub == null) return true;

    if (sub['is_premium'] == true && sub['subscription_source'] != 'trial') {
      return false; // Has real subscription
    }

    final trialEnds = DateTime.tryParse(sub['trial_ends_at'] ?? '');
    if (trialEnds != null && trialEnds.isAfter(DateTime.now())) {
      return true;
    }
    return false;
  }

  /// Get days remaining in trial (0 if expired)
  static Future<int> getDaysRemaining() async {
    final sub = await getSubscription();
    if (sub == null) return 60;

    final trialEnds = DateTime.tryParse(sub['trial_ends_at'] ?? '');
    if (trialEnds == null) return 0;

    final remaining = trialEnds.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
  }

  /// Get subscription source: 'trial', 'revenuecat', 'cupom'
  static Future<String> getSource() async {
    final sub = await getSubscription();
    return sub?['subscription_source'] ?? 'trial';
  }

  // ══════════════════════════════════════════════════════
  // FREE TIER LIMITS
  // ══════════════════════════════════════════════════════

  static const int freeMaxLists = 1;
  static const int freeMaxItemsPerList = 15;

  /// Check if user can create more lists
  static Future<bool> canCreateList(int currentListCount) async {
    if (await hasAccess()) return true;
    return currentListCount < freeMaxLists;
  }

  /// Check if user can add more items to a list
  static Future<bool> canAddItem(int currentItemCount) async {
    if (await hasAccess()) return true;
    return currentItemCount < freeMaxItemsPerList;
  }

  // ══════════════════════════════════════════════════════
  // COUPON SYSTEM
  // ══════════════════════════════════════════════════════

  /// Redeem a coupon code
  static Future<Map<String, dynamic>> redeemCoupon(String code) async {
    try {
      final result = await _client.rpc('lista_redeem_coupon', params: {
        'p_code': code.trim(),
      });
      clearCache(); // Invalidate cache after redemption
      return Map<String, dynamic>.from(result);
    } catch (e) {
      return {'success': false, 'error': 'Erro ao resgatar: $e'};
    }
  }

  // ══════════════════════════════════════════════════════
  // REVENUECAT INTEGRATION
  // ══════════════════════════════════════════════════════

  /// Get Lista Inteligente packages from RevenueCat
  static Future<List<Package>> getListaPackages() async {
    if (kIsWeb) return [];
    try {
      final offerings = await Purchases.getOfferings();
      // Try specific offering first, fallback to current
      final offering = offerings.getOffering('lista_inteligente') ?? offerings.current;
      if (offering == null) return [];
      return offering.availablePackages;
    } catch (e) {
      debugPrint('ListaSubscription getPackages error: $e');
      return [];
    }
  }

  /// Purchase a package
  static Future<bool> purchasePackage(Package package) async {
    if (kIsWeb) return false;
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      final isPremiumNow = result.customerInfo.entitlements.active.containsKey(entitlementId);

      if (isPremiumNow) {
        await _syncPremiumStatus(true, 'revenuecat');
      }
      return isPremiumNow;
    } catch (e) {
      debugPrint('ListaSubscription purchase error: $e');
      return false;
    }
  }

  /// Restore purchases
  static Future<bool> restorePurchases() async {
    if (kIsWeb) return false;
    try {
      final customerInfo = await Purchases.restorePurchases();
      final isPremiumNow = customerInfo.entitlements.active.containsKey(entitlementId);
      await _syncPremiumStatus(isPremiumNow, isPremiumNow ? 'revenuecat' : 'trial');
      return isPremiumNow;
    } catch (e) {
      debugPrint('ListaSubscription restore error: $e');
      return false;
    }
  }

  /// Sync premium status to Supabase
  static Future<void> _syncPremiumStatus(bool isPremium, String source) async {
    if (_userId == null) return;
    await _client.from('lista_user_subscription').upsert({
      'user_id': _userId,
      'is_premium': isPremium,
      'subscription_source': source,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id');
    clearCache();
  }
}
