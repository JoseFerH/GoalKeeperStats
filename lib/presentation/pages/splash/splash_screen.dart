// lib/presentation/pages/splash/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;

/// Pantalla de splash con pre-loader animado para Goalkeeper Stats
class SplashScreen extends StatefulWidget {
  final Future<void> Function() onInitialize;
  final VoidCallback onComplete;

  const SplashScreen({
    super.key,
    required this.onInitialize,
    required this.onComplete,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Controladores de animación
  late AnimationController _logoController;
  late AnimationController _loaderController;
  late AnimationController _textController;
  late AnimationController _progressController;

  // Animaciones
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _loaderRotation;
  late Animation<double> _textOpacity;
  late Animation<double> _progressValue;

  // Estados del splash
  bool _isInitializing = false;
  bool _hasError = false;
  String _currentStep = 'Iniciando...';
  double _progress = 0.0;

  // Lista de pasos de inicialización
  final List<String> _initSteps = [
    'Iniciando aplicación...',
    'Conectando con Firebase...',
    'Calentando servicios...',
    'Inicializando repositorios...',
    'Configurando servicios...',
    'Preparando interfaz...',
    '¡Listo para jugar!'
  ];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startSplashSequence();
  }

  void _setupAnimations() {
    // Controlador para el logo
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Controlador para el loader circular
    _loaderController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    // Controlador para el texto
    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Controlador para la barra de progreso
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Animación del logo
    _logoScale = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));

