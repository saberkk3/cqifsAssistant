import 'package:flutter/material.dart';

enum AppThemeColor { white, black, system, blue, teal, purple, green, orange }

extension AppThemeColorX on AppThemeColor {
  String get label {
    return switch (this) {
      AppThemeColor.white => '白色',
      AppThemeColor.black => '纯黑',
      AppThemeColor.system => '跟随系统',
      AppThemeColor.blue => '海蓝',
      AppThemeColor.teal => '青绿',
      AppThemeColor.purple => '紫罗兰',
      AppThemeColor.green => '森绿',
      AppThemeColor.orange => '暖橙',
    };
  }

  Color get primary {
    return switch (this) {
      AppThemeColor.white => const Color(0xFF37474F),
      AppThemeColor.black => const Color(0xFFF2F2F2),
      AppThemeColor.system => const Color(0xFF37474F),
      AppThemeColor.blue => const Color(0xFF0D5DBD),
      AppThemeColor.teal => const Color(0xFF087F7B),
      AppThemeColor.purple => const Color(0xFF6A46B8),
      AppThemeColor.green => const Color(0xFF287A4B),
      AppThemeColor.orange => const Color(0xFFC05A16),
    };
  }

  Color get previewColor {
    return switch (this) {
      AppThemeColor.white => const Color(0xFFECEFF1),
      AppThemeColor.black => const Color(0xFF111111),
      AppThemeColor.system => const Color(0xFFECEFF1),
      _ => primary,
    };
  }

  Color get previewForeground {
    return switch (this) {
      AppThemeColor.white => const Color(0xFF263238),
      AppThemeColor.black => Colors.white,
      AppThemeColor.system => const Color(0xFF263238),
      _ => Colors.white,
    };
  }
}

class AppCustomTheme extends ThemeExtension<AppCustomTheme> {
  const AppCustomTheme({
    required this.timetableBackground,
    required this.isDark,
    required this.cardColor,
    required this.textColor,
    required this.mutedColor,
    required this.borderColor,
  });

  final Color timetableBackground;
  final bool isDark;
  final Color cardColor;
  final Color textColor;
  final Color mutedColor;
  final Color borderColor;

  @override
  AppCustomTheme copyWith({
    Color? timetableBackground,
    bool? isDark,
    Color? cardColor,
    Color? textColor,
    Color? mutedColor,
    Color? borderColor,
  }) {
    return AppCustomTheme(
      timetableBackground: timetableBackground ?? this.timetableBackground,
      isDark: isDark ?? this.isDark,
      cardColor: cardColor ?? this.cardColor,
      textColor: textColor ?? this.textColor,
      mutedColor: mutedColor ?? this.mutedColor,
      borderColor: borderColor ?? this.borderColor,
    );
  }

  @override
  AppCustomTheme lerp(AppCustomTheme? other, double t) {
    if (other == null) {
      return this;
    }
    return AppCustomTheme(
      timetableBackground: Color.lerp(
        timetableBackground,
        other.timetableBackground,
        t,
      )!,
      isDark: t < 0.5 ? isDark : other.isDark,
      cardColor: Color.lerp(cardColor, other.cardColor, t)!,
      textColor: Color.lerp(textColor, other.textColor, t)!,
      mutedColor: Color.lerp(mutedColor, other.mutedColor, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppCustomTheme get appTheme => Theme.of(this).extension<AppCustomTheme>()!;

  Color get appCard => appTheme.cardColor;
  Color get appText => appTheme.textColor;
  Color get appMuted => appTheme.mutedColor;
  Color get appBorder => appTheme.borderColor;
}

const timetableBackgroundOptions = [
  Color(0xFFFFFFFF),
  Color(0xFFF4F8FE),
  Color(0xFFF3FAF6),
  Color(0xFFFFF8F1),
  Color(0xFFF8F4FC),
];

const courseColorOptions = [
  Color(0xFFE4F0FE),
  Color(0xFFE8F5E9),
  Color(0xFFEDE7F6),
  Color(0xFFFCE4EC),
  Color(0xFFFFF8E1),
  Color(0xFFE0F7FA),
  Color(0xFFF3E5F5),
  Color(0xFFFFEBEE),
];
