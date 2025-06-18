// lib/main.dart
// 🔧 VERSIÓN CORREGIDA: Main.dart sin conflictos de tipos

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
late DailyLimitsService dailyLimitsService;
late AdService adService;

void main() async {
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
    // 🔧 PASO 1: Inicializar Firebase con configuración mejorada
    debugPrint('🔥 Inicializando Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 🔧 PASO CRÍTICO: Warm-up mejorado pero simplificado
    await performFirebaseWarmUp();

    firebaseInitialized = true;
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
    await initializeAllServices();

    // 🔧 PASO 3: Inicializar repositorios
    await initializeRepositories();
  } catch (e, stack) {
    debugPrint('❌ Error al inicializar Firebase o servicios: $e');
    debugPrint('Stack trace: $stack');

    if (firebaseInitialized) {
      FirebaseCrashlytics.instance
          .recordError(e, stack, reason: 'Error en inicialización principal');
    }
  }

  // Iniciar la aplicación
  debugPrint('🚀 Iniciando aplicación...');
  runApp(GoalkeeperStatsApp(
    firebaseInitialized: firebaseInitialized,
  ));
}

/// 🔧 FUNCIÓN SIMPLIFICADA: Warm-up de Firebase Auth
dynamic performFirebaseWarmUp() async {
  try {
    debugPrint('🔥 Iniciando warm-up de Firebase Auth...');

    final FirebaseAuth auth = FirebaseAuth.instance;

    // Paso 1: Configurar idioma
    await auth.setLanguageCode('es');
    debugPrint('✅ Idioma configurado');

    // Paso 2: Múltiples operaciones para calentar Pigeon
    debugPrint('🔧 Calentando mecanismo Pigeon...');

    for (int i = 1; i <= 5; i++) {
      try {
        await auth.fetchSignInMethodsForEmail('warmup$i@test.com').timeout(
              const Duration(seconds: 4),
            );
      } catch (e) {
        debugPrint('✅ Warm-up $i completado: $e');
      }

      // Espera entre operaciones
      await waitMilliseconds(300 * i);
    }

    // Paso 3: Warm-up de Google Sign-In
    await warmUpGoogleSignIn();

    // Paso 4: Test de usuario actual
    await testCurrentUserAccess(auth);

    // Paso 5: Espera final
    debugPrint('⏳ Espera final de estabilización...');
    await waitMilliseconds(3000);

    debugPrint('🎯 Warm-up completado exitosamente');
  } catch (e, stack) {
    debugPrint('❌ Error en warm-up: $e');

    // Registrar pero no fallar
    try {
      FirebaseCrashlytics.instance
          .recordError(e, stack, reason: 'Error en warm-up de Firebase Auth');
    } catch (_) {
      // Ignorar errores de Crashlytics
    }

    // Espera adicional como fallback
    debugPrint('⏳ Fallback: espera adicional...');
    await waitMilliseconds(5000);
  }
}

/// 🔧 FUNCIÓN SIMPLIFICADA: Warm-up de Google Sign-In
dynamic warmUpGoogleSignIn() async {
  try {
    debugPrint('📱 Calentando Google Sign-In...');

    final GoogleSignIn googleSignIn = GoogleSignIn(
      clientId:
          '415256305974-9smib8kjpro0f7iacq4ctt2gqk3mdf0u.apps.googleusercontent.com',
      scopes: ['email', 'profile'],
    );

    // Test múltiples de disponibilidad
    for (int i = 0; i < 3; i++) {
      try {
        await googleSignIn.isSignedIn();
        debugPrint('✅ Google Sign-In test $i completado');
      } catch (e) {
        debugPrint('⚠️ Google Sign-In test $i error: $e');
      }
      await waitMilliseconds(300 * (i + 1));
    }

    // Test de usuario actual si existe
    try {
      final account = googleSignIn.currentUser;
      if (account != null) {
        debugPrint('👤 Usuario Google detectado: ${account.email}');

        // Test de autenticación
        try {
          final auth = await account.authentication;
          debugPrint('🔐 Autenticación Google accesible');
        } catch (e) {
          debugPrint('⚠️ Error accediendo autenticación Google: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error verificando usuario Google: $e');
    }

    debugPrint('🎯 Google Sign-In warm-up completado');
  } catch (e) {
    debugPrint('❌ Error en Google Sign-In warm-up: $e');
  }
}

/// 🔧 FUNCIÓN SIMPLIFICADA: Test de usuario actual
dynamic testCurrentUserAccess(FirebaseAuth auth) async {
  try {
    debugPrint('🔍 Testeando acceso a usuario actual...');

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final currentUser = auth.currentUser;
        if (currentUser != null) {
          debugPrint('👤 Usuario actual detectado: ${currentUser.uid}');

          // Test de propiedades
          final properties = ['uid', 'email', 'displayName', 'photoURL'];

          for (final property in properties) {
            try {
              switch (property) {
                case 'uid':
                  final _ = currentUser.uid;
                  break;
                case 'email':
                  final _ = currentUser.email;
                  break;
                case 'displayName':
                  final _ = currentUser.displayName;
                  break;
                case 'photoURL':
                  final _ = currentUser.photoURL;
                  break;
              }
              debugPrint('✅ Propiedad $property accesible');
            } catch (e) {
              debugPrint('⚠️ Error accediendo $property: $e');

              if (e.toString().contains('PigeonUserDetails')) {
                debugPrint('🚨 Error PigeonUserDetails detectado');
                throw e;
              }
            }
          }
        } else {
          debugPrint('👤 No hay usuario actual');
        }

        break; // Éxito
      } catch (e) {
        debugPrint('⚠️ Error en test intento $attempt: $e');

        if (e.toString().contains('PigeonUserDetails') && attempt < 3) {
          await waitMilliseconds(800 * attempt);
          continue;
        }

        if (attempt == 3) {
          debugPrint('⚠️ Test completado con advertencias');
        }
      }
    }

    debugPrint('✅ Test de usuario actual completado');
  } catch (e) {
    debugPrint('❌ Error en test de usuario actual: $e');
  }
}

