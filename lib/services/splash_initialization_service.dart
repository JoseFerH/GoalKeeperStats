// lib/services/splash_initialization_service.dart
import 'package:flutter/foundation.dart';

/// Servicio que maneja la inicialización paso a paso para el splash screen
class SplashInitializationService {
  static const List<SplashStep> _initializationSteps = [
    SplashStep(
      id: 'flutter_binding',
      name: 'Iniciando aplicación...',
      description: 'Configurando Flutter framework',
      duration: Duration(milliseconds: 500),
    ),
    SplashStep(
      id: 'firebase_core',
      name: 'Conectando con Firebase...',
      description: 'Estableciendo conexión con servicios backend',
      duration: Duration(milliseconds: 2000),
    ),
    SplashStep(
      id: 'firebase_auth_warmup',
      name: 'Calentando autenticación...',
      description: 'Preparando sistema de usuarios',
      duration: Duration(milliseconds: 1500),
    ),
    SplashStep(
      id: 'services_init',
      name: 'Inicializando servicios...',
      description: 'Configurando cache, analytics y crashlytics',
      duration: Duration(milliseconds: 1200),
    ),
    SplashStep(
      id: 'repositories_init',
      name: 'Configurando repositorios...',
      description: 'Preparando acceso a datos',
      duration: Duration(milliseconds: 800),
    ),
    SplashStep(
      id: 'ui_preparation',
      name: 'Preparando interfaz...',
      description: 'Configurando temas y localización',
      duration: Duration(milliseconds: 600),
    ),
    SplashStep(
      id: 'final_checks',
      name: '¡Listo para jugar!',
      description: 'Verificaciones finales completadas',
      duration: Duration(milliseconds: 400),
    ),
  ];

  /// Obtiene todos los pasos de inicialización
  static List<SplashStep> get initializationSteps => _initializationSteps;

  /// Obtiene un paso específico por ID
  static SplashStep? getStepById(String id) {
    try {
      return _initializationSteps.firstWhere((step) => step.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Obtiene el índice de un paso específico
  static int getStepIndex(String stepId) {
    return _initializationSteps.indexWhere((step) => step.id == stepId);
  }

  /// Calcula el progreso total basado en el paso actual
  static double calculateProgress(String currentStepId) {
    final currentIndex = getStepIndex(currentStepId);
    if (currentIndex == -1) return 0.0;

    return (currentIndex + 1) / _initializationSteps.length;
  }

  /// Simula la ejecución de un paso específico
  static Future<void> executeStep(String stepId) async {
    final step = getStepById(stepId);
    if (step == null) {
      debugPrint('⚠️ Paso no encontrado: $stepId');
      return;
    }

    debugPrint('🔧 Ejecutando: ${step.name}');

    // Simular el tiempo del paso (en desarrollo)
    if (kDebugMode) {
      await Future.delayed(step.duration);
    }

    debugPrint('✅ Completado: ${step.name}');
  }

  /// Valida que todos los pasos sean válidos
  static bool validateSteps() {
    if (_initializationSteps.isEmpty) {
      debugPrint('❌ Error: No hay pasos de inicialización definidos');
      return false;
    }

    final uniqueIds = <String>{};
    for (final step in _initializationSteps) {
      if (!uniqueIds.add(step.id)) {
        debugPrint('❌ Error: ID duplicado encontrado: ${step.id}');
        return false;
      }
    }

    debugPrint(
        '✅ Validación de pasos exitosa: ${_initializationSteps.length} pasos');
    return true;
  }

  /// Obtiene estadísticas de la inicialización
  static InitializationStats getStats() {
    final totalDuration = _initializationSteps.fold<Duration>(
      Duration.zero,
      (total, step) => total + step.duration,
    );

    return InitializationStats(
      totalSteps: _initializationSteps.length,
      totalDuration: totalDuration,
      criticalSteps: _initializationSteps
          .where((step) => step.duration > const Duration(milliseconds: 1000))
          .length,
    );
  }
}

/// Modelo que representa un paso de inicialización
class SplashStep {
  final String id;
  final String name;
  final String description;
  final Duration duration;

  const SplashStep({
    required this.id,
    required this.name,
    required this.description,
    required this.duration,
  });

  @override
  String toString() {
    return 'SplashStep(id: $id, name: $name, duration: ${duration.inMilliseconds}ms)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SplashStep && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Estadísticas de la inicialización
class InitializationStats {
  final int totalSteps;
  final Duration totalDuration;
  final int criticalSteps;

  const InitializationStats({
    required this.totalSteps,
    required this.totalDuration,
    required this.criticalSteps,
  });

  /// Duración estimada en segundos
  double get estimatedSeconds => totalDuration.inMilliseconds / 1000.0;

  /// Porcentaje de pasos críticos
  double get criticalStepsPercentage => criticalSteps / totalSteps;

  @override
  String toString() {
    return 'InitializationStats('
        'steps: $totalSteps, '
        'duration: ${estimatedSeconds.toStringAsFixed(1)}s, '
        'critical: $criticalSteps'
        ')';
  }
}
