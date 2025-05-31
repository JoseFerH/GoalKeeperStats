import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // CORREGIDO: Añadir importación
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
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'package:goalkeeper_stats/services/connectivity_service.dart';
import 'package:goalkeeper_stats/services/firebase_crashlytics_service.dart';
import 'package:goalkeeper_stats/services/purchase_service.dart';
import 'package:goalkeeper_stats/services/analytics_service.dart';
import 'package:goalkeeper_stats/services/daily_limits_service.dart'; // NUEVO: Servicio de límites
import 'package:goalkeeper_stats/core/constants/app_constants.dart';

// Variables globales para los repositorios
late AuthRepository authRepository;
late MatchesRepository matchesRepository;
late ShotsRepository shotsRepository;
late GoalkeeperPassesRepository passesRepository;
late CacheManager cacheManager;

// Variables globales para los servicios
late ConnectivityService connectivityService;
late FirebaseCrashlyticsService crashlyticsService;
late PurchaseService purchaseService;
late AnalyticsService analyticsService;
late DailyLimitsService dailyLimitsService; // NUEVO: Servicio de límites

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

  // Flag para indicar si Firebase se inicializó correctamente
  bool firebaseInitialized = false;

  try {
    // Inicializar Firebase con manejo de errores mejorado
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    firebaseInitialized = true;
    debugPrint('✅ Firebase inicializado correctamente');

    // Configurar Crashlytics solo después de que Firebase esté inicializado
    if (!kDebugMode && (Platform.isAndroid || Platform.isIOS)) {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

      // Capturar errores no manejados
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } else {
      // En modo debug, desactivar Crashlytics
      if (Platform.isAndroid || Platform.isIOS) {
        await FirebaseCrashlytics.instance
            .setCrashlyticsCollectionEnabled(false);
      }
    }

    // Inicializar servicios en orden correcto
    debugPrint('🔧 Inicializando servicios...');

    // 1. Servicios básicos primero
    connectivityService = ConnectivityService();
    crashlyticsService = FirebaseCrashlyticsService();
    await crashlyticsService
        .initialize(); // CORREGIDO: Inicializar explícitamente
    analyticsService = AnalyticsService();

    debugPrint('✅ Servicios básicos inicializados');

    // 2. Inicializar CacheManager
    cacheManager = CacheManager();
    await cacheManager.init();
    debugPrint('✅ Cache manager inicializado correctamente');

    // 3. NUEVO: Inicializar servicio de límites diarios
    dailyLimitsService = DailyLimitsService(
      cacheManager: cacheManager,
      crashlyticsService: crashlyticsService,
    );
    debugPrint('✅ DailyLimitsService inicializado');

    // 4. Inicializar PurchaseService
    purchaseService = PurchaseService();
    debugPrint('🛒 Inicializando PurchaseService...');

    final purchaseInitialized = await purchaseService.initialize();

    if (purchaseInitialized) {
      debugPrint('✅ PurchaseService inicializado correctamente');
    } else {
      debugPrint(
          '⚠️ PurchaseService no se pudo inicializar (las compras pueden no estar disponibles)');
    }
  } catch (e, stack) {
    debugPrint('❌ Error al inicializar Firebase o servicios: $e');
    debugPrint('Stack trace: $stack');

    // Registrar error en Crashlytics si está disponible
    if (firebaseInitialized) {
      FirebaseCrashlytics.instance
          .recordError(e, stack, reason: 'Error en inicialización principal');
    }
  }

  // Inicializar repositorios
  if (firebaseInitialized) {
    try {
      debugPrint('🗄️ Inicializando repositorios...');

      // 1. Inicializar AuthRepository
      authRepository = FirebaseAuthRepository();
      debugPrint('✅ AuthRepository inicializado');

      // 2. CORREGIDO: Inicializar ShotsRepository con DailyLimitsService
      shotsRepository = FirebaseShotsRepository(
        authRepository: authRepository,
        cacheManager: cacheManager,
        dailyLimitsService: dailyLimitsService, // NUEVO parámetro
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

      debugPrint('✅ Todos los repositorios inicializados correctamente');
    } catch (e, stack) {
      debugPrint('❌ Error al inicializar repositorios: $e');
      debugPrint('Stack trace: $stack');

      // Registrar error
      crashlyticsService.recordError(e, stack,
          reason: 'Error inicializando repositorios');

      // Aquí podrías crear repositorios mock o fallback si es necesario
    }
  } else {
    debugPrint('⚠️ Firebase no inicializado, no se pueden crear repositorios');
  }

  // Iniciar la aplicación
  debugPrint('🚀 Iniciando aplicación...');
  runApp(GoalkeeperStatsApp(
    firebaseInitialized: firebaseInitialized,
  ));
}

