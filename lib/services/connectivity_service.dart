import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Servicio para monitorear el estado de la conexión a internet
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<ConnectivityResult> _subscription;

  // Controlador para transmitir cambios de conectividad
  final _connectivityController =
      StreamController<ConnectivityResult>.broadcast();

  // Estado actual de conectividad
  ConnectivityResult _lastResult = ConnectivityResult.none;
  bool _isInitialized = false;

  /// Constructor
  ConnectivityService() {
    _init();
  }

  /// Stream que emite cambios de conectividad
  Stream<ConnectivityResult> get onConnectivityChanged =>
      _connectivityController.stream;

  /// Estado actual de conectividad
  ConnectivityResult get currentConnectivity => _lastResult;

  /// Indica si el dispositivo tiene conexión a internet
  bool get isConnected =>
      _lastResult == ConnectivityResult.wifi ||
      _lastResult == ConnectivityResult.mobile ||
      _lastResult == ConnectivityResult.ethernet;

  /// Inicializar el servicio
  Future<void> _init() async {
    if (_isInitialized) return;

    try {
      // Obtener estado inicial
      _lastResult = await _connectivity.checkConnectivity();

      // Suscribirse a cambios
      _subscription = _connectivity.onConnectivityChanged.listen((result) {
        _lastResult = result;
        _connectivityController.add(result);

        // 🔧 CORREGIDO: Registrar cambio en Crashlytics con valor string
        _recordConnectivityChange(result);
      });

      _isInitialized = true;
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al inicializar ConnectivityService');
      debugPrint('Error al inicializar ConnectivityService: $e');
    }
  }

  /// 🔧 NUEVO: Método para registrar cambios de conectividad de forma segura
  void _recordConnectivityChange(ConnectivityResult result) {
    try {
      // Registrar en Crashlytics con string en lugar de boolean
      FirebaseCrashlytics.instance.setCustomKey('network_connectivity',
          result.toString() // 🔧 Usar toString() en lugar del enum directo
          );

      // También registrar si está conectado como string
      FirebaseCrashlytics.instance.setCustomKey('is_connected',
          isConnected.toString() // 🔧 Convertir boolean a string
          );

      debugPrint(
          '📶 Conectividad cambió a: ${result.toString()} (conectado: $isConnected)');
    } catch (e) {
      debugPrint('❌ Error registrando cambio de conectividad: $e');
    }
  }

  /// Verificar la conectividad actual
  Future<bool> checkConnectivity() async {
    try {
      _lastResult = await _connectivity.checkConnectivity();
      return isConnected;
    } catch (e) {
      debugPrint('Error al verificar conectividad: $e');
      return false;
    }
  }

  /// Mostrar un snackbar informativo sobre el estado de la conexión
  void showConnectivitySnackBar(BuildContext context) {
    String message;
    Color backgroundColor;

    if (isConnected) {
      message = 'Conexión a internet restablecida';
      backgroundColor = Colors.green;
    } else {
      message =
          'Sin conexión a internet. Algunas funciones podrían no estar disponibles';
      backgroundColor = Colors.red;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 🔧 NUEVO: Método para obtener información detallada de conectividad
  Map<String, String> getConnectivityInfo() {
    return {
      'status': _lastResult.toString(),
      'is_connected': isConnected.toString(),
      'is_initialized': _isInitialized.toString(),
    };
  }

  /// 🔧 NUEVO: Método para verificar conectividad con timeout
  Future<bool> checkConnectivityWithTimeout({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final result = await _connectivity.checkConnectivity().timeout(timeout);
      _lastResult = result;

      // Registrar el resultado
      _recordConnectivityChange(result);

      return isConnected;
    } catch (e) {
      debugPrint('❌ Error verificando conectividad con timeout: $e');
      return false;
    }
  }

  /// Liberar recursos
  void dispose() {
    try {
      _subscription.cancel();
      _connectivityController.close();
      debugPrint('🗑️ ConnectivityService disposed');
    } catch (e) {
      debugPrint('❌ Error disposing ConnectivityService: $e');
    }
  }
}
