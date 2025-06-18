// lib/main.dart
// 🔧 SOLUCIÓN DEFINITIVA: Main.dart sin errores de nullability

import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:goalkeeper_stats/domain/repositories/auth_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/matches_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/shots_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/goalkeeper_passes_repository.dart';
import 'package:goalkeeper_stats/data/repositories/firebase_auth_repository.dart';
import 'package:goalkeeper_stats/data/repositories/firebase_matches_repository.dart';
import 'package:goalkeeper_stats/data/repositories/firebase_shots_repository.dart';
import 'package:goalkeeper_stats/data/repositories/firebase_goalkeeper_passes_repository.dart';
import 'package:goalkeeper_stats/services/cache_manager.dart';
import 'package:goalkeeper_stats/presentation/pages/auth/login_page.dart';
import 'package:goalkeeper_stats/presentation/blocs/auth/auth_bloc.dart';
import 'package:goalkeeper_stats/presentation/pages/splash/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'package:goalkeeper_stats/services/connectivity_service.dart';
import 'package:goalkeeper_stats/services/firebase_crashlytics_service.dart';
import 'package:goalkeeper_stats/services/purchase_service.dart';
import 'package:goalkeeper_stats/services/analytics_service.dart';
import 'package:goalkeeper_stats/services/daily_limits_service.dart';
import 'package:goalkeeper_stats/services/ad_service.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Variables globales usando late para evitar nullability issues
late AuthRepository authRepository;
late MatchesRepository matchesRepository;
late ShotsRepository shotsRepository;
late GoalkeeperPassesRepository passesRepository;
late CacheManager cacheManager;
late ConnectivityService connectivityService;
late FirebaseCrashlyticsService crashlyticsService;
late PurchaseService purchaseService;
late AnalyticsService analyticsService;
late DailyLimitsService dailyLimitsService;
late AdService adService;

// Variables para controlar el estado de inicialización
bool _servicesInitialized = false;
bool _repositoriesInitialized = false;
bool _initializationCompleted = false;

Future<void> main() async {
  // Inicialización de Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // Detectar si es tablet o teléfono
  final window = WidgetsBinding.instance.window;
  final size = window.physicalSize / window.devicePixelRatio;
  final bool isTablet = size.shortestSide > 600;

  // Configurar orientación según tipo de dispositivo
  if (isTablet) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  } else {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Iniciar la aplicación con splash screen
  runApp(const GoalkeeperStatsApp());
}

