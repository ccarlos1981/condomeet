import 'package:flutter/material.dart';

/// Dinglo's independent blue theme — visually separate from Condomeet's coral/red
class DingloTheme {
  DingloTheme._();

  // ── Primary Colors ──────────────────────────────────────────────────
  static const Color primary = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color primaryLight = Color(0xFF93C5FD);
  static const Color accent = Color(0xFF06B6D4);

  // ── Background ──────────────────────────────────────────────────────
  static const Color background = Color(0xFFF0F4FF);
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFF8FAFF);

  // ── Text ────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // ── Semantic ────────────────────────────────────────────────────────
  static const Color income = Color(0xFF10B981);    // verde receita
  static const Color expense = Color(0xFFEF4444);   // vermelho despesa
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // ── Gradients ───────────────────────────────────────────────────────
  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient incomeGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient expenseGradient = LinearGradient(
    colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Border Radius ──────────────────────────────────────────────────
  static final BorderRadius cardRadius = BorderRadius.circular(16);
  static final BorderRadius buttonRadius = BorderRadius.circular(12);
  static final BorderRadius inputRadius = BorderRadius.circular(12);
  static final BorderRadius chipRadius = BorderRadius.circular(20);

  // ── Shadows ─────────────────────────────────────────────────────────
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: primary.withValues(alpha: 0.08),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: primary.withValues(alpha: 0.15),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  // ── Text Styles ─────────────────────────────────────────────────────
  static const TextStyle heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: textPrimary,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: textMuted,
  );

  static const TextStyle money = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    letterSpacing: -1,
  );

  static const TextStyle moneySmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: textPrimary,
  );

  // ── Helper: format BRL currency ─────────────────────────────────────
  static String formatCurrency(double value) {
    final abs = value.abs();
    final formatted = 'R\$ ${abs.toStringAsFixed(2).replaceAll('.', ',')}';
    return value < 0 ? '- $formatted' : formatted;
  }

  static String formatCurrencyCompact(double value) {
    if (value.abs() >= 1000000) {
      return 'R\$ ${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value.abs() >= 1000) {
      return 'R\$ ${(value / 1000).toStringAsFixed(1)}K';
    }
    return formatCurrency(value);
  }

  // ── Helper: icon mapping (from Bubble data) ─────────────────────────
  static IconData getIcon(String? iconName) {
    switch (iconName) {
      case 'restaurant':        return Icons.restaurant_rounded;
      case 'directions_car':    return Icons.directions_car_rounded;
      case 'home':              return Icons.home_rounded;
      case 'local_hospital':    return Icons.local_hospital_rounded;
      case 'school':            return Icons.school_rounded;
      case 'sports_esports':    return Icons.sports_esports_rounded;
      case 'checkroom':         return Icons.checkroom_rounded;
      case 'shopping_cart':     return Icons.shopping_cart_rounded;
      case 'subscriptions':     return Icons.subscriptions_rounded;
      case 'pets':              return Icons.pets_rounded;
      case 'more_horiz':        return Icons.more_horiz_rounded;
      case 'payments':          return Icons.payments_rounded;
      case 'work':              return Icons.work_rounded;
      case 'trending_up':       return Icons.trending_up_rounded;
      case 'attach_money':      return Icons.attach_money_rounded;
      case 'savings':           return Icons.savings_rounded;
      case 'receipt':           return Icons.receipt_rounded;
      default:                  return Icons.category_rounded;
    }
  }

  static Color parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return primary;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return primary;
    }
  }
}
