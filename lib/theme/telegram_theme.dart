import 'package:flutter/material.dart';

/// Палитра и темы в духе Telegram (как в проекте «Алфавиты»).
abstract final class TelegramColors {
  static const Color blue = Color(0xFF3390EC);
  static const Color blueDarkMode = Color(0xFF5288C1);
  static const Color lightBg = Color(0xFFE7EBF0);
  static const Color lightHeader = Color(0xFFF6F6F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color subtitle = Color(0xFF707579);
  static const Color divider = Color(0xFFDADCE0);
  static const Color darkBg = Color(0xFF0E1621);
  static const Color darkHeader = Color(0xFF17212B);
  static const Color darkSurface = Color(0xFF17212B);
  static const Color darkSurfaceHigh = Color(0xFF242F3D);

  /// Вторичный текст в списке библиотеки (дата, прогресс) — тёплый жёлто-коричневый, не сливается с белым.
  static const Color libraryWarmLight = Color(0xFF6D5248);
  static const Color libraryWarmDark = Color(0xFFD4B88A);

  static Color libraryWarmSecondary(Brightness brightness) =>
      brightness == Brightness.dark ? libraryWarmDark : libraryWarmLight;
}

ThemeData telegramLightTheme() {
  const primary = TelegramColors.blue;
  final scheme = ColorScheme.light(
    primary: primary,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFC5E4FA),
    onPrimaryContainer: const Color(0xFF0A3D6B),
    secondary: primary,
    onSecondary: Colors.white,
    surface: TelegramColors.lightSurface,
    onSurface: const Color(0xFF222222),
    onSurfaceVariant: TelegramColors.subtitle,
    outline: TelegramColors.divider,
    outlineVariant: const Color(0xFFE8E8E8),
    error: const Color(0xFFE53935),
    onError: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: TelegramColors.lightBg,
    splashColor: primary.withValues(alpha: 0.12),
    highlightColor: primary.withValues(alpha: 0.08),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      backgroundColor: TelegramColors.lightHeader,
      foregroundColor: const Color(0xFF222222),
      surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(color: primary, size: 24),
      titleTextStyle: const TextStyle(
        color: Color(0xFF222222),
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: TelegramColors.lightSurface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.zero,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: primary,
      textColor: const Color(0xFF222222),
      titleTextStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
      ),
      subtitleTextStyle: const TextStyle(
        fontSize: 14,
        color: TelegramColors.subtitle,
        height: 1.35,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    dividerTheme: const DividerThemeData(
      color: TelegramColors.divider,
      thickness: 1,
      space: 1,
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: TelegramColors.lightSurface,
      elevation: 2,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: TelegramColors.lightSurface,
      foregroundColor: primary,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: TelegramColors.lightSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF3A3F45),
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

ThemeData telegramDarkTheme() {
  const primary = TelegramColors.blueDarkMode;
  final scheme = ColorScheme.dark(
    primary: primary,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFF2B5278),
    onPrimaryContainer: const Color(0xFFE1EFFE),
    secondary: primary,
    onSecondary: Colors.white,
    surface: TelegramColors.darkSurface,
    onSurface: const Color(0xFFE8E8E8),
    onSurfaceVariant: const Color(0xFF8D969C),
    outline: const Color(0xFF3E4C59),
    outlineVariant: const Color(0xFF2F3B47),
    error: const Color(0xFFFF6B6B),
    onError: Color(0xFF1A1A1A),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: TelegramColors.darkBg,
    splashColor: primary.withValues(alpha: 0.16),
    highlightColor: primary.withValues(alpha: 0.1),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      backgroundColor: TelegramColors.darkHeader,
      foregroundColor: const Color(0xFFE8E8E8),
      surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(color: primary, size: 24),
      titleTextStyle: const TextStyle(
        color: Color(0xFFE8E8E8),
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: TelegramColors.darkSurface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.zero,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: primary,
      textColor: const Color(0xFFE8E8E8),
      titleTextStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      subtitleTextStyle: const TextStyle(
        fontSize: 14,
        color: Color(0xFF8D969C),
        height: 1.35,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF2F3B47),
      thickness: 1,
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: TelegramColors.darkHeader,
      elevation: 2,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: TelegramColors.darkSurfaceHigh,
      foregroundColor: primary,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: TelegramColors.darkSurfaceHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF3A3F45),
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
