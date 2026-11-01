import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── PREMIUM COLOR MIXING ──
  static const Color jadeDark = Color(0xFF0F766E); // Deep Teal
  static const Color jadeLight = Color(0xFF3EB489); // Vibrant Jade
  
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [jadeDark, jadeLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── PRISTINE LIGHT MODE ──
  static const Color lightBg = Color(0xFFF9FAFB); // Ultra-clean off-white
  static const Color lightCard = Colors.white;
  static const Color lightText = Colors.black87;
  static const Color lightBorder = Color(0xFFF3F4F6);

  // ── GRAPHITE DARK MODE (Neutral Black) ──
  static const Color darkBg = Color(0xFF121212); // Sleek Graphite Black
  static const Color darkCard = Color(0xFF1E1E1E); // Slightly elevated for cards
  static const Color darkText = Colors.white;
  static const Color darkBorder = Color(0xFF2C2C2C); // Subtle dividing lines

  // ════════════════════════════════════════════════════════════
  // ── LIGHT THEME ──
  // ════════════════════════════════════════════════════════════
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: jadeLight,
      scaffoldBackgroundColor: lightBg,
      
      textTheme: GoogleFonts.spaceGroteskTextTheme().apply(
        bodyColor: lightText, displayColor: lightText,
      ),
      
      colorScheme: const ColorScheme.light(
        primary: jadeLight, surface: lightBg, error: Colors.redAccent,
      ),
      
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: lightText),
      ),

      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightBorder),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // ── DARK THEME ──
  // ════════════════════════════════════════════════════════════
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: jadeLight,
      scaffoldBackgroundColor: darkBg,
      
      textTheme: GoogleFonts.spaceGroteskTextTheme().apply(
        bodyColor: darkText, displayColor: darkText,
      ),
      
      colorScheme: const ColorScheme.dark(
        primary: jadeLight, surface: darkBg, error: Colors.redAccent,
      ),
      
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: darkText),
      ),

      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder),
        ),
      ),
    );
  }
}