import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:goalkeeper_stats/domain/repositories/auth_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/matches_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/shots_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/goalkeeper_passes_repository.dart';
import 'package:goalkeeper_stats/data/repositories/firebase_auth_repository.dart';
import 'package:goalkeeper_stats/data/repositories/firebase_matches_repository.dart';
import 'package:goalkeeper_stats/data/repositories/firebase_shots_repository.dart';
import 'package:goalkeeper_stats/data/repositories/firebase_goalkeeper_passes_repository.dart';
import 'package:goalkeeper_stats/firebase_options.dart';
import 'package:goalkeeper_stats/services/cache_manager.dart';
import 'package:goalkeeper_stats/presentation/pages/auth/login_page.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'; // <-- Añadir esto

// Variables globales para los repositorios
late AuthRepository authRepository;
late MatchesRepository matchesRepository;
late ShotsRepository shotsRepository;
late GoalkeeperPassesRepository passesRepository;
late CacheManager cacheManager;

Future<void> main() async {
  // Inicialización de Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // Detectar si es tablet o teléfono (basado en tamaño de pantalla)
  final window = WidgetsBinding.instance.window;
  final size = window.physicalSize / window.devicePixelRatio;
  final bool isTablet = size.shortestSide > 600;

  // Configurar orientación según tipo de dispositivo
  if (isTablet) {
    // Permitir orientación horizontal para tablets
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  } else {
    // Solo vertical para teléfonos
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Inicializar Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Configurar Crashlytics
    if (Platform.isAndroid || Platform.isIOS) {
      // Pasar todos los errores de Flutter a Crashlytics
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;

      // En modo debug, imprime los errores directamente
      if (kDebugMode) {
        await FirebaseCrashlytics.instance
            .setCrashlyticsCollectionEnabled(false);
      } else {
        await FirebaseCrashlytics.instance
            .setCrashlyticsCollectionEnabled(true);
      }
    }

    // Inicializar gestor de caché
    cacheManager = CacheManager();

    // Inicializar repositorios Firebase
    authRepository = FirebaseAuthRepository();
    matchesRepository = FirebaseMatchesRepository();
    shotsRepository = FirebaseShotsRepository();
    passesRepository = FirebaseGoalkeeperPassesRepository();

    debugPrint('Firebase inicializado correctamente');
  } catch (e) {
    debugPrint('Error al inicializar Firebase: $e');
    // En una situación real, podríamos mostrar un diálogo de error fatal
    // o incluso forzar la actualización de la app si es necesario
    if (Platform.isAndroid || Platform.isIOS) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
    }
  }

  // Capturar errores no manejados en la zona asíncrona
  PlatformDispatcher.instance.onError = (error, stack) {
    if (Platform.isAndroid || Platform.isIOS) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
    return true;
  };

  // Iniciar la aplicación
  runApp(const GoalkeeperStatsApp());
}

class GoalkeeperStatsApp extends StatelessWidget {
  const GoalkeeperStatsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: authRepository),
        Provider<MatchesRepository>.value(value: matchesRepository),
        Provider<ShotsRepository>.value(value: shotsRepository),
        Provider<GoalkeeperPassesRepository>.value(value: passesRepository),
        Provider<CacheManager>.value(value: cacheManager),
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
        themeMode: ThemeMode.system, // Usar tema del sistema
        home: const LoginPage(), // Comienza con la página de login
      ),
    );
  }
}
