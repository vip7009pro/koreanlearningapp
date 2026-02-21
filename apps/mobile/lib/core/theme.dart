import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const primary = Color(0xFF2563EB);
  static const secondary = Color(0xFF7C3AED);
  static const accent = Color(0xFFF59E0B);
  static const success = Color(0xFF10B981);
  static const error = Color(0xFFEF4444);
  static const surface = Color(0xFFF8FAFC);
  static const darkSurface = Color(0xFF0F172A);
  static const darkCard = Color(0xFF1E293B);
  static const darkText = Color(0xFFE2E8F0);
  static const darkTextSecondary = Color(0xFF94A3B8);

  static ThemeData lightThemeForSeed(Color seedColor) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.interTextTheme(),
        scaffoldBackgroundColor: surface,
        appBarTheme: AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.grey[900],
          titleTextStyle: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey[900],
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: seedColor,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle:
                GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );

  static ThemeData get lightTheme => lightThemeForSeed(primary);

  static ThemeData darkThemeForSeed(Color seedColor) => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
          surface: darkSurface,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
          bodyColor: darkText,
          displayColor: darkText,
        ),
        scaffoldBackgroundColor: darkSurface,
        appBarTheme: AppBarTheme(
          elevation: 0,
          backgroundColor: darkCard,
          foregroundColor: darkText,
          titleTextStyle: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: darkText,
          ),
          iconTheme: const IconThemeData(color: darkText),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: darkCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF334155)),
          ),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: darkCard,
          titleTextStyle: TextStyle(
            color: darkText,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          contentTextStyle: TextStyle(color: darkTextSecondary, fontSize: 14),
        ),
        listTileTheme: const ListTileThemeData(
          textColor: darkText,
          iconColor: darkTextSecondary,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: darkCard,
          selectedItemColor: primary,
          unselectedItemColor: darkTextSecondary,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF334155),
          contentTextStyle: const TextStyle(color: darkText),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: darkCard,
          selectedColor: seedColor.withValues(alpha: 0.3),
          labelStyle: const TextStyle(color: darkText),
          secondaryLabelStyle: const TextStyle(color: darkText),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: seedColor,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle:
                GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: darkText,
            side: const BorderSide(color: Color(0xFF475569)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF60A5FA),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF334155),
          hintStyle: const TextStyle(color: darkTextSecondary),
          labelStyle: const TextStyle(color: darkText),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF475569)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: seedColor, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF334155),
        ),
        iconTheme: const IconThemeData(color: darkTextSecondary),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          linearTrackColor: Color(0xFF334155),
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: darkText,
          unselectedLabelColor: darkTextSecondary,
          indicatorColor: primary,
        ),
      );

  static ThemeData get darkTheme => darkThemeForSeed(primary);
}