/// 🔧 FUNCIÓN PRINCIPAL: Inicialización completa de la aplicación
Future<void> performAppInitialization() async {
  if (_initializationCompleted) {
    debugPrint('⚠️ Inicialización ya completada, saltando...');
    return;
  }

  try {
    debugPrint('🚀 Iniciando inicialización completa...');

    // 🔧 PASO 1: Inicializar Firebase con configuración mejorada
    debugPrint('🔥 Inicializando Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 🔧 PASO CRÍTICO: Warm-up super robusto de Firebase Auth
    await _performSuperRobustFirebaseWarmUp();
    debugPrint('✅ Firebase inicializado y completamente calentado');

    // Configurar Crashlytics
    if (!kDebugMode && (Platform.isAndroid || Platform.isIOS)) {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } else {
      if (Platform.isAndroid || Platform.isIOS) {
        await FirebaseCrashlytics.instance
            .setCrashlyticsCollectionEnabled(false);
      }
    }

    // 🔧 PASO 2: Inicializar servicios
    await _initializeAllServices();

    // 🔧 PASO 3: Inicializar repositorios con Firebase completamente listo
    await _initializeRepositoriesWithStableFirebase();

    _initializationCompleted = true;
    debugPrint('🎯 Inicialización completa exitosa');
  } catch (e, stack) {
    debugPrint('❌ Error en inicialización completa: $e');
    debugPrint('Stack trace: $stack');

    // Resetear estados en caso de error
    _servicesInitialized = false;
    _repositoriesInitialized = false;
    _initializationCompleted = false;

    // Re-lanzar la excepción para que el splash screen la maneje
    rethrow;
  }
}

/// 🔧 FUNCIÓN: Warm-up super robusto de Firebase Auth
Future<void> _performSuperRobustFirebaseWarmUp() async {
  try {
    debugPrint('🔥 Iniciando warm-up super robusto de Firebase Auth...');

    final FirebaseAuth auth = FirebaseAuth.instance;

    // Paso 1: Configurar idioma inmediatamente
    await auth.setLanguageCode('es');
    debugPrint('✅ Idioma configurado');

    // Paso 2: Verificar estado inicial básico
    final currentUser = auth.currentUser;
    debugPrint('👤 Usuario inicial: ${currentUser?.uid ?? 'ninguno'}');

    // Paso 3: Operaciones progresivas para calentar Pigeon
    debugPrint('🔧 Calentando mecanismo Pigeon...');

    // Operación 1: fetchSignInMethodsForEmail (calienta Pigeon)
    try {
      await auth.fetchSignInMethodsForEmail('warmup1@test.com').timeout(
            const Duration(seconds: 4),
          );
    } catch (e) {
      debugPrint('✅ Warm-up 1 completado (error esperado): $e');
    }

    // Espera intermedia
    await Future.delayed(const Duration(milliseconds: 800));

    // Operación 2: Verificar configuración de idioma
    try {
      await auth.setLanguageCode('es'); // Repetir para asegurar
      debugPrint('✅ Idioma re-verificado');
    } catch (e) {
      debugPrint('⚠️ Error re-verificando idioma: $e');
    }

    // Operación 3: Google Sign-In warm-up
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId:
            '415256305974-9smib8kjpro0f7iacq4ctt2gqk3mdf0u.apps.googleusercontent.com',
        scopes: ['email', 'profile'],
      );

      // Solo verificar si está disponible, no hacer login
      await googleSignIn.isSignedIn();
      debugPrint('✅ Google Sign-In verificado');
    } catch (e) {
      debugPrint('⚠️ Google Sign-In warm-up: $e');
    }

    // Operación 4: Test de accesibilidad de usuario actual
    if (currentUser != null) {
      try {
        // Intentar acceder a propiedades para verificar deserialización
        final uid = currentUser.uid;
        final email = currentUser.email;
        final displayName = currentUser.displayName;
        final photoURL = currentUser.photoURL;

        debugPrint('✅ Usuario accesible: $uid ($email)');
      } catch (e) {
        debugPrint('⚠️ Error accediendo a usuario: $e');

        // Si hay error de PigeonUserDetails aquí, necesitamos más tiempo
        if (e.toString().contains('PigeonUserDetails') ||
            e.toString().contains('List<Object?>')) {
          debugPrint(
              '🚨 Error PigeonUserDetails detectado - warm-up extendido');
          await Future.delayed(const Duration(seconds: 3));

          // Segundo intento
          try {
            final _ = currentUser.uid;
            debugPrint('✅ Usuario accesible en segundo intento');
          } catch (e2) {
            debugPrint('🚨 Usuario aún problemático: $e2');
          }
        }
      }
    }

    // Operación 5: Espera final de estabilización
    debugPrint('⏳ Espera final de estabilización...');
    await Future.delayed(const Duration(milliseconds: 2000));

    // Operación 6: Test final de funcionalidad
    try {
      await auth.fetchSignInMethodsForEmail('finaltest@test.com').timeout(
            const Duration(seconds: 3),
          );
    } catch (e) {
      debugPrint('✅ Test final completado (error esperado): $e');
    }

    debugPrint('🎯 Warm-up super robusto completado exitosamente');
  } catch (e, stack) {
    debugPrint('❌ Error en warm-up super robusto: $e');

    // Registrar pero no fallar
    if (FirebaseCrashlytics.instance != null) {
      FirebaseCrashlytics.instance.recordError(e, stack,
          reason: 'Error en warm-up robusto de Firebase Auth');
    }

    // Espera adicional como fallback
    debugPrint('⏳ Fallback: espera adicional...');
    await Future.delayed(const Duration(seconds: 3));
  }
}

