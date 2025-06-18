import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:goalkeeper_stats/presentation/blocs/auth/auth_bloc.dart';
import 'package:goalkeeper_stats/presentation/blocs/auth/auth_event.dart';
import 'package:goalkeeper_stats/presentation/blocs/auth/auth_state.dart';
import 'package:goalkeeper_stats/presentation/pages/auth/login_page.dart';
import 'package:goalkeeper_stats/presentation/pages/dashboard/dashboard_page.dart';
import 'package:goalkeeper_stats/services/connectivity_service.dart';
import 'package:goalkeeper_stats/services/firebase_crashlytics_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

/// Splash Screen con pre-loader animado para Goalkeeper Stats App
///
/// Maneja la inicialización de la app y la verificación del estado de autenticación
/// con una interfaz visual atractiva y feedback al usuario
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Controladores de animación
  late AnimationController _logoAnimationController;
  late AnimationController _loadingAnimationController;
  late AnimationController _progressAnimationController;

  // Animaciones
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _loadingOpacityAnimation;
  late Animation<double> _progressAnimation;

  // Control de estado
  bool _isInitialized = false;
  String _currentMessage = 'Iniciando aplicación...';
  double _progress = 0.0;

  // Lista de mensajes de carga
  final List<String> _loadingMessages = [
    'Iniciando aplicación...',
    'Conectando con Firebase...',
    'Verificando conectividad...',
    'Configurando servicios...',
    'Verificando autenticación...',
    '¡Listo para atajar!',
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startInitializationProcess();
  }

  /// Inicializar todas las animaciones
  void _initializeAnimations() {
    // Animación del logo (fade in + scale)
    _logoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _logoFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _logoScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
    ));

    // Animación del loading
    _loadingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _loadingOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _loadingAnimationController,
      curve: Curves.easeIn,
    ));

    // Animación del progreso
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.easeOut,
    ));
  }

  /// Proceso de inicialización completo
  Future<void> _startInitializationProcess() async {
    try {
      // Paso 1: Iniciar animación del logo
      _logoAnimationController.forward();
      await Future.delayed(const Duration(milliseconds: 800));

      // Paso 2: Mostrar elementos de carga
      _loadingAnimationController.forward();
      await Future.delayed(const Duration(milliseconds: 400));

      // Paso 3: Proceso de inicialización por pasos
      await _initializeStep(0, 'Iniciando aplicación...', () async {
        await Future.delayed(const Duration(milliseconds: 500));
      });

      await _initializeStep(1, 'Conectando con Firebase...', () async {
        // Verificar que Firebase esté inicializado
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp();
        }
      });

      await _initializeStep(2, 'Verificando conectividad...', () async {
        // Verificar conectividad
        final connectivityService =
            Provider.of<ConnectivityService>(context, listen: false);
        await connectivityService.checkConnectivity();
      });

      await _initializeStep(3, 'Configurando servicios...', () async {
        // Inicializar servicios adicionales (Analytics, Crashlytics, etc.)
        await _initializeServices();
      });

      await _initializeStep(4, 'Verificando autenticación...', () async {
        // Verificar estado de autenticación
        if (mounted) {
          context.read<AuthBloc>().add(CheckAuthStatusEvent());
        }
      });

      await _initializeStep(5, '¡Listo para atajar!', () async {
        await Future.delayed(const Duration(milliseconds: 800));
      });

      // Marcar como inicializado
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error durante la inicialización: $e');

      // En caso de error, continuar con la inicialización básica
      if (mounted) {
        _updateMessage('Error en inicialización, continuando...');
        await Future.delayed(const Duration(milliseconds: 1000));

        setState(() {
          _isInitialized = true;
        });

        // Verificar autenticación como fallback
        context.read<AuthBloc>().add(CheckAuthStatusEvent());
      }
    }
  }

  /// Ejecutar un paso de inicialización
  Future<void> _initializeStep(
      int step, String message, Future<void> Function() action) async {
    if (!mounted) return;

    _updateMessage(message);
    _updateProgress(step / (_loadingMessages.length - 1));

    try {
      await action();
    } catch (e) {
      debugPrint('Error en paso $step: $e');
      // Continuar con el siguiente paso aunque haya error
    }

    await Future.delayed(const Duration(milliseconds: 400));
  }

  /// Actualizar mensaje de carga
  void _updateMessage(String message) {
    if (mounted) {
      setState(() {
        _currentMessage = message;
      });
    }
  }

  /// Actualizar progreso
  void _updateProgress(double progress) {
    if (mounted) {
      setState(() {
        _progress = progress;
      });
      _progressAnimationController.forward();
    }
  }

  /// Inicializar servicios adicionales
  Future<void> _initializeServices() async {
    try {
      // Inicializar Firebase Crashlytics si está disponible
      final crashlyticsService = FirebaseCrashlyticsService();
      // Configuraciones adicionales de servicios
    } catch (e) {
      debugPrint('Error inicializando servicios: $e');
    }
  }

  @override
  void dispose() {
    _logoAnimationController.dispose();
    _loadingAnimationController.dispose();
    _progressAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (!_isInitialized) return;

        // Solo navegar después de que la inicialización esté completa
        if (state is AuthenticatedState) {
          debugPrint('Usuario autenticado, navegando al dashboard...');
          _navigateToPage(DashboardPage(user: state.user));
        } else if (state is UnauthenticatedState) {
          debugPrint('Usuario no autenticado, navegando al login...');
          _navigateToPage(const LoginPage());
        } else if (state is AuthErrorState) {
          debugPrint('Error de autenticación: ${state.message}');
          // En caso de error, ir al login
          _navigateToPage(const LoginPage());
        }
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.green[700]!,
                Colors.green[900]!,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo animado
                      _buildAnimatedLogo(),

                      const SizedBox(height: 40),

                      // Título de la app
                      _buildAppTitle(),

                      const SizedBox(height: 60),

                      // Elementos de carga
                      _buildLoadingElements(),
                    ],
                  ),
                ),

                // Footer con información adicional
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Widget del logo animado
  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: _logoAnimationController,
      builder: (context, child) {
        return Opacity(
          opacity: _logoFadeAnimation.value,
          child: Transform.scale(
            scale: _logoScaleAnimation.value,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.sports_soccer,
                size: 60,
                color: Colors.green,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Título de la aplicación
  Widget _buildAppTitle() {
    return AnimatedBuilder(
      animation: _logoAnimationController,
      builder: (context, child) {
        return Opacity(
          opacity: _logoFadeAnimation.value,
          child: Column(
            children: [
              Text(
                'Goalkeeper Stats',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.3),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tu rendimiento, tu evolución',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Elementos de carga (mensaje, progreso, spinner)
  Widget _buildLoadingElements() {
    return AnimatedBuilder(
      animation: _loadingAnimationController,
      builder: (context, child) {
        return Opacity(
          opacity: _loadingOpacityAnimation.value,
          child: Column(
            children: [
              // Spinner de carga
              _buildLoadingSpinner(),

              const SizedBox(height: 24),

              // Mensaje de estado
              _buildStatusMessage(),

              const SizedBox(height: 16),

              // Barra de progreso
              _buildProgressBar(),
            ],
          ),
        );
      },
    );
  }

  /// Spinner de carga personalizado
  Widget _buildLoadingSpinner() {
    return SizedBox(
      width: 40,
      height: 40,
      child: CircularProgressIndicator(
        valueColor:
            AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.8)),
        strokeWidth: 3,
      ),
    );
  }

  /// Mensaje de estado actual
  Widget _buildStatusMessage() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        _currentMessage,
        key: ValueKey(_currentMessage),
        style: TextStyle(
          fontSize: 16,
          color: Colors.white.withOpacity(0.9),
          fontWeight: FontWeight.w400,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Barra de progreso
  Widget _buildProgressBar() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.7,
      height: 4,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        color: Colors.white.withOpacity(0.3),
      ),
      child: AnimatedBuilder(
        animation: _progressAnimation,
        builder: (context, child) {
          return FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _progress,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }

  /// Footer con información adicional
  Widget _buildFooter() {
    return AnimatedBuilder(
      animation: _loadingAnimationController,
      builder: (context, child) {
        return Opacity(
          opacity: _loadingOpacityAnimation.value * 0.7,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Text(
                  'Versión 1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '© 2024 Goalkeeper Stats App',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Navegar a la página correspondiente con animación
  void _navigateToPage(Widget page) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => page,
            transitionDuration: const Duration(milliseconds: 600),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              const begin = Offset(0.0, 1.0);
              const end = Offset.zero;
              const curve = Curves.easeInOut;

              var tween = Tween(begin: begin, end: end).chain(
                CurveTween(curve: curve),
              );

              var offsetAnimation = animation.drive(tween);
              var fadeAnimation = animation.drive(
                Tween(begin: 0.0, end: 1.0).chain(
                  CurveTween(curve: curve),
                ),
              );

              return SlideTransition(
                position: offsetAnimation,
                child: FadeTransition(
                  opacity: fadeAnimation,
                  child: child,
                ),
              );
            },
          ),
        );
      }
    });
  }
}
