import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider para manejar el idioma de la aplicación
/// Soporta Español (es) e Inglés (en)
class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('es'); // Idioma por defecto: Español

  Locale get locale => _locale;

  LocaleProvider() {
    _loadLocale();
  }

  /// Cargar el idioma guardado desde SharedPreferences
  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString('language_code') ?? 'es';
      _locale = Locale(languageCode);
      notifyListeners();
    } catch (e) {
      debugPrint('Error cargando idioma: $e');
    }
  }

  /// Cambiar el idioma de la aplicación
  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;

    _locale = locale;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language_code', locale.languageCode);
      debugPrint('Idioma guardado: ${locale.languageCode}');
    } catch (e) {
      debugPrint('Error guardando idioma: $e');
    }
  }

  /// Obtener el idioma actual como String
  String get currentLanguageCode => _locale.languageCode;

  /// Verificar si está en español
  bool get isSpanish => _locale.languageCode == 'es';

  /// Verificar si está en inglés
  bool get isEnglish => _locale.languageCode == 'en';
}
