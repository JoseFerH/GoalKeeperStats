import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:goalkeeper_stats/data/repositories/firebase_auth_repository.dart';
import 'package:goalkeeper_stats/data/repositories/firebase_goalkeeper_passes_repository.dart';
import 'package:goalkeeper_stats/data/repositories/firebase_matches_repository.dart';
import 'package:goalkeeper_stats/data/repositories/firebase_shots_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/auth_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/goalkeeper_passes_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/matches_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/shots_repository.dart';
import 'package:goalkeeper_stats/firebase_options.dart';
import 'package:goalkeeper_stats/services/cache_manager.dart';
import 'package:goalkeeper_stats/services/connectivity_service.dart';
import 'package:goalkeeper_stats/services/firebase_crashlytics_service.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Clase global para gestionar todos los repositorios usando exclusivamente Firebase
///
/// Implementa el patrón Singleton para asegurar una sola instancia
/// de cada repositorio en toda la aplicación.
class RepositoryProvider {
  // Instancias de repositorios
  late AuthRepository _authRepository;
  late MatchesRepository _matchesRepository;
  late ShotsRepository _shotsRepository;
  late GoalkeeperPassesRepository _passesRepository;

  // Servicios de utilidad
  late CacheManager _cacheManager;
  late ConnectivityService _connectivityService;
  late FirebaseCrashlyticsService _crashlyticsService;

  // Estado de inicialización
  bool _isInitialized = false;

  // Singleton
  static final RepositoryProvider _instance = RepositoryProvider._internal();

  factory RepositoryProvider() {
    return _instance;
  }

  RepositoryProvider._internal();

  /// Indica si los repositorios ya fueron inicializados
  bool get isInitialized => _isInitialized;

  /// Inicializador de Firebase y repositorios
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Inicializar Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Inicializar servicios de utilidad
      _cacheManager = CacheManager();
      await _cacheManager.init();

      _connectivityService = ConnectivityService();

      _crashlyticsService = FirebaseCrashlyticsService();
      await _crashlyticsService.initialize();

      // 1. Crear AuthRepository primero (no depende de otros repositorios)
      _authRepository = FirebaseAuthRepository(
        cacheManager: _cacheManager,
      );

      // 2. Crear ShotsRepository (depende de AuthRepository)
      _shotsRepository = FirebaseShotsRepository(
        authRepository: _authRepository,
        cacheManager: _cacheManager,
      );

      // 3. Crear PassesRepository (depende de AuthRepository)
      _passesRepository = FirebaseGoalkeeperPassesRepository(
        authRepository: _authRepository,
        cacheManager: _cacheManager,
      );

      // 4. Crear MatchesRepository (depende de AuthRepository y opcionalmente de otros repositorios)
      _matchesRepository = FirebaseMatchesRepository(
        authRepository: _authRepository,
        shotsRepository: _shotsRepository,
        passesRepository: _passesRepository,
        cacheManager: _cacheManager,
      );

      _isInitialized = true;
      debugPrint('RepositoryProvider inicializado correctamente');
    } catch (e, stack) {
      debugPrint('Error al inicializar RepositoryProvider: $e');
      // Registrar error en Crashlytics
      FirebaseCrashlytics.instance.recordError(e, stack,
          reason: 'Error inicializando RepositoryProvider');
      rethrow;
    }
  }

  // Getters para repositorios
  AuthRepository get authRepository {
    _checkInitialization();
    return _authRepository;
  }

  MatchesRepository get matchesRepository {
    _checkInitialization();
    return _matchesRepository;
  }

  ShotsRepository get shotsRepository {
    _checkInitialization();
    return _shotsRepository;
  }

  GoalkeeperPassesRepository get passesRepository {
    _checkInitialization();
    return _passesRepository;
  }

  // Getters para servicios
  CacheManager get cacheManager {
    _checkInitialization();
    return _cacheManager;
  }

  ConnectivityService get connectivityService {
    _checkInitialization();
    return _connectivityService;
  }

  FirebaseCrashlyticsService get crashlyticsService {
    _checkInitialization();
    return _crashlyticsService;
  }

  /// Verifica si los repositorios están inicializados
  void _checkInitialization() {
    if (!_isInitialized) {
      throw Exception(
          'RepositoryProvider no está inicializado. Llama a initialize() primero.');
    }
  }

  /// Liberar recursos al cerrar la aplicación
  void dispose() {
    if (_isInitialized) {
      _connectivityService.dispose();
      _crashlyticsService.dispose();
    }
  }
}

/// Instancia global para fácil acceso
final repositoryProvider = RepositoryProvider();
