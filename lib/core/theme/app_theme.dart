import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palet warna terinspirasi Kraton Surakarta & jajanan Serabi Solo:
/// hijau tua (pakubuwono green) + emas (prada gold) + krem (adonan serabi)
class AppColors {
  static const kratonGreen = Color(0xFF1F4B36);   // hijau tua kraton
  static const kratonGreenLight = Color(0xFF2E6B4E);
  static const pradaGold = Color(0xFFC9A227);      // emas prada
  static const pradaGoldLight = Color(0xFFE8C766);
  static const serabiCream = Color(0xFFFBF3E3);    // krem adonan serabi
  static const santanWhite = Color(0xFFFFFDF8);
  static const dapurRed = Color(0xFFB3402A);       // aksen status/alert
  static const textDark = Color(0xFF2A2A22);
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.serabiCream,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.kratonGreen,
        secondary: AppColors.pradaGold,
        surface: AppColors.santanWhite,
        error: AppColors.dapurRed,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textDark,
        displayColor: AppColors.textDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.kratonGreen,
        foregroundColor: AppColors.pradaGoldLight,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.kratonGreen,
          foregroundColor: AppColors.pradaGoldLight,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.santanWhite,
        elevation: 2,
        shadowColor: AppColors.kratonGreen.withOpacity(0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.pradaGold.withOpacity(0.25)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.santanWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.kratonGreen.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.pradaGold, width: 2),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.kratonGreen,
        selectedIconTheme: const IconThemeData(color: AppColors.pradaGold),
        unselectedIconTheme: IconThemeData(color: AppColors.santanWhite.withOpacity(0.6)),
        selectedLabelTextStyle: const TextStyle(color: AppColors.pradaGoldLight),
        unselectedLabelTextStyle: TextStyle(color: AppColors.santanWhite.withOpacity(0.6)),
      ),
    );
  }
}
