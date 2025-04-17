import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gestor de temas para toda la aplicación
class ThemeManager extends ChangeNotifier {
  // Clave para guardar preferencia en SharedPreferences
  static const String _themeKey = "dark_mode";

  // Instancia singleton
  static ThemeManager? _instance;
  SharedPreferences? _prefs;

  // Modo oscuro habilitado o no
  bool _darkMode = false;

  // Constructor privado
  ThemeManager._() {
    _loadFromPrefs();
  }

  // Método para obtener la instancia singleton
  static ThemeManager getInstance() {
    _instance ??= ThemeManager._();
    return _instance!;
  }

  // Getters
  bool get darkMode => _darkMode;
  ThemeMode get themeMode => _darkMode ? ThemeMode.dark : ThemeMode.light;

  // Método para esperar a que las preferencias estén cargadas
  Future<void> waitForSettings() async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
      _darkMode = _prefs!.getBool(_themeKey) ?? false;
      notifyListeners();
    }
  }

  // Cambiar entre temas
  void toggleDarkMode() {
    setDarkMode(!_darkMode);
  }

  // Establecer modo oscuro
  void setDarkMode(bool value) {
    if (_darkMode != value) {
      _darkMode = value;
      _saveToPrefs();
      notifyListeners();
      debugPrint('ThemeManager: Tema cambiado a darkMode = $_darkMode');
    }
  }

  // Cargar preferencias guardadas
  Future<void> _loadFromPrefs() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _darkMode = _prefs!.getBool(_themeKey) ?? false;
      notifyListeners();
      debugPrint('ThemeManager: Tema cargado, darkMode = $_darkMode');
    } catch (e) {
      debugPrint('ThemeManager: Error al cargar preferencias: $e');
    }
  }

  // Guardar preferencias
  Future<void> _saveToPrefs() async {
    try {
      if (_prefs == null) {
        _prefs = await SharedPreferences.getInstance();
      }
      await _prefs!.setBool(_themeKey, _darkMode);
      debugPrint('ThemeManager: Tema guardado, darkMode = $_darkMode');
    } catch (e) {
      debugPrint('ThemeManager: Error al guardar preferencias: $e');
    }
  }
}
