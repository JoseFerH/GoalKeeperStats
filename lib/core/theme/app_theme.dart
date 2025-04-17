import 'package:flutter/material.dart';

/// Clase que define los temas y estilos visuales de la aplicación
/// con mejoras específicas para los componentes problemáticos
class AppTheme {
  // Colores principales ligeramente refinados
  static const Color primaryColor = Color(0xFF184621);
  static const Color secondaryColor = Color(0xFF3D8331);
  static const Color accentColor = Color(0xFF73A832);

  // Colores específicos para el modo oscuro
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCardColor = Color(0xFF252525);

  // Colores para función premium
  static const Color premiumColor = Color(0xFFFFB300);
  static const Color premiumDarkColor = Color(0xFFFFD54F);

  // Colores de texto con mayor contraste
  static const Color darkTextColor = Color(0xFF121212);
  static const Color lightTextColor = Color(0xFFF9F9F9);
  static const Color mediumTextDark =
      Color(0xFFBDBDBD); // Para textos secundarios en modo oscuro
  static const Color mediumTextLight =
      Color(0xFF616161); // Para textos secundarios en modo claro

  // Colores específicos para elementos seleccionados/no seleccionados
  static const Color selectedGreen = Color(0xFF4CAF50);
  static const Color selectedTextDark = Color(0xFFE8F5E9);
  static const Color unselectedDark = Color(0xFF424242);
  static const Color unselectedTextDark = Color(0xFFE0E0E0);

  // Colores de error y éxito
  static const Color errorColor =
      Color(0xFFB00020); // Color de error para tema claro
  static const Color errorColorDark =
      Color(0xFFE57373); // Color de error para tema oscuro
  static const Color successColor = Color(0xFF4CAF50); // Color de éxito

  // TEMA CLARO
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      onPrimary: Colors.white,
      secondary: secondaryColor,
      onSecondary: Colors.white,
      tertiary: accentColor,
      onTertiary: Colors.white,
      background: Colors.white,
      onBackground: darkTextColor,
      surface: Colors.white,
      onSurface: darkTextColor,
      surfaceVariant: const Color(0xFFF5F5F5),
      onSurfaceVariant: mediumTextLight,
      error: errorColor, // Usando la constante definida
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: Colors.white,

    // Resto del tema claro similar al anterior
  );

  // TEMA OSCURO
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.dark(
      primary:
          const Color(0xFF9EDE53), // Verde más brillante para mejor contraste
      onPrimary: Colors.black,
      secondary: const Color(0xFF66BB6A),
      onSecondary: Colors.black,
      tertiary: const Color(0xFFAED581),
      onTertiary: Colors.black,

      // Superficies y fondos
      background: darkBackground,
      onBackground: lightTextColor,
      surface: darkSurface,
      onSurface: lightTextColor,
      surfaceVariant: darkCardColor,
      onSurfaceVariant: mediumTextDark,

      // Error con mejor contraste
      error: errorColorDark, // Usando la constante específica para modo oscuro
      onError: Colors.black,
    ),
    scaffoldBackgroundColor: darkBackground,

    appBarTheme: AppBarTheme(
      backgroundColor: darkSurface,
      foregroundColor: lightTextColor,
      elevation: 0,
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: darkSurface,
      selectedItemColor: const Color(0xFF9EDE53),
      unselectedItemColor:
          const Color(0xFFBDBDBD), // Gris más claro para mejor contraste
      type: BottomNavigationBarType.fixed,
    ),

    // Botones mejorados
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF9EDE53),
        foregroundColor: Colors.black,
        minimumSize: const Size(120, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor:
            const Color(0xFFE0E0E0), // Gris muy claro para contraste
        side: const BorderSide(color: Color(0xFFBDBDBD), width: 1.5),
        minimumSize: const Size(120, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),

    // Tarjetas mejoradas
    cardTheme: CardTheme(
      color: darkCardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),

    // Chip theme para botones de selección
    chipTheme: ChipThemeData(
      backgroundColor: darkCardColor,
      disabledColor: darkSurface,
      selectedColor: const Color(0xFF388E3C),
      secondarySelectedColor: const Color(0xFF388E3C),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      labelStyle: TextStyle(color: mediumTextDark),
      secondaryLabelStyle: const TextStyle(color: Colors.white),
      brightness: Brightness.dark,
    ),

    // Estilo para campos de texto
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkCardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      hintStyle: TextStyle(color: mediumTextDark.withOpacity(0.7)),
      labelStyle: TextStyle(color: mediumTextDark),
    ),

    // Estilo para texto
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFFE0E0E0)),
      bodyMedium: TextStyle(color: Color(0xFFE0E0E0)),
      bodySmall: TextStyle(color: Color(0xFFBDBDBD)),
      labelLarge: TextStyle(color: Color(0xFFE0E0E0)),
      labelMedium: TextStyle(color: Color(0xFFE0E0E0)),
      labelSmall: TextStyle(color: Color(0xFFBDBDBD)),
    ),
  );

  /// Estilos específicos para elementos premium
  static BoxDecoration premiumCardDecoration(bool isDarkMode) {
    return BoxDecoration(
      color: isDarkMode
          ? const Color(0xFF423000).withOpacity(0.7) // Fondo amarillo oscuro
          : const Color(0xFFFFF8E1), // Fondo amarillo claro
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isDarkMode ? const Color(0xFFFFD54F) : const Color(0xFFFFB300),
        width: 1,
      ),
    );
  }

  /// Estilos para botones "Actualizar a Premium"
  static ButtonStyle premiumButtonStyle(bool isDarkMode) {
    return ElevatedButton.styleFrom(
      backgroundColor:
          isDarkMode ? const Color(0xFFFFB300) : const Color(0xFFFF9800),
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      textStyle: const TextStyle(fontWeight: FontWeight.bold),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    );
  }

  /// Estilos para botones de selección de tipo (como en pantalla de tiros)
  static ButtonStyle selectionButtonStyle({
    required bool isDarkMode,
    required bool isSelected,
  }) {
    return OutlinedButton.styleFrom(
      backgroundColor: isSelected
          ? (isDarkMode ? const Color(0xFF2E7D32) : const Color(0xFFE8F5E9))
          : (isDarkMode ? const Color(0xFF424242) : Colors.white),
      foregroundColor: isSelected
          ? (isDarkMode ? Colors.white : const Color(0xFF2E7D32))
          : (isDarkMode ? const Color(0xFFE0E0E0) : const Color(0xFF757575)),
      side: BorderSide(
        color: isSelected
            ? (isDarkMode ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32))
            : (isDarkMode ? const Color(0xFF757575) : const Color(0xFFBDBDBD)),
        width: 1.5,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      minimumSize: const Size(120, 48),
    );
  }

  /// Estilo para mensajes de error
  static TextStyle errorTextStyle(bool isDarkMode) {
    return TextStyle(
      color: isDarkMode ? errorColorDark : errorColor,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
  }
}
