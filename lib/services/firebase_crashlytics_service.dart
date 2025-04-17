import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'dart:isolate';
import 'dart:ui';

/// Servicio centralizado para gestionar errores con Firebase Crashlytics
///
/// Proporciona métodos para inicializar Crashlytics, registrar errores
/// y establecer información de usuario para facilitar la depuración.
class FirebaseCrashlyticsService {
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  // Puerto para errores de Isolate
  static const String _isolateErrorPortName = 'crash-reporting';
  ReceivePort? _isolateErrorPort;

  /// Constructor
  FirebaseCrashlyticsService() {
    _initCrashlytics();
  }

  /// Inicializa Crashlytics y configura captura de errores
  Future<void> _initCrashlytics() async {
    try {
      // En modo debug, desactivar reporte automático
      await _crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

      // Capturar errores de Flutter
      FlutterError.onError = _crashlytics.recordFlutterFatalError;

      // Capturar errores en isolates
      _isolateErrorPort = ReceivePort();
      IsolateNameServer.registerPortWithName(
        _isolateErrorPort!.sendPort,
        _isolateErrorPortName,
      );

      _isolateErrorPort!.listen((dynamic error) {
        _crashlytics.recordError(
          error['exception'],
          error['stack'],
          fatal: error['fatal'] ?? false,
          reason: error['reason'],
        );
      });

      // Registrar información de la app
      await _crashlytics.setCustomKey(
          'app_mode', kDebugMode ? 'debug' : 'release');

      debugPrint('Crashlytics inicializado correctamente');
    } catch (e) {
      debugPrint('Error al inicializar Crashlytics: $e');
    }
  }

  /// Registra un error no fatal en Crashlytics
  void recordError(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
    Iterable<Object> information = const [],
    bool fatal = false,
  }) {
    try {
      _crashlytics.recordError(
        exception,
        stack,
        reason: reason,
        information: information,
        fatal: fatal,
      );
    } catch (e) {
      debugPrint('Error al registrar error en Crashlytics: $e');
    }
  }

  /// Registra un mensaje informativo en Crashlytics
  void log(String message) {
    try {
      _crashlytics.log(message);
    } catch (e) {
      debugPrint('Error al registrar log en Crashlytics: $e');
    }
  }

  /// Establece el identificador de usuario para contextualizar errores
  Future<void> setUserIdentifier(String userId) async {
    try {
      await _crashlytics.setUserIdentifier(userId);
    } catch (e) {
      debugPrint('Error al establecer identificador de usuario: $e');
    }
  }

  /// Establece datos personalizados del usuario
  Future<void> setUserData({
    required String userId,
    required String email,
    required bool isPremium,
    String? subscriptionPlan,
  }) async {
    try {
      await _crashlytics.setUserIdentifier(userId);
      await _crashlytics.setCustomKey('email', email);
      await _crashlytics.setCustomKey('isPremium', isPremium);

      if (isPremium && subscriptionPlan != null) {
        await _crashlytics.setCustomKey('subscriptionPlan', subscriptionPlan);
      }
    } catch (e) {
      debugPrint('Error al establecer datos de usuario: $e');
    }
  }

  /// Limpia los datos de usuario
  Future<void> clearUserData() async {
    try {
      await _crashlytics.setUserIdentifier('');
      await _crashlytics.setCustomKey('email', '');
      await _crashlytics.setCustomKey('isPremium', false);
      await _crashlytics.setCustomKey('subscriptionPlan', '');
    } catch (e) {
      debugPrint('Error al limpiar datos de usuario: $e');
    }
  }

  /// Fuerza un crash para pruebas (solo en modo debug)
  void forceCrash() {
    if (kDebugMode) {
      _crashlytics.crash();
    }
  }

  /// Libera recursos
  void dispose() {
    if (_isolateErrorPort != null) {
      IsolateNameServer.removePortNameMapping(_isolateErrorPortName);
      _isolateErrorPort!.close();
    }
  }
}
