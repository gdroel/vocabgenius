import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const cream = Color(0xFFF2ECDF);
  static const creamSoft = Color(0xFFEDE6D6);
  static const ink = Color(0xFF1F1F1F);
  static const inkSoft = Color(0xFF3A3A3A);
  static const teal = Color(0xFF7A1F2B); // burgundy primary
  static const tealDark = Color(0xFF5C1620);
  static const burgundy = Color(0xFF7A1F2B);
  static const burgundyDeep = Color(0xFF5C1620);
  static const burgundySoft = Color(0xFFB85C68);
  static const outline = Color(0xFF1F1F1F);
  static const muted = Color(0xFF8A8275);
  static const card = Color(0xFFFFFFFF);
  static const accent = Color(0xFFE9D8A6);
  static const flame = Color(0xFFE85A2A);
  static const success = Color(0xFF4CAF7C);
}

// Neo-brutalist hard shadow + thick border
class Brutal {
  static const borderColor = AppColors.ink;
  static const borderWidth = 2.5;
  static List<BoxShadow> shadow({double dx = 4, double dy = 5}) => [
    BoxShadow(color: AppColors.ink, offset: Offset(dx, dy), blurRadius: 0),
  ];
}

String get appFontFamily => GoogleFonts.fraunces().fontFamily!;

TextStyle appText({
  double size = 16,
  FontWeight weight = FontWeight.w500,
  Color color = AppColors.ink,
  double? height,
}) {
  return GoogleFonts.fraunces(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );
}

ThemeData buildOnboardingTheme() {
  final base = GoogleFonts.frauncesTextTheme();
  return ThemeData(
    useMaterial3: true,
    fontFamily: appFontFamily,
    scaffoldBackgroundColor: AppColors.cream,
    colorScheme: const ColorScheme.light(
      primary: AppColors.teal,
      onPrimary: AppColors.ink,
      surface: AppColors.cream,
      onSurface: AppColors.ink,
    ),
    textTheme: base
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink)
        .copyWith(
          displayLarge: appText(size: 42, weight: FontWeight.w800, height: 1.1),
          headlineMedium: appText(
            size: 34,
            weight: FontWeight.w800,
            height: 1.15,
          ),
          titleLarge: appText(size: 24, weight: FontWeight.w700),
          bodyLarge: appText(size: 16, weight: FontWeight.w500, height: 1.4),
          bodyMedium: appText(
            size: 16,
            weight: FontWeight.w500,
            color: AppColors.inkSoft,
          ),
          labelLarge: appText(size: 18, weight: FontWeight.w700),
        ),
  );
}
