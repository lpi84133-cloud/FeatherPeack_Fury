import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/fp_colors.dart';
import '../design/fp_tokens.dart';
import '../design/fp_typography.dart';

abstract final class FpTheme {
  static const overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: FpColors.canvas,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  static ThemeData build() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: FpColors.forest,
      onPrimary: Colors.white,
      primaryContainer: FpColors.forestTint,
      onPrimaryContainer: FpColors.forestDeep,
      secondary: FpColors.gold,
      onSecondary: FpColors.graphite,
      secondaryContainer: FpColors.goldTint,
      onSecondaryContainer: FpColors.goldDeep,
      tertiary: FpColors.skyDeep,
      onTertiary: Colors.white,
      tertiaryContainer: FpColors.skyTint,
      onTertiaryContainer: FpColors.graphite,
      error: FpColors.severe,
      onError: Colors.white,
      surface: FpColors.surface,
      onSurface: FpColors.graphite,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: FpColors.canvas,
      surfaceContainer: FpColors.surfaceAlt,
      onSurfaceVariant: FpColors.graphiteMid,
      outline: FpColors.outlineStrong,
      outlineVariant: FpColors.outline,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: FpColors.canvas,
      canvasColor: FpColors.canvas,
      textTheme: FpTypography.textTheme,
      fontFamily: FpFonts.text,
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: const DividerThemeData(
        color: FpColors.outline,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: FpColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: FpRadius.cardAll,
          side: FpBorders.hairline,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FpColors.forest,
          foregroundColor: Colors.white,
          disabledBackgroundColor: FpColors.outline,
          disabledForegroundColor: FpColors.graphiteSoft,
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: FpSpace.lg),
          textStyle: FpTypography.button,
          shape: const RoundedRectangleBorder(borderRadius: FpRadius.tileAll),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FpColors.forest,
          minimumSize: const Size.fromHeight(54),
          side: const BorderSide(color: FpColors.outlineStrong),
          textStyle: FpTypography.button,
          shape: const RoundedRectangleBorder(borderRadius: FpRadius.tileAll),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: FpColors.forest,
          textStyle: FpTypography.bodyStrong,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FpColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: FpSpace.md,
          vertical: FpSpace.md,
        ),
        hintStyle: FpTypography.body.copyWith(color: FpColors.graphiteSoft),
        labelStyle: FpTypography.label,
        border: const OutlineInputBorder(
          borderRadius: FpRadius.tileAll,
          borderSide: FpBorders.hairline,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: FpRadius.tileAll,
          borderSide: FpBorders.hairline,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: FpRadius.tileAll,
          borderSide: BorderSide(color: FpColors.forest, width: 1.6),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: FpRadius.tileAll,
          borderSide: BorderSide(color: FpColors.severe),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : FpColors.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? FpColors.forest
              : FpColors.outline,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: FpColors.forest,
        inactiveTrackColor: FpColors.forestTint,
        thumbColor: FpColors.forest,
        overlayColor: Color(0x1A24501C),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: FpColors.surfaceAlt,
        selectedColor: FpColors.forestTint,
        labelStyle: FpTypography.label,
        side: FpBorders.hairline,
        shape: const RoundedRectangleBorder(borderRadius: FpRadius.pillAll),
        padding: const EdgeInsets.symmetric(
          horizontal: FpSpace.sm,
          vertical: FpSpace.xxs,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: FpColors.canvas,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(FpRadius.sheet),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: FpColors.graphite,
        contentTextStyle: FpTypography.bodyStrong.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: FpRadius.tileAll),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: overlayStyle,
        titleTextStyle: FpTypography.title,
        iconTheme: IconThemeData(color: FpColors.graphite),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        },
      ),
    );
  }
}
