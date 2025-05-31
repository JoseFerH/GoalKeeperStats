// lib/core/utils/dependency_injection.dart

import 'package:goalkeeper_stats/domain/repositories/auth_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/shots_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/matches_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/goalkeeper_passes_repository.dart';

// Importaciones locales
import 'package:goalkeeper_stats/data/repositories/local_auth_repository.dart';
import 'package:goalkeeper_stats/data/repositories/local_shots_repository.dart';
import 'package:goalkeeper_stats/data/repositories/local_matches_repository.dart';
import 'package:goalkeeper_stats/data/repositories/local_goalkeeper_passes_repository.dart';

// Importaciones de Firebase
import 'package:goalkeeper_stats/data/repositories/firebase_auth_repository.dart';
import 'package:goalkeeper_stats/data/repositories/firebase_shots_repository.dart';
import 'package:goalkeeper_stats/data/repositories/firebase_matches_repository.dart';
import 'package:goalkeeper_stats/data/repositories/firebase_goalkeeper_passes_repository.dart';

// Servicios
import 'package:goalkeeper_stats/services/cache_manager.dart';
import 'package:goalkeeper_stats/services/connectivity_service.dart';
import 'package:goalkeeper_stats/services/analytics_service.dart';
import 'package:goalkeeper_stats/services/firebase_crashlytics_service.dart';
import 'package:goalkeeper_stats/services/daily_limits_service.dart'; // NUEVO: Servicio de límites
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

enum StorageMode {
  local,
  firebase,
}

class DependencyInjection {
  static final DependencyInjection _instance = DependencyInjection._internal();

  factory DependencyInjection() => _instance;

  DependencyInjection._internal() {
    // Inicializar servicios
    _initializeServices();
  }

  // Por defecto, usar almacenamiento Firebase
  StorageMode _currentMode = StorageMode.firebase;

  // Instancias de repositorios (inicializadas bajo demanda)
  AuthRepository? _authRepository;
  ShotsRepository? _shotsRepository;
  MatchesRepository? _matchesRepository;
  GoalkeeperPassesRepository? _passesRepository;

  // Instancias de servicios
  CacheManager? _cacheManager;
  ConnectivityService? _connectivityService;
  AnalyticsService? _analyticsService;
  FirebaseCrashlyticsService? _crashlyticsService;
  DailyLimitsService? _dailyLimitsService; // NUEVO: Servicio de límites

  // Inicialización de servicios
  Future<void> _initializeServices() async {
    _cacheManager = CacheManager();
    await _cacheManager!.init();

    _connectivityService = ConnectivityService();
    _analyticsService = AnalyticsService();
    _crashlyticsService = FirebaseCrashlyticsService();

    // NUEVO: Inicializar servicio de límites diarios
    _dailyLimitsService = DailyLimitsService(
      cacheManager: _cacheManager,
      crashlyticsService: _crashlyticsService,
    );
  }

  // Reiniciar todas las instancias cuando cambie el modo
  void _resetRepositories() {
    _authRepository = null;
    _shotsRepository = null;
    _matchesRepository = null;
    _passesRepository = null;
    // NUEVO: También resetear servicio de límites si cambia el modo
    _dailyLimitsService = null;
  }

  // Getters para los repositorios con lazy initialization
  AuthRepository get authRepository {
    _authRepository ??= _createAuthRepository();
    return _authRepository!;
  }

  // CORREGIDO: ShotsRepository ahora incluye DailyLimitsService
  ShotsRepository get shotsRepository {
    _shotsRepository ??= _createShotsRepository();
    return _shotsRepository!;
  }

  MatchesRepository get matchesRepository {
    _matchesRepository ??= _createMatchesRepository();
    return _matchesRepository!;
  }

  GoalkeeperPassesRepository get passesRepository {
    _passesRepository ??= _createPassesRepository();
    return _passesRepository!;
  }

