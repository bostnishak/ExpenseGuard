import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const ExpenseGuardApp());
}

class ExpenseGuardApp extends StatelessWidget {
  const ExpenseGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ExpenseGuard Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0A06), // bg
        primaryColor: const Color(0xFFF59E0B), // gold
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF59E0B), // gold
          secondary: Color(0xFFF97316), // orange
          surface: Color(0xFF1C1109), // bg3
          error: Color(0xFFF87171), // red
        ),
        cardTheme: const CardTheme(
          color: Color(0xFF1C1109),
        ),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme).apply(
          bodyColor: const Color(0xFFFDF4E7), // text
          displayColor: const Color(0xFFFDF4E7), // text
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1C1109),
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Color(0xFFC4A882)), // text2
          titleTextStyle: TextStyle(
            color: Color(0xFFFDF4E7),
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
