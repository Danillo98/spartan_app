import 'package:flutter/material.dart';

class AppTheme {
  // Cores principais - Tema Claro com Dourado

  // Preto (substituindo Dourado conforme pedido)
  static const Color primaryGold = Color(0xFF1A1A1A); // Preto principal
  static const Color accentGold = Color(0xFF000000); // Preto puro
  static const Color darkGold = Color(0xFF333333); // Cinza chumbo

  // Vermelho (acento)
  static const Color primaryRed = Color(0xFF8B0000); // Vermelho escuro
  static const Color accentRed = Color(0xFFDC143C); // Vermelho crimson

  // Tema Claro - Branco e Cinza Claro
  static const Color white = Color(0xFFFFFFFF); // Branco puro
  static const Color offWhite = Color(0xFFFAFAFA); // Branco suave
  static const Color lightGrey = Color(0xFFF5F5F5); // Cinza muito claro
  static const Color mediumGrey = Color(0xFFE8E8E8); // Cinza claro
  static const Color borderGrey = Color(0xFFD0D0D0); // Cinza para bordas

  // Textos
  static const Color primaryText = Color(0xFF1A1A1A); // Preto suave
  static const Color secondaryText = Color(0xFF666666); // Cinza escuro
  static const Color hintText = Color(0xFF999999); // Cinza médio

  // Cores complementares
  static const Color success = Color(0xFF06D6A0); // Verde
  static const Color info = Color(0xFF118AB2); // Azul

  // Gradientes
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryGold, darkGold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldShineGradient = LinearGradient(
    colors: [accentGold, primaryGold, darkGold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient lightGradient = LinearGradient(
    colors: [white, offWhite],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFFAFAFA), Color(0xFFF5F5F5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Sombras
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> goldGlowShadow = [
    BoxShadow(
      color: primaryGold.withOpacity(0.3),
      blurRadius: 20,
      spreadRadius: 2,
    ),
  ];

  static List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: primaryGold.withOpacity(0.25),
      blurRadius: 15,
      offset: const Offset(0, 6),
    ),
  ];

  // Border Radius
  static BorderRadius cardRadius = BorderRadius.circular(16);
  static BorderRadius buttonRadius = BorderRadius.circular(12);
  static BorderRadius inputRadius = BorderRadius.circular(10);

  // Tema do App
  static ThemeData get theme {
    return ThemeData(
      primaryColor: primaryGold,
      scaffoldBackgroundColor: white,
      colorScheme: const ColorScheme.light(
        primary: primaryGold,
        secondary: accentGold,
        surface: lightGrey,
        background: white,
        error: accentRed,
        onPrimary: white,
        onSecondary: primaryText,
        onSurface: primaryText,
        onBackground: primaryText,
      ),
      fontFamily: 'Lato',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: primaryText,
        ),
        displayMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: primaryText,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: primaryText,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: secondaryText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGold,
          foregroundColor: white,
          elevation: 4,
          shadowColor: primaryGold.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: buttonRadius,
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightGrey,
        border: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: borderGrey, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: const BorderSide(color: primaryGold, width: 2),
        ),
        labelStyle: const TextStyle(color: secondaryText),
        hintStyle: const TextStyle(color: hintText),
        prefixIconColor: primaryGold,
        suffixIconColor: primaryGold,
      ),
      cardTheme: CardTheme(
        color: white,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.08),
        shape: RoundedRectangleBorder(
          borderRadius: cardRadius,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: white,
        foregroundColor: primaryText,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}