    _logoOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    ));

    // Animación del loader
    _loaderRotation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(_loaderController);

    // Animación del texto
    _textOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeInOut,
    ));

    // Animación del progreso
    _progressValue = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _startSplashSequence() async {
    try {
      // Vibración suave al iniciar
      HapticFeedback.lightImpact();

      // Paso 1: Mostrar logo
      await _logoController.forward();
      await Future.delayed(const Duration(milliseconds: 500));

      // Paso 2: Mostrar texto de carga
      _textController.forward();
      await Future.delayed(const Duration(milliseconds: 300));

      // Paso 3: Iniciar proceso de inicialización
      setState(() {
        _isInitializing = true;
      });

      await _performInitializationWithProgress();

      // Paso 4: Esperar un momento antes de continuar
      await Future.delayed(const Duration(milliseconds: 800));

      // Paso 5: Navegar a la aplicación principal
      if (mounted && !_hasError) {
        widget.onComplete();
      }
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> _performInitializationWithProgress() async {
    for (int i = 0; i < _initSteps.length; i++) {
      if (!mounted) return;

      setState(() {
        _currentStep = _initSteps[i];
        _progress = (i + 1) / _initSteps.length;
      });

      // Animar el progreso
      _progressController.reset();
      await _progressController.forward();

      // Ejecutar inicialización real solo en el paso de Firebase
      if (i == 1) {
        try {
          await widget.onInitialize();
        } catch (e) {
          throw e;
        }
      } else {
        // Simular tiempo de otros pasos
        await Future.delayed(Duration(
          milliseconds: 300 + (math.Random().nextInt(400)),
        ));
      }

      // Pequeña vibración en pasos importantes
      if (i == 1 || i == _initSteps.length - 1) {
        HapticFeedback.selectionClick();
      }
    }
  }

  void _handleError(dynamic error) {
    if (!mounted) return;

    setState(() {
      _hasError = true;
      _currentStep = 'Error al inicializar';
    });

    // Vibración de error
    HapticFeedback.heavyImpact();

    // Mostrar dialog de error después de un momento
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        _showErrorDialog(error.toString());
      }
    });
  }

  void _showErrorDialog(String error) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Error de Inicialización'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No se pudo inicializar la aplicación correctamente.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text('Posibles soluciones:'),
            const SizedBox(height: 8),
            const Text('• Verifica tu conexión a internet'),
            const Text('• Reinicia la aplicación'),
            const Text('• Actualiza la app si hay versiones disponibles'),
            const SizedBox(height: 16),
            if (error.isNotEmpty) ...[
              const Text(
                'Detalles técnicos:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                error,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (mounted) {
                Navigator.of(context).pop();
                SystemNavigator.pop();
              }
            },
            child: const Text('Cerrar App'),
          ),
          ElevatedButton(
            onPressed: () {
              if (mounted) {
                Navigator.of(context).pop();
                _retryInitialization();
              }
            },
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  void _retryInitialization() {
    setState(() {
      _hasError = false;
      _isInitializing = false;
      _currentStep = 'Iniciando...';
      _progress = 0.0;
    });

    // Reiniciar animaciones
    _logoController.reset();
    _textController.reset();
    _progressController.reset();

    // Reiniciar secuencia
    _startSplashSequence();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _loaderController.dispose();
    _textController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.shortestSide > 600;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF388E3C), // Verde principal
              Color(0xFF1B5E20), // Verde oscuro
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Área principal con logo y loader
              Expanded(
                flex: 3,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo animado
                      AnimatedBuilder(
                        animation: _logoController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _logoScale.value,
                            child: Opacity(
                              opacity: _logoOpacity.value,
                              child: _buildLogo(isTablet),
                            ),
                          );
                        },
                      ),

                      SizedBox(height: isTablet ? 40 : 30),

                      // Título de la app
                      AnimatedBuilder(
                        animation: _textController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _textOpacity.value,
                            child: Text(
                              'Goalkeeper Stats',
                              style: TextStyle(
                                fontSize: isTablet ? 32 : 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                          );
                        },
                      ),

                      SizedBox(height: isTablet ? 16 : 12),

                      // Subtítulo
                      AnimatedBuilder(
                        animation: _textController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _textOpacity.value * 0.8,
                            child: Text(
                              'Tu asistente de portería',
                              style: TextStyle(
                                fontSize: isTablet ? 18 : 16,
                                color: Colors.white70,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Área de loading
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Loader circular animado
                    if (_isInitializing) ...[
                      AnimatedBuilder(
                        animation: _loaderController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _loaderRotation.value,
                            child: Container(
                              width: isTablet ? 50 : 40,
                              height: isTablet ? 50 : 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white30,
                                  width: 3,
                                ),
                              ),
                              child: CustomPaint(
                                painter: LoaderPainter(
                                  progress: _hasError ? 0.0 : _progress,
                                  hasError: _hasError,
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      SizedBox(height: isTablet ? 24 : 20),

                      // Barra de progreso
                      Container(
                        width: screenSize.width * 0.6,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: AnimatedBuilder(
                          animation: _progressValue,
                          builder: (context, child) {
                            return FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: _progress,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _hasError ? Colors.red : Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      SizedBox(height: isTablet ? 16 : 12),

                      // Texto de estado
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _currentStep,
                          key: ValueKey(_currentStep),
                          style: TextStyle(
                            fontSize: isTablet ? 16 : 14,
                            color: _hasError
                                ? Colors.red.shade200
                                : Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      SizedBox(height: isTablet ? 8 : 6),

                      // Porcentaje
                      Text(
                        '${(_progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: isTablet ? 14 : 12,
                          color: Colors.white54,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Footer
              Padding(
                padding: EdgeInsets.only(bottom: isTablet ? 24 : 16),
                child: Text(
                  'Versión 1.0.0',
                  style: TextStyle(
                    fontSize: isTablet ? 12 : 10,
                    color: Colors.white38,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(bool isTablet) {
    final size = isTablet ? 120.0 : 100.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(
        Icons.sports_soccer,
        size: size * 0.6,
        color: const Color(0xFF388E3C),
      ),
    );
  }
}

/// Custom painter para el loader circular con progreso
class LoaderPainter extends CustomPainter {
  final double progress;
  final bool hasError;

  LoaderPainter({
    required this.progress,
    required this.hasError,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    final paint = Paint()
      ..color = hasError ? Colors.red : Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Dibujar el arco de progreso
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Empezar desde arriba
      2 * math.pi * progress, // Progreso actual
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(LoaderPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.hasError != hasError;
  }
}
