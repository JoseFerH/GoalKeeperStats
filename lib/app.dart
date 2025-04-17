import 'package:flutter/material.dart';
import 'package:goalkeeper_stats/core/theme/app_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:goalkeeper_stats/presentation/pages/auth/login_page.dart';
import 'package:provider/provider.dart';
import 'package:goalkeeper_stats/domain/repositories/auth_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/shots_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/matches_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/goalkeeper_passes_repository.dart';
import 'package:goalkeeper_stats/services/cache_manager.dart';
import 'package:goalkeeper_stats/services/connectivity_service.dart';
import 'package:goalkeeper_stats/services/firebase_crashlytics_service.dart';

/// Clase principal de la aplicación
///
/// Define la estructura global, temas, y punto de entrada para la navegación.
/// Aquí se configuran aspectos globales como localización e idiomas.
class App extends StatelessWidget {
  final AuthRepository authRepository;
  final ShotsRepository shotsRepository;
  final MatchesRepository matchesRepository;
  final GoalkeeperPassesRepository passesRepository;
  final CacheManager cacheManager;

  const App({
    super.key,
    required this.authRepository,
    required this.shotsRepository,
    required this.matchesRepository,
    required this.passesRepository,
    required this.cacheManager,
  });

  @override
  Widget build(BuildContext context) {
    // Configurar repositorios que se inyectarán en la aplicación
    return MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: authRepository),
        Provider<ShotsRepository>.value(value: shotsRepository),
        Provider<MatchesRepository>.value(value: matchesRepository),
        Provider<GoalkeeperPassesRepository>.value(value: passesRepository),
        Provider<CacheManager>.value(value: cacheManager),
        Provider<ConnectivityService>(
          create: (_) => ConnectivityService(),
          dispose: (_, service) => service.dispose(),
        ),
        Provider<FirebaseCrashlyticsService>(
          create: (_) => FirebaseCrashlyticsService(),
        ),
      ],
      child: MaterialApp(
        // Título de la aplicación
        title: 'Goalkeeper Stats',

        // Quita el banner de debug
        debugShowCheckedModeBanner: false,

        // Configuración de temas (claro/oscuro)
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,

        // Usar el tema del sistema (cambia automáticamente)
        themeMode: ThemeMode.system,

        // Soporte para múltiples idiomas
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en', ''), // Inglés
          Locale('es', ''), // Español
        ],

        // Página inicial
        home: const LoginPage(),
      ),
    );
  }
}
