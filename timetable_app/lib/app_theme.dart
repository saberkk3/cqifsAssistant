import 'package:flutter/material.dart';

import 'app_palette.dart';

abstract final class AppColors {
  static const primary = Color(0xFF0D5DBD);
  static const primaryDark = Color(0xFF083F86);
  static const primarySoft = Color(0xFFE7F1FD);
  static const background = Color(0xFFF4F8FE);
  static const text = Color(0xFF17324D);
  static const muted = Color(0xFF6D7F92);
  static const border = Color(0xFFDDE8F5);
  static const success = Color(0xFF1F8A5B);
  static const warning = Color(0xFFB56A00);
}

ThemeData buildAppTheme({
  required AppThemeColor themeColor,
  required Color timetableBackground,
  required Brightness platformBrightness,
}) {
  final effective = switch (themeColor) {
    AppThemeColor.system =>
      platformBrightness == Brightness.dark
          ? AppThemeColor.black
          : AppThemeColor.white,
    _ => themeColor,
  };
  final isBlack = effective == AppThemeColor.black;
  final isWhite = effective == AppThemeColor.white;
  final primary = isBlack ? const Color(0xFFF2F2F2) : effective.primary;

  final surface = isBlack ? const Color(0xFF111111) : Colors.white;
  final scaffold = isBlack
      ? Colors.black
      : isWhite
      ? const Color(0xFFF7F8FA)
      : Color.alphaBlend(
          primary.withValues(alpha: 0.035),
          const Color(0xFFF8FAFD),
        );
  final textColor = isBlack ? const Color(0xFFF4F4F4) : AppColors.text;
  final mutedColor = isBlack ? const Color(0xFFA8A8A8) : AppColors.muted;
  final borderColor = isBlack ? const Color(0xFF343434) : AppColors.border;
  final primarySoft = isBlack
      ? const Color(0xFF252525)
      : Color.alphaBlend(
          primary.withValues(alpha: isWhite ? 0.09 : 0.1),
          Colors.white,
        );
  final onPrimary = isBlack ? Colors.black : Colors.white;
  final appBarColor = isBlack
      ? Colors.black
      : isWhite
      ? Colors.white
      : primary;
  final appBarForeground = isBlack
      ? Colors.white
      : isWhite
      ? AppColors.text
      : Colors.white;
  final resolvedTimetableBackground =
      isBlack && timetableBackground.computeLuminance() > 0.35
      ? const Color(0xFF0B0B0B)
      : timetableBackground;

  final colorScheme = ColorScheme(
    brightness: isBlack ? Brightness.dark : Brightness.light,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primarySoft,
    onPrimaryContainer: isBlack ? Colors.white : AppColors.primaryDark,
    secondary: primary,
    onSecondary: onPrimary,
    surface: surface,
    onSurface: textColor,
    onSurfaceVariant: mutedColor,
    error: isBlack ? const Color(0xFFFF6B6B) : const Color(0xFFBA1A1A),
    onError: Colors.white,
    outline: borderColor,
    outlineVariant: borderColor,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: isBlack ? Brightness.dark : Brightness.light,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffold,
    splashFactory: InkSparkle.splashFactory,
    extensions: [
      AppCustomTheme(
        timetableBackground: resolvedTimetableBackground,
        isDark: isBlack,
        cardColor: surface,
        textColor: textColor,
        mutedColor: mutedColor,
        borderColor: borderColor,
      ),
    ],
    appBarTheme: AppBarTheme(
      backgroundColor: appBarColor,
      foregroundColor: appBarForeground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: appBarForeground,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isBlack ? const Color(0xFF080808) : Colors.white,
      indicatorColor: primarySoft,
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          color: states.contains(WidgetState.selected) ? primary : mutedColor,
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected) ? primary : mutedColor,
        );
      }),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        side: BorderSide(color: borderColor),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isBlack ? const Color(0xFF171717) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      hintStyle: TextStyle(color: mutedColor),
      prefixIconColor: primary,
      labelStyle: TextStyle(color: mutedColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    dividerTheme: DividerThemeData(color: borderColor),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isBlack ? const Color(0xFFECECEC) : AppColors.text,
      contentTextStyle: TextStyle(color: isBlack ? Colors.black : Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
