import 'package:flutter/material.dart';

@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  const AppThemeColors({
    required this.background,
    required this.sidebar,
    required this.border,
    required this.primary,
    required this.primaryDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.hover,
    required this.selected,
    required this.error,
  });

  final Color background;
  final Color sidebar;
  final Color border;
  final Color primary;
  final Color primaryDark;
  final Color textPrimary;
  final Color textSecondary;
  final Color hover;
  final Color selected;
  final Color error;

  static const AppThemeColors light = AppThemeColors(
    background: Color(0xFFF4F5F7),
    sidebar: Color(0xFFFFFFFF),
    border: Color(0xFFE8E8E8),
    primary: Color(0xFF00B96B),
    primaryDark: Color(0xFF009456),
    textPrimary: Color(0xFF262626),
    textSecondary: Color(0xFF8C8C8C),
    hover: Color(0xFFF0F0F0),
    selected: Color(0xFFE6F7EF),
    error: Color(0xFFFF4D4F),
  );

  static const AppThemeColors dark = AppThemeColors(
    background: Color(0xFF121212),
    sidebar: Color(0xFF1E1E1E),
    border: Color(0xFF333333),
    primary: Color(0xFF00B96B),
    primaryDark: Color(0xFF00D47A),
    textPrimary: Color(0xFFE8E8E8),
    textSecondary: Color(0xFF9A9A9A),
    hover: Color(0xFF2A2A2A),
    selected: Color(0xFF1A3D2E),
    error: Color(0xFFFF6B6B),
  );

  @override
  AppThemeColors copyWith({
    Color? background,
    Color? sidebar,
    Color? border,
    Color? primary,
    Color? primaryDark,
    Color? textPrimary,
    Color? textSecondary,
    Color? hover,
    Color? selected,
    Color? error,
  }) {
    return AppThemeColors(
      background: background ?? this.background,
      sidebar: sidebar ?? this.sidebar,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      hover: hover ?? this.hover,
      selected: selected ?? this.selected,
      error: error ?? this.error,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) {
      return this;
    }
    return AppThemeColors(
      background: Color.lerp(background, other.background, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      border: Color.lerp(border, other.border, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      hover: Color.lerp(hover, other.hover, t)!,
      selected: Color.lerp(selected, other.selected, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppThemeColors get appColors =>
      Theme.of(this).extension<AppThemeColors>() ?? AppThemeColors.light;
}

ThemeData buildAppTheme({required Brightness brightness}) {
  final colors =
      brightness == Brightness.dark ? AppThemeColors.dark : AppThemeColors.light;

  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: colors.primary,
    onPrimary: Colors.white,
    secondary: const Color(0xFF1677FF),
    onSecondary: Colors.white,
    error: colors.error,
    onError: Colors.white,
    surface: colors.sidebar,
    onSurface: colors.textPrimary,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colors.background,
    extensions: [colors],
    appBarTheme: AppBarTheme(
      backgroundColor: colors.sidebar,
      foregroundColor: colors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.sidebar,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: brightness == Brightness.dark
          ? const Color(0xFF2A2A2A)
          : Colors.white,
      labelStyle: TextStyle(color: colors.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.primary,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colors.border,
      thickness: 1,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: colors.textSecondary,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colors.selected,
      labelStyle: TextStyle(color: colors.primary, fontSize: 12),
      side: BorderSide(color: colors.primary.withValues(alpha: 0.3)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    ),
  );
}

ThemeData buildLightTheme() => buildAppTheme(brightness: Brightness.light);

ThemeData buildDarkTheme() => buildAppTheme(brightness: Brightness.dark);