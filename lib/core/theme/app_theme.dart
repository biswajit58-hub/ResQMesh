import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF060D18);
  static const backgroundAlt = Color(0xFF081422);
  static const surface = Color(0xFF0C1A2B);
  static const surfaceAlt = Color(0xFF102238);
  static const surfaceHigh = Color(0xFF152B45);
  static const border = Color(0xFF1C3450);
  static const borderStrong = Color(0xFF2B4C70);

  static const text = Color(0xFFF2F7FF);
  static const textMuted = Color(0xFF8EA5BF);
  static const textDim = Color(0xFF5E7896);

  static const red = Color(0xFFFF3B4E);
  static const redDeep = Color(0xFFB91F32);
  static const redSoft = Color(0x33FF3B4E);
  static const cyan = Color(0xFF34D6F5);
  static const cyanSoft = Color(0x2634D6F5);
  static const blue = Color(0xFF4C7DFF);
  static const blueSoft = Color(0x264C7DFF);
  static const green = Color(0xFF39D98A);
  static const greenSoft = Color(0x2639D98A);
  static const amber = Color(0xFFF8C24A);
  static const amberSoft = Color(0x26F8C24A);
  static const purple = Color(0xFFA78BFA);

  static const gradientEmergency = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF495C), Color(0xFFC31E34)],
  );
  static const gradientCyan = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF35D8F4), Color(0xFF2175E8)],
  );
  static const gradientSurface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF102338), Color(0xFF0A1727)],
  );
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.cyan,
        secondary: AppColors.blue,
        surface: AppColors.surface,
        error: AppColors.red,
        onPrimary: AppColors.background,
        onSurface: AppColors.text,
        onError: Colors.white,
      ),
      fontFamily: 'Roboto',
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
        fontFamily: 'Roboto',
      ).copyWith(
        displayLarge: const TextStyle(
          fontSize: 36,
          height: 1.05,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.1,
          color: AppColors.text,
        ),
        displayMedium: const TextStyle(
          fontSize: 30,
          height: 1.08,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
          color: AppColors.text,
        ),
        headlineLarge: const TextStyle(
          fontSize: 25,
          height: 1.15,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: AppColors.text,
        ),
        headlineMedium: const TextStyle(
          fontSize: 21,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: AppColors.text,
        ),
        titleLarge: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
        titleMedium: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
        bodyLarge: const TextStyle(
          fontSize: 15,
          height: 1.45,
          color: AppColors.text,
        ),
        bodyMedium: const TextStyle(
          fontSize: 13.5,
          height: 1.45,
          color: AppColors.text,
        ),
        bodySmall: const TextStyle(
          fontSize: 11.5,
          height: 1.4,
          color: AppColors.textDim,
        ),
        labelLarge: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: AppColors.text,
        ),
        labelSmall: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: AppColors.textDim,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        hintStyle: const TextStyle(color: AppColors.textDim, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.cyan, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.red),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.text),
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.cyanSoft,
        height: 66,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 10.5,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? AppColors.cyan
                  : AppColors.textDim,
            )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              size: 22,
              color: states.contains(WidgetState.selected)
                  ? AppColors.cyan
                  : AppColors.textDim,
            )),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: const TextStyle(color: AppColors.text, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceAlt,
        selectedColor: AppColors.cyanSoft,
        side: const BorderSide(color: AppColors.border),
        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.cyan,
        inactiveTrackColor: AppColors.surfaceHigh,
        thumbColor: AppColors.cyan,
        overlayColor: AppColors.cyanSoft,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.background
                : AppColors.textMuted),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.cyan
                : AppColors.surfaceHigh),
      ),
    );
  }
}