/// Helper function para esperas
dynamic waitMilliseconds(int milliseconds) async {
  await Future.delayed(Duration(milliseconds: milliseconds));
}

/// 🔧 FUNCIÓN SIMPLIFICADA: Inicializar servicios
dynamic initializeAllServices() async {
  debugPrint('🔧 Inicializando servicios...');

  // 1. Servicios básicos
  connectivityService = ConnectivityService();
  crashlyticsService = FirebaseCrashlyticsService();
  await crashlyticsService.initialize();
  analyticsService = AnalyticsService();

  debugPrint('✅ Servicios básicos inicializados');

  // 2. CacheManager
  cacheManager = CacheManager();
  await cacheManager.init();
  debugPrint('✅ Cache manager inicializado');

  // 3. DailyLimitsService
  dailyLimitsService = DailyLimitsService(
    cacheManager: cacheManager,
    crashlyticsService: crashlyticsService,
  );
  debugPrint('✅ DailyLimitsService inicializado');

  // 4. AdService
  adService = AdService();
  final adServiceInitialized = await adService.initialize();
  if (adServiceInitialized) {
    debugPrint('✅ AdService inicializado');
  } else {
    debugPrint('⚠️ AdService no se pudo inicializar');
  }

  // 5. PurchaseService
  purchaseService = PurchaseService();
  final purchaseInitialized = await purchaseService.initialize();
  if (purchaseInitialized) {
    debugPrint('✅ PurchaseService inicializado');
  } else {
    debugPrint('⚠️ PurchaseService no se pudo inicializar');
  }

  debugPrint('✅ Todos los servicios inicializados');
}

/// 🔧 FUNCIÓN SIMPLIFICADA: Inicializar repositorios
dynamic initializeRepositories() async {
  try {
    debugPrint('🗄️ Inicializando repositorios...');

    // Espera para estabilización
    await waitMilliseconds(1500);

    // 1. AuthRepository
    authRepository = FirebaseAuthRepository(
      crashlyticsService: crashlyticsService,
    );

    // Espera crítica
    await waitMilliseconds(2000);
    debugPrint('✅ AuthRepository inicializado');

    // 2. ShotsRepository
    shotsRepository = FirebaseShotsRepository(
      authRepository: authRepository,
      cacheManager: cacheManager,
      dailyLimitsService: dailyLimitsService,
    );
    debugPrint('✅ ShotsRepository inicializado');

    // 3. PassesRepository
    passesRepository = FirebaseGoalkeeperPassesRepository(
      authRepository: authRepository,
      cacheManager: cacheManager,
    );
    debugPrint('✅ PassesRepository inicializado');

    // 4. MatchesRepository
    matchesRepository = FirebaseMatchesRepository(
      authRepository: authRepository,
      shotsRepository: shotsRepository,
      passesRepository: passesRepository,
      cacheManager: cacheManager,
    );
    debugPrint('✅ MatchesRepository inicializado');

    debugPrint('✅ Todos los repositorios inicializados');
  } catch (e, stack) {
    debugPrint('❌ Error al inicializar repositorios: $e');
    debugPrint('Stack trace: $stack');

    crashlyticsService.recordError(e, stack,
        reason: 'Error inicializando repositorios');
  }
}

class GoalkeeperStatsApp extends StatelessWidget {
  final bool firebaseInitialized;

  const GoalkeeperStatsApp({
    super.key,
    required this.firebaseInitialized,
  });

  @override
  Widget build(BuildContext context) {
    // Si Firebase no está inicializado, mostrar pantalla de error
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
        theme: ThemeData(
          primarySwatch: Colors.green,
          useMaterial3: true,
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF184621),
            brightness: Brightness.light,
          ),
        ),
        darkTheme: ThemeData(
          primarySwatch: Colors.green,
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF9EDE53),
            brightness: Brightness.dark,
          ),
        ),
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
}
