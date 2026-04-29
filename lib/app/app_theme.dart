import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Palette ────────────────────────────────────────────────────────────────
  static const Color primary       = Color(0xFF00C896); // emerald green
  static const Color primaryDark   = Color(0xFF00A37A);
  static const Color accent        = Color(0xFFFFD166); // warm gold
  static const Color surface       = Color(0xFF1A1F2E); // dark blue-grey card
  static const Color background    = Color(0xFF0F1320); // deep navy
  static const Color surfaceLight  = Color(0xFFF7FAF9);
  static const Color backgroundLight = Color(0xFFF0F4F2);

  // Gradient stops
  static const List<Color> brandGradient = [
    Color(0xFF00C896),
    Color(0xFF00A3FF),
  ];
  static const List<Color> cardGradient = [
    Color(0xFF1E2535),
    Color(0xFF161B28),
  ];

  // ── Dark theme (primary) ───────────────────────────────────────────────────
  static ThemeData darkTheme() {
    final base = ColorScheme.dark(
      primary:          primary,
      onPrimary:        Colors.white,
      secondary:        accent,
      onSecondary:      const Color(0xFF1A1F2E),
      surface:          surface,
      onSurface:        Colors.white,
      surfaceContainerHighest: const Color(0xFF222840),
      outline:          Colors.white.withOpacity(0.12),
      onSurfaceVariant: Colors.white.withOpacity(0.55),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: background,
      textTheme: _textTheme(Colors.white),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.06), width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E2535),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.10), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
        prefixIconColor: Colors.white.withOpacity(0.4),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF1E2535),
        selectedColor: primary.withOpacity(0.2),
        labelStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
        side: BorderSide(color: Colors.white.withOpacity(0.10)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF141928),
        selectedItemColor: primary,
        unselectedItemColor: Colors.white.withOpacity(0.35),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withOpacity(0.08),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1E2535),
        contentTextStyle: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xFF1E2535),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1A1F2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: GoogleFonts.poppins(
          color: Colors.white70,
          fontSize: 14,
        ),
      ),
    );
  }

  // ── Light theme ────────────────────────────────────────────────────────────
  static ThemeData lightTheme() {
    const dark = Color(0xFF0F1320);
    final base = ColorScheme.light(
      primary:          primary,
      onPrimary:        Colors.white,
      secondary:        accent,
      surface:          Colors.white,
      onSurface:        dark,
      surfaceContainerHighest: const Color(0xFFF0F4F8),
      outline:          Colors.black.withOpacity(0.08),
      onSurfaceVariant: Colors.black54,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: backgroundLight,
      textTheme: _textTheme(dark),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: dark,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.poppins(
          color: dark,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.black.withOpacity(0.06), width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        labelStyle: const TextStyle(color: Colors.black54, fontSize: 14),
        prefixIconColor: Colors.black38,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF0F4F8),
        selectedColor: primary.withOpacity(0.15),
        labelStyle: GoogleFonts.poppins(fontSize: 12, color: dark),
        side: BorderSide(color: Colors.black.withOpacity(0.08)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primary,
        unselectedItemColor: Colors.black38,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark,
        contentTextStyle: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          color: dark,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: GoogleFonts.poppins(color: Colors.black54, fontSize: 14),
      ),
    );
  }

  // ── Shared text theme ──────────────────────────────────────────────────────
  static TextTheme _textTheme(Color base) => TextTheme(
        displayLarge:  GoogleFonts.poppins(color: base, fontWeight: FontWeight.w800, letterSpacing: -1.5),
        displayMedium: GoogleFonts.poppins(color: base, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        displaySmall:  GoogleFonts.poppins(color: base, fontWeight: FontWeight.w700),
        headlineLarge: GoogleFonts.poppins(color: base, fontWeight: FontWeight.w700),
        headlineMedium:GoogleFonts.poppins(color: base, fontWeight: FontWeight.w700),
        headlineSmall: GoogleFonts.poppins(color: base, fontWeight: FontWeight.w700, fontSize: 22),
        titleLarge:    GoogleFonts.poppins(color: base, fontWeight: FontWeight.w600, fontSize: 18),
        titleMedium:   GoogleFonts.poppins(color: base, fontWeight: FontWeight.w600, fontSize: 16),
        titleSmall:    GoogleFonts.poppins(color: base, fontWeight: FontWeight.w500, fontSize: 14),
        bodyLarge:     GoogleFonts.poppins(color: base, fontSize: 16),
        bodyMedium:    GoogleFonts.poppins(color: base, fontSize: 14),
        bodySmall:     GoogleFonts.poppins(color: base.withOpacity(0.6), fontSize: 12),
        labelLarge:    GoogleFonts.poppins(color: base, fontWeight: FontWeight.w600, fontSize: 14),
        labelMedium:   GoogleFonts.poppins(color: base, fontWeight: FontWeight.w500, fontSize: 12),
        labelSmall:    GoogleFonts.poppins(color: base.withOpacity(0.5), fontSize: 11),
      );

  // ── Gradient helpers ───────────────────────────────────────────────────────
  static LinearGradient get primaryGradient => const LinearGradient(
        colors: brandGradient,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static BoxDecoration gradientCard({double radius = 20}) => BoxDecoration(
        gradient: const LinearGradient(
          colors: cardGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
      );
}