/// 🔧 FUNCIÓN: Inicializar todos los servicios
Future<void> _initializeAllServices() async {
  if (_servicesInitialized) {
    debugPrint('⚠️ Servicios ya inicializados, saltando...');
    return;
  }

  try {
    debugPrint('🔧 Inicializando servicios...');

    // 1. Servicios básicos primero
    connectivityService = ConnectivityService();
    crashlyticsService = FirebaseCrashlyticsService();
    await crashlyticsService.initialize();
    analyticsService = AnalyticsService();

    debugPrint('✅ Servicios básicos inicializados');

    // 2. Inicializar CacheManager
    cacheManager = CacheManager();
    await cacheManager.init();
    debugPrint('✅ Cache manager inicializado correctamente');

    // 3. Inicializar servicio de límites diarios
    dailyLimitsService = DailyLimitsService(
      cacheManager: cacheManager,
      crashlyticsService: crashlyticsService,
    );
    debugPrint('✅ DailyLimitsService inicializado');

    // 4. Inicializar servicio de anuncios
    adService = AdService();
    debugPrint('🎯 Inicializando AdService...');

    final adServiceInitialized = await adService.initialize();
    if (adServiceInitialized) {
      debugPrint('✅ AdService inicializado correctamente');
    } else {
      debugPrint('⚠️ AdService no se pudo inicializar');
    }

    // 5. Inicializar PurchaseService
    purchaseService = PurchaseService();
    debugPrint('🛒 Inicializando PurchaseService...');

    final purchaseInitialized = await purchaseService.initialize();
    if (purchaseInitialized) {
      debugPrint('✅ PurchaseService inicializado correctamente');
    } else {
      debugPrint('⚠️ PurchaseService no se pudo inicializar');
    }

    _servicesInitialized = true;
    debugPrint('✅ Todos los servicios inicializados');
  } catch (e, stack) {
    debugPrint('❌ Error al inicializar servicios: $e');
    _servicesInitialized = false;
    rethrow;
  }
}

/// 🔧 FUNCIÓN: Inicializar repositorios con Firebase estable
Future<void> _initializeRepositoriesWithStableFirebase() async {
  if (_repositoriesInitialized) {
    debugPrint('⚠️ Repositorios ya inicializados, saltando...');
    return;
  }

  if (!_servicesInitialized) {
    throw Exception(
        'Servicios no inicializados - no se pueden crear repositorios');
  }

  try {
    debugPrint('🗄️ Inicializando repositorios con Firebase estable...');

    // Espera adicional para asegurar que Firebase Auth esté 100% listo
    await Future.delayed(const Duration(milliseconds: 500));

    // 1. Inicializar AuthRepository con Firebase estabilizado
    authRepository = FirebaseAuthRepository(
      crashlyticsService: crashlyticsService,
    );

    // 🔧 ESPERA CRÍTICA: Dar tiempo a que AuthRepository se inicialice completamente
    await Future.delayed(const Duration(milliseconds: 1000));
    debugPrint('✅ AuthRepository inicializado y estabilizado');

    // 2. Inicializar ShotsRepository
    shotsRepository = FirebaseShotsRepository(
      authRepository: authRepository,
      cacheManager: cacheManager,
      dailyLimitsService: dailyLimitsService,
    );
    debugPrint('✅ ShotsRepository inicializado');

    // 3. Inicializar PassesRepository
    passesRepository = FirebaseGoalkeeperPassesRepository(
      authRepository: authRepository,
      cacheManager: cacheManager,
    );
    debugPrint('✅ PassesRepository inicializado');

    // 4. Inicializar MatchesRepository
    matchesRepository = FirebaseMatchesRepository(
      authRepository: authRepository,
      shotsRepository: shotsRepository,
      passesRepository: passesRepository,
      cacheManager: cacheManager,
    );
    debugPrint('✅ MatchesRepository inicializado');

    _repositoriesInitialized = true;
    debugPrint(
        '✅ Todos los repositorios inicializados correctamente con Firebase estable');
  } catch (e, stack) {
    debugPrint('❌ Error al inicializar repositorios: $e');
    debugPrint('Stack trace: $stack');

    _repositoriesInitialized = false;
    crashlyticsService.recordError(e, stack,
        reason: 'Error inicializando repositorios con Firebase estable');
    rethrow;
  }
}

/// 🔧 FUNCIÓN: Resetear estado de inicialización para reintentos
void resetInitializationState() {
  debugPrint('🔄 Reseteando estado de inicialización...');

  _servicesInitialized = false;
  _repositoriesInitialized = false;
  _initializationCompleted = false;

  debugPrint('✅ Estado reseteado correctamente');
}

