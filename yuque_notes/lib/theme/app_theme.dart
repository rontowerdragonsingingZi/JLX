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

/// Windows / Android 共用的描边按钮样式（浅绿边 + 主题绿字，对齐登录框）。
ButtonStyle buildAppOutlinedButtonStyle(AppThemeColors colors) {
  final outlineSoft = colors.border;
  final outlineAccent = colors.primary.withValues(alpha: 0.45);
  return OutlinedButton.styleFrom(
    foregroundColor: colors.primary,
    backgroundColor: colors.sidebar,
    disabledForegroundColor: colors.textSecondary.withValues(alpha: 0.5),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    side: BorderSide(color: outlineAccent),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
  ).copyWith(
    side: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return BorderSide(color: outlineSoft);
      }
      if (states.contains(WidgetState.pressed) ||
          states.contains(WidgetState.focused) ||
          states.contains(WidgetState.hovered)) {
        return BorderSide(color: colors.primary, width: 1.5);
      }
      return BorderSide(color: outlineAccent);
    }),
  );
}

ThemeData buildAppTheme({required Brightness brightness}) {
  final colors =
      brightness == Brightness.dark ? AppThemeColors.dark : AppThemeColors.light;

  // 与登录输入框一致：默认浅描边，强调/聚焦用主题绿，避免 M3 默认黑框。
  final outlineSoft = colors.border;
  final outlineAccent = colors.primary.withValues(alpha: 0.45);

  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: colors.primary,
    onPrimary: Colors.white,
    secondary: const Color(0xFF1677FF),
    onSecondary: Colors.white,
    secondaryContainer: colors.selected,
    onSecondaryContainer: colors.primary,
    error: colors.error,
    onError: Colors.white,
    surface: colors.sidebar,
    onSurface: colors.textPrimary,
    surfaceContainerHighest: colors.hover,
    outline: outlineSoft,
    outlineVariant: outlineSoft,
  );

  final softRounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(6),
  );

  return ThemeData(
    // 同一套 Theme：Windows / Android 共用，不用平台自适应密度，避免边框观感不一致。
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    scaffoldBackgroundColor: colors.background,
    canvasColor: colors.sidebar,
    cardColor: colors.sidebar,
    dividerColor: outlineSoft,
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
      surfaceTintColor: Colors.transparent,
      shape: softRounded,
    ),
    cardTheme: CardThemeData(
      color: colors.sidebar,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: softRounded.copyWith(
        side: BorderSide(color: outlineSoft),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: brightness == Brightness.dark
          ? const Color(0xFF2A2A2A)
          : Colors.white,
      labelStyle: TextStyle(color: colors.textSecondary),
      hintStyle: TextStyle(color: colors.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: outlineSoft),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: outlineSoft),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: outlineSoft.withValues(alpha: 0.7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: colors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: colors.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: softRounded,
      ),
    ),
    // 「新建文件夹」「发送验证码」等：Windows / Android 同一套描边样式。
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: buildAppOutlinedButtonStyle(colors),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: colors.primary,
        backgroundColor: colors.selected,
        disabledForegroundColor: colors.textSecondary.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: softRounded,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.primary,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: outlineSoft,
      thickness: 1,
      space: 1,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: colors.textSecondary,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colors.selected,
      labelStyle: TextStyle(color: colors.primary, fontSize: 12),
      side: BorderSide(color: outlineAccent),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      shape: softRounded,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colors.sidebar,
      surfaceTintColor: Colors.transparent,
      shape: softRounded,
      textStyle: TextStyle(color: colors.textPrimary, fontSize: 14),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.sidebar),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(softRounded),
        side: WidgetStatePropertyAll(BorderSide(color: outlineSoft)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.textPrimary,
      contentTextStyle: TextStyle(color: colors.sidebar),
      behavior: SnackBarBehavior.floating,
      shape: softRounded,
    ),
  );
}

ThemeData buildLightTheme() => buildAppTheme(brightness: Brightness.light);

ThemeData buildDarkTheme() => buildAppTheme(brightness: Brightness.dark);