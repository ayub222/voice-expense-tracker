import 'package:flutter/material.dart';

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class AppRadius {
  static const BorderRadius sm = BorderRadius.all(Radius.circular(6));
  static const BorderRadius md = BorderRadius.all(Radius.circular(10));
  static const BorderRadius lg = BorderRadius.all(Radius.circular(16));
  static const BorderRadius full = BorderRadius.all(Radius.circular(999));
}

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color income;
  final Color expense;
  final Color heroBg;
  final Color heroFg;

  const AppSemanticColors({
    required this.income,
    required this.expense,
    required this.heroBg,
    required this.heroFg,
  });

  @override
  AppSemanticColors copyWith({
    Color? income,
    Color? expense,
    Color? heroBg,
    Color? heroFg,
  }) {
    return AppSemanticColors(
      income: income ?? this.income,
      expense: expense ?? this.expense,
      heroBg: heroBg ?? this.heroBg,
      heroFg: heroFg ?? this.heroFg,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      income: Color.lerp(income, other.income, t) ?? income,
      expense: Color.lerp(expense, other.expense, t) ?? expense,
      heroBg: Color.lerp(heroBg, other.heroBg, t) ?? heroBg,
      heroFg: Color.lerp(heroFg, other.heroFg, t) ?? heroFg,
    );
  }
}

class AppTheme {
  static ThemeData lightTheme() {
    const bg = Color(0xFFF8FAFC);
    const surface = Color(0xFFFFFFFF);
    const border = Color(0xFFE2E8F0);
    const primary = Color(0xFF2563EB);
    const text = Color(0xFF0F172A);
    const textMuted = Color(0xFF475569);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      surface: surface,
      error: const Color(0xFFDC2626),
    ).copyWith(
      surfaceContainerLow: surface,
      surfaceContainerHighest: const Color(0xFFF1F5F9),
      onSurface: text,
      onSurfaceVariant: textMuted,
      outlineVariant: border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      extensions: const [
        AppSemanticColors(
          income: Color(0xFF16A34A),
          expense: Color(0xFFDC2626),
          heroBg: Color(0xFF1D4ED8),
          heroFg: Color(0xFFFFFFFF),
        ),
      ],
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: textMuted,
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
        ),
      ),
    );
  }
}
