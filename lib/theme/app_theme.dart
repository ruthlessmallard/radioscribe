import 'package:flutter/material.dart';

class AppColors {
  // CAT Yellow
  static const Color catYellow = Color(0xFFFFCD11);
  // Snap-on Red
  static const Color snaponRed = Color(0xFFED1C24);
  // Background
  static const Color background = Color(0xFF121212);
  // Surface (slightly lighter)
  static const Color surface = Color(0xFF1E1E1E);
  // Normal text
  static const Color textNormal = Colors.white;
  // Faded text (low confidence)
  static const Color textFaded = Color(0xFF888888);
  // Grey accent
  static const Color grey = Color(0xFF3A3A3A);
  static const Color greyLight = Color(0xFF666666);
}

class AppTheme {
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.catYellow,
          secondary: AppColors.snaponRed,
          surface: AppColors.surface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.catYellow,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: AppColors.catYellow,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: AppColors.textNormal, fontSize: 16),
          bodyMedium: TextStyle(color: AppColors.textNormal, fontSize: 14),
          titleLarge: TextStyle(
            color: AppColors.catYellow,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catYellow,
            foregroundColor: Colors.black,
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 1.0,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        dividerColor: AppColors.grey,
      );
}
