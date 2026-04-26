import 'package:flutter/material.dart';

/// Gradiente e painéis usados na dashboard — reutilizar em todas as telas para identidade única.
abstract final class AppGradients {
  static const LinearGradient screenBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.lightBlue, AppColors.white],
    stops: [0.0, 0.4],
  );
}

/// Espaçamentos horizontais/verticais padrão (lista principal da dashboard).
abstract final class AppLayout {
  static const double screenPaddingH = 24;
  static const double screenPaddingTop = 16;
  static const double screenPaddingBottom = 24;

  static const EdgeInsets screenPadding = EdgeInsets.fromLTRB(
    screenPaddingH,
    screenPaddingTop,
    screenPaddingH,
    screenPaddingBottom,
  );

  static const EdgeInsets screenPaddingSymmetricH = EdgeInsets.symmetric(horizontal: screenPaddingH);
}

/// Superfície branca elevada (cards de conteúdo sobre o gradiente).
abstract final class AppDecor {
  static BoxDecoration whiteTopSheet({double radius = 26}) => BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(radius), topRight: Radius.circular(radius)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.06),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      );
}

class AppColors {
  static const primaryBlue = Color(0xFF1F2A8A);
  static const lightBlue = Color(0xFFE8F1FF);
  static const accentOrange = Color(0xFFFF8A3D);
  static const white = Color(0xFFFFFFFF);
  static const neutralGray = Color(0xFF6B7280);
  static const mediumGray = Color(0xFFD1D5DB);
  static const darkGray = Color(0xFF1F2937);
  static const errorRed = Colors.red;

  // Aliases for backward compatibility in existing screens.
  static const blue = primaryBlue;
  static const orange = accentOrange;
  static const lightGray = Color(0xFFF5F8FF);
  static const green = Color(0xFF10B981);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.white,
      fontFamily: 'Arial',
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryBlue,
        secondary: AppColors.accentOrange,
        error: AppColors.errorRed,
        surface: AppColors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBlue,
        foregroundColor: AppColors.primaryBlue,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Arial',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryBlue,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.mediumGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.mediumGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.6),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primaryBlue, height: 1.2),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primaryBlue, height: 1.2),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryBlue, height: 1.2),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.darkGray, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.darkGray, height: 1.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          backgroundColor: AppColors.accentOrange,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accentOrange,
        foregroundColor: AppColors.white,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.darkGray,
        contentTextStyle: const TextStyle(color: AppColors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: AppColors.accentOrange,
        labelColor: AppColors.primaryBlue,
        unselectedLabelColor: AppColors.neutralGray,
      ),
    );
  }
}