class GoalkeeperStatsApp extends StatefulWidget {
  const GoalkeeperStatsApp({super.key});

  @override
  State<GoalkeeperStatsApp> createState() => _GoalkeeperStatsAppState();
}

class _GoalkeeperStatsAppState extends State<GoalkeeperStatsApp> {
  bool _showSplash = true;
  bool _initializationError = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Goalkeeper Stats',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: ThemeMode.system,
      home: _showSplash ? _buildSplashScreen() : _buildMainApp(),
    );
  }

  Widget _buildSplashScreen() {
    return SplashScreen(
      onInitialize: () async {
        try {
          // Resetear el estado si es un reintento
          if (_initializationError) {
            resetInitializationState();
          }

          await performAppInitialization();
        } catch (e) {
          setState(() {
            _initializationError = true;
            _errorMessage = e.toString();
          });
          rethrow;
        }
      },
      onComplete: () {
        if (mounted) {
          setState(() {
            _showSplash = false;
          });
        }
      },
    );
  }

  Widget _buildMainApp() {
    // Si hubo error en la inicialización, mostrar pantalla de error
    if (_initializationError || !_initializationCompleted) {
      return _buildErrorScreen();
    }

    return MultiProvider(
      providers: [
        // Repositorios - usando late variables (no nullable)
        Provider<AuthRepository>.value(value: authRepository),
        Provider<MatchesRepository>.value(value: matchesRepository),
        Provider<ShotsRepository>.value(value: shotsRepository),
        Provider<GoalkeeperPassesRepository>.value(value: passesRepository),

        // Servicios básicos - usando late variables (no nullable)
        Provider<CacheManager>.value(value: cacheManager),
        Provider<ConnectivityService>.value(value: connectivityService),
        Provider<FirebaseCrashlyticsService>.value(value: crashlyticsService),
        Provider<PurchaseService>.value(value: purchaseService),
        Provider<AnalyticsService>.value(value: analyticsService),
        Provider<DailyLimitsService>.value(value: dailyLimitsService),
        Provider<AdService>.value(value: adService),

        // BLoC providers
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc(
            authRepository: authRepository,
            analyticsService: analyticsService,
            crashlytics: FirebaseCrashlytics.instance,
            connectivityService: connectivityService,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Goalkeeper Stats',
        debugShowCheckedModeBanner: false,

        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('es', ''), // Español (principal)
          Locale('en', ''), // Inglés
        ],
        locale: const Locale('es', ''), // Idioma por defecto

        // Temas
        theme: _buildLightTheme(),
        darkTheme: _buildDarkTheme(),
        themeMode: ThemeMode.system,

        // Página inicial
        home: const LoginPage(),

        routes: {
          '/login': (context) => const LoginPage(),
          '/subscription': (context) => const Scaffold(
                body: Center(
                  child: Text(
                    'Página de suscripción\n(Por implementar)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
        },

        onUnknownRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: const Text('Página no encontrada'),
              ),
              body: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Página no encontrada',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('La página solicitada no existe.'),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red.shade600,
              ),
              const SizedBox(height: 24),
              const Text(
                'Error al inicializar la aplicación',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'No se pudo conectar con los servicios necesarios. '
                'Por favor:\n\n'
                '• Verifica tu conexión a internet\n'
                '• Asegúrate de tener la última versión de la app\n'
                '• Reinicia la aplicación',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                ExpansionTile(
                  title: const Text('Detalles técnicos'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      SystemNavigator.pop();
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Cerrar App'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showSplash = true;
                        _initializationError = false;
                        _errorMessage = null;
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      primarySwatch: Colors.green,
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF184621),
        brightness: Brightness.light,
      ),
      // appBarTheme: const AppBarTheme(
      //   elevation: 0,
      //   centerTitle: true,
      //   backgroundColor: Color(0xFF388E3C),
      //   foregroundColor: Colors.white,
      // ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF388E3C),
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      primarySwatch: Colors.green,
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF9EDE53),
        brightness: Brightness.dark,
      ),
      // appBarTheme: const AppBarTheme(
      //   elevation: 0,
      //   centerTitle: true,
      //   backgroundColor: Color(0xFF1B5E20),
      //   foregroundColor: Colors.white,
      // ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