  // Getters para los servicios
  CacheManager get cacheManager {
    _cacheManager ??= CacheManager()..init();
    return _cacheManager!;
  }

  ConnectivityService get connectivityService {
    _connectivityService ??= ConnectivityService();
    return _connectivityService!;
  }

  AnalyticsService get analyticsService {
    _analyticsService ??= AnalyticsService();
    return _analyticsService!;
  }

  FirebaseCrashlyticsService get crashlyticsService {
    _crashlyticsService ??= FirebaseCrashlyticsService();
    return _crashlyticsService!;
  }

  // NUEVO: Getter para servicio de límites diarios
  DailyLimitsService get dailyLimitsService {
    if (_dailyLimitsService == null) {
      _dailyLimitsService = DailyLimitsService(
        cacheManager: cacheManager,
        crashlyticsService: crashlyticsService,
      );
    }
    return _dailyLimitsService!;
  }

  // Crashlytics
  FirebaseCrashlytics get crashlytics => FirebaseCrashlytics.instance;

  // Métodos privados para crear repositorios
  AuthRepository _createAuthRepository() {
    return _currentMode == StorageMode.local
        ? LocalAuthRepository()
        : FirebaseAuthRepository();
  }

  // CORREGIDO: Incluir DailyLimitsService en ShotsRepository
  ShotsRepository _createShotsRepository() {
    if (_currentMode == StorageMode.local) {
      return LocalShotsRepository();
    } else {
      return FirebaseShotsRepository(
        authRepository: authRepository,
        cacheManager: cacheManager,
        dailyLimitsService: dailyLimitsService, // NUEVO parámetro
      );
    }
  }

  GoalkeeperPassesRepository _createPassesRepository() {
    if (_currentMode == StorageMode.local) {
      return LocalGoalkeeperPassesRepository();
    } else {
      return FirebaseGoalkeeperPassesRepository(
        authRepository: authRepository,
        cacheManager: cacheManager,
      );
    }
  }

  MatchesRepository _createMatchesRepository() {
    if (_currentMode == StorageMode.local) {
      return LocalMatchesRepository();
    } else {
      return FirebaseMatchesRepository(
        authRepository: authRepository,
        shotsRepository: shotsRepository,
        passesRepository: passesRepository,
        cacheManager: cacheManager,
      );
    }
  }

  // Método para cambiar el modo de almacenamiento
  void setStorageMode(StorageMode mode) {
    if (_currentMode != mode) {
      _currentMode = mode;
      _resetRepositories();
    }
  }

  // Verificar si Firebase está disponible
  Future<bool> isFirebaseAvailable() async {
    try {
      // Aquí podríamos hacer una verificación simple de Firebase
      return _currentMode == StorageMode.firebase;
    } catch (e) {
      return false;
    }
  }

  // NUEVO: Método para limpiar recursos
  void dispose() {
    _connectivityService?.dispose();
    _crashlyticsService?.dispose();
    // El resto de servicios se limpiarán automáticamente
  }

  // NUEVO: Método para reinicializar todos los servicios (útil para testing)
  Future<void> reinitialize() async {
    _resetRepositories();
    await _initializeServices();
  }

  // NUEVO: Método para obtener información de debug
  Map<String, dynamic> getDebugInfo() {
    return {
      'storageMode': _currentMode.toString(),
      'authRepository': _authRepository?.runtimeType.toString(),
      'shotsRepository': _shotsRepository?.runtimeType.toString(),
      'matchesRepository': _matchesRepository?.runtimeType.toString(),
      'passesRepository': _passesRepository?.runtimeType.toString(),
      'services': {
        'cacheManager': _cacheManager != null,
        'connectivityService': _connectivityService != null,
        'analyticsService': _analyticsService != null,
        'crashlyticsService': _crashlyticsService != null,
        'dailyLimitsService': _dailyLimitsService != null,
      },
    };
  }
}

// Instancia global para compatibilidad con código existente
final repositoryProvider = DependencyInjection();