class GoalkeeperStatsApp extends StatelessWidget {
  final bool firebaseInitialized;

  const GoalkeeperStatsApp({
    super.key,
    required this.firebaseInitialized,
  });

  @override
  Widget build(BuildContext context) {
    // Si Firebase no está inicializado, mostrar una pantalla de error
    if (!firebaseInitialized) {
      return MaterialApp(
        title: 'Goalkeeper Stats - Error',
        debugShowCheckedModeBanner: false,
        home: Scaffold(
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
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Reiniciar la app
                      SystemNavigator.pop();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reiniciar App'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MultiProvider(
      providers: [
        // Repositorios
        Provider<AuthRepository>.value(value: authRepository),
        Provider<MatchesRepository>.value(value: matchesRepository),
        Provider<ShotsRepository>.value(value: shotsRepository),
        Provider<GoalkeeperPassesRepository>.value(value: passesRepository),

        // Servicios básicos
        Provider<CacheManager>.value(value: cacheManager),
        Provider<ConnectivityService>.value(value: connectivityService),
        Provider<FirebaseCrashlyticsService>.value(value: crashlyticsService),
        Provider<PurchaseService>.value(value: purchaseService),
        Provider<AnalyticsService>.value(value: analyticsService),

        // NUEVO: Añadir DailyLimitsService a los providers
        Provider<DailyLimitsService>.value(value: dailyLimitsService),

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

        // CORREGIDO: Configuración completa de localización
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
        theme: ThemeData(
          primarySwatch: Colors.green,
          useMaterial3: true,
          brightness: Brightness.light,
          // Colores personalizados
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF184621),
            brightness: Brightness.light,
          ),
        ),
        darkTheme: ThemeData(
          primarySwatch: Colors.green,
          useMaterial3: true,
          brightness: Brightness.dark,
          // Colores personalizados para modo oscuro
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF9EDE53),
            brightness: Brightness.dark,
          ),
        ),
        themeMode: ThemeMode.system,

        // Página inicial
        home: const LoginPage(),

        // NUEVO: Rutas nombradas para navegación
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

        // Manejo de rutas no encontradas
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
}

// NUEVO: Función para logging de información del sistema
void _logSystemInfo() {
  debugPrint('📱 Información del sistema:');
  debugPrint('   Platform: ${Platform.operatingSystem}');
  debugPrint('   Debug mode: $kDebugMode');
  debugPrint('   Profile mode: $kProfileMode');
  debugPrint('   Release mode: $kReleaseMode');
}

// NUEVO: Función para manejo de errores globales
void _setupGlobalErrorHandling() {
  // Capturar errores de Flutter
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);

    // Registrar en Crashlytics si está disponible
    try {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    } catch (e) {
      debugPrint('Error registrando en Crashlytics: $e');
    }
  };

  // Capturar errores de la zona
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Error no capturado: $error');
    debugPrint('Stack trace: $stack');

    // Registrar en Crashlytics si está disponible
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (e) {
      debugPrint('Error registrando en Crashlytics: $e');
    }

    return true;
  };
}
