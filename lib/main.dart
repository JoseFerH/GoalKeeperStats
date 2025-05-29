import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import 'package:goalkeeper_stats/core/constants/app_constants.dart';

// Variables globales para los repositorios
late AuthRepository authRepository;
late MatchesRepository matchesRepository;
late ShotsRepository shotsRepository;
late GoalkeeperPassesRepository passesRepository;
late CacheManager cacheManager;

late ConnectivityService connectivityService;
late FirebaseCrashlyticsService crashlyticsService;
late PurchaseService purchaseService;
late AnalyticsService analyticsService;

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

    // Inicializar servicios
    connectivityService = ConnectivityService();
    crashlyticsService = FirebaseCrashlyticsService();
    analyticsService = AnalyticsService();

    // Inicializar PurchaseService
    purchaseService = PurchaseService();
    debugPrint('🛒 Inicializando PurchaseService...');

    // Inicializar el servicio de compras con los IDs de productos
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
  }

  // Inicializar gestor de caché independientemente de Firebase
  try {
    cacheManager = CacheManager();
    await cacheManager.init();
    debugPrint('✅ Cache manager inicializado correctamente');
  } catch (e) {
    debugPrint('❌ Error al inicializar cache manager: $e');
    // Crear un cache manager básico si falla
    cacheManager = CacheManager();
  }

  // Inicializar repositorios
  if (firebaseInitialized) {
    try {
      // 1. Inicializar AuthRepository
      authRepository = FirebaseAuthRepository();
      debugPrint('✅ AuthRepository inicializado');

      // 2. Inicializar ShotsRepository
      shotsRepository = FirebaseShotsRepository(
        authRepository: authRepository,
        cacheManager: cacheManager,
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
    } catch (e, stack) {
      debugPrint('❌ Error al inicializar repositorios: $e');
      debugPrint('Stack trace: $stack');
      // Aquí podrías crear repositorios mock o fallback si es necesario
    }
  }

  // Iniciar la aplicación
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
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Error al inicializar Firebase',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Por favor, verifica tu conexión a internet',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    // Reiniciar la app
                    SystemNavigator.pop();
                  },
                  child: const Text('Reiniciar App'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: authRepository),
        Provider<MatchesRepository>.value(value: matchesRepository),
        Provider<ShotsRepository>.value(value: shotsRepository),
        Provider<GoalkeeperPassesRepository>.value(value: passesRepository),
        Provider<CacheManager>.value(value: cacheManager),
        Provider<ConnectivityService>.value(value: connectivityService),
        Provider<FirebaseCrashlyticsService>.value(value: crashlyticsService),
        Provider<PurchaseService>.value(value: purchaseService),
        Provider<AnalyticsService>.value(value: analyticsService),

        // Agregar AuthBloc aquí
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
        theme: ThemeData(
          primarySwatch: Colors.green,
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          primarySwatch: Colors.green,
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        themeMode: ThemeMode.system,
        home: const LoginPage(),
      ),
    );
  }
}
