import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Colors ──
  static const Color bgDark = Color(0xFF0F0A06);
  static const Color surfaceGlass = Color(0xFF1C1109);
  static const Color primaryGold = Color(0xFFF59E0B);
  static const Color secondaryOrange = Color(0xFFF97316);
  static const Color accentRed = Color(0xFFFB7185);
  static const Color textPrimary = Color(0xFFFDF4E7);
  static const Color textMuted = Color(0xFFC4A882);
  static const Color textDarkMuted = Color(0xFF7A6347);
  
  // Status Colors
  static const Color statusApproved = Color(0xFF34D399);
  static const Color statusRejected = Color(0xFFF87171);
  static const Color statusFlagged = Color(0xFFFCA5A5);
  static const Color statusAiProcessing = Color(0xFFC084FC);
  static const Color statusPending = Color(0xFFFBBF24);

  // ── Gradients ──
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryGold, secondaryOrange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradientLine = LinearGradient(
    colors: [primaryGold, secondaryOrange, accentRed],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const RadialGradient bgGlow = RadialGradient(
    center: Alignment(-0.5, -0.3),
    radius: 1.5,
    colors: [
      Color(0x1FF59E0B),
      Colors.transparent,
    ],
  );

  // ── Box Shadows ──
  static const List<BoxShadow> glassShadow = [
    BoxShadow(color: Color(0x14F59E0B), blurRadius: 80, spreadRadius: 0),
    BoxShadow(color: Colors.black54, blurRadius: 28, offset: Offset(0, 4)),
  ];
  
  static const List<BoxShadow> buttonGlow = [
    BoxShadow(color: Color(0x33F59E0B), blurRadius: 22, offset: Offset(0, 4)),
  ];

  // ── ThemeData ──
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      primaryColor: primaryGold,
      colorScheme: const ColorScheme.dark(
        primary: primaryGold,
        secondary: secondaryOrange,
        surface: surfaceGlass,
        error: statusRejected,
      ),
      cardTheme: CardTheme(
        color: surfaceGlass,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0x2EF59E0B)),
        ),
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceGlass,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textMuted),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent, // Gradient applied in Container
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      useMaterial3: true,
    );
  }
}
