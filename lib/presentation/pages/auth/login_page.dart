// lib/presentation/pages/auth/login_page.dart
// 🔧 SOLUCIÓN: LoginPage mejorado para evitar race conditions

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:goalkeeper_stats/services/analytics_service.dart';
import 'package:goalkeeper_stats/services/connectivity_service.dart';
import 'package:goalkeeper_stats/presentation/blocs/auth/auth_bloc.dart';
import 'package:goalkeeper_stats/presentation/blocs/auth/auth_event.dart';
import 'package:goalkeeper_stats/presentation/blocs/auth/auth_state.dart';
import 'package:goalkeeper_stats/presentation/pages/dashboard/dashboard_page.dart';
import 'package:goalkeeper_stats/presentation/pages/auth/register_page.dart';
import 'package:goalkeeper_stats/presentation/pages/auth/forgot_password_page.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;

  // 🔧 NUEVA VARIABLE: Control de inicialización
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();

    // 🔧 SOLUCIÓN PRINCIPAL: Inicialización súper robusta con múltiples delays
    _performSuperRobustInitialization();
  }

  /// 🔧 MÉTODO NUEVO: Inicialización súper robusta con verificaciones múltiples
  Future<void> _performSuperRobustInitialization() async {
    try {
      debugPrint('🔍 Iniciando inicialización súper robusta de LoginPage...');

      // Espera 1: Widget completamente montado
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      // Espera 2: Firebase Auth debe estar completamente listo
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;

      // Verificación: Estado del BLoC
      final authBlocState = context.read<AuthBloc>().state;
      debugPrint(
          '📊 Estado inicial del AuthBloc: ${authBlocState.runtimeType}');

      // Espera 3: Si el BLoC está en loading, esperar más
      if (authBlocState is AuthLoadingState) {
        debugPrint('⏳ BLoC en loading, esperando estabilización...');
        await Future.delayed(const Duration(milliseconds: 1500));
        if (!mounted) return;
      }

      // Espera 4: Verificación de conectividad (opcional pero útil)
      try {
        final connectivityService =
            Provider.of<ConnectivityService>(context, listen: false);
        final isConnected = await connectivityService.checkConnectivity();
        debugPrint('🌐 Estado de conectividad: $isConnected');
      } catch (e) {
        debugPrint('⚠️ Error verificando conectividad en init: $e');
      }

      // Espera 5: Final - asegurar que todo esté estable
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      // Marcar como inicializado
      _hasInitialized = true;
      debugPrint('✅ LoginPage inicializado completamente');

      // AHORA SÍ: Disparar CheckAuthStatusEvent con Firebase completamente listo
      debugPrint(
          '🚀 Disparando CheckAuthStatusEvent con sistema completamente estable');
      context.read<AuthBloc>().add(CheckAuthStatusEvent());
    } catch (e, stack) {
      debugPrint('❌ Error en inicialización súper robusta: $e');

      // Registrar error pero intentar inicialización básica
      try {
        FirebaseCrashlytics.instance.recordError(e, stack,
            reason: 'Error en inicialización súper robusta de LoginPage');
      } catch (_) {}

      // Fallback: Inicialización básica después de más tiempo
      if (mounted) {
        await Future.delayed(const Duration(seconds: 3));
        if (mounted && !_hasInitialized) {
          _hasInitialized = true;
          context.read<AuthBloc>().add(CheckAuthStatusEvent());
        }
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthenticatedState) {
          debugPrint("Estado autenticado detectado. Navegando al dashboard...");
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => DashboardPage(user: state.user),
            ),
          );
        }

        if (state is AuthErrorState) {
          FirebaseCrashlytics.instance
              .log("Error de autenticación en UI: ${state.message}");

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          body: Stack(
            children: [
              _buildContent(context),
              if (state is AuthLoadingState)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    return Container(
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
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo de la aplicación
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.sports_soccer,
                    size: 80,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 40),

                // Título de la aplicación
                const Text(
                  'Goalkeeper Stats',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // Descripción
                const Text(
                  'Registra, analiza y mejora tu rendimiento como portero',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 40),

                // Formulario de email y contraseña
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor ingresa tu email';
                              }
                              if (!value.contains('@')) {
                                return 'Por favor ingresa un email válido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: const Icon(Icons.lock),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor ingresa tu contraseña';
                              }
                              if (value.length < 6) {
                                return 'La contraseña debe tener al menos 6 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Link de recuperación de contraseña
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ForgotPasswordPage(),
                                  ),
                                );
                              },
                              child: const Text(
                                '¿Olvidaste tu contraseña?',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          ElevatedButton(
                            onPressed: _handleEmailSignIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 32,
                              ),
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Iniciar Sesión',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Divisor
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: Colors.white30,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'O',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: Colors.white30,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Botón de inicio de sesión con Google
                _buildGoogleSignInButton(context),

                const SizedBox(height: 24),

                // Link para registro
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const RegisterPage(),
                      ),
                    );
                  },
                  child: const Text(
                    '¿No tienes una cuenta? Regístrate',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Nota de versión freemium
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Versión gratuita disponible con funciones limitadas. Actualiza a Premium para acceso completo.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 🔧 MÉTODO MEJORADO: Email sign-in con validaciones súper robustas
  void _handleEmailSignIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      // 🔧 VALIDACIÓN 1: Sistema debe estar inicializado
      if (!_hasInitialized) {
        debugPrint('⏳ Sistema aún no inicializado, esperando...');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'La aplicación se está inicializando, por favor espera...'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      // 🔧 VALIDACIÓN 2: Estado del BLoC
      final authBlocState = context.read<AuthBloc>().state;
      if (authBlocState is AuthLoadingState) {
        debugPrint('⏳ AuthBloc ocupado, no procesar email sign-in');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor espera, hay una operación en progreso...'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      // 🔧 VALIDACIÓN 3: Verificar conectividad
      try {
        final connectivityService =
            Provider.of<ConnectivityService>(context, listen: false);
        final isConnected = await connectivityService.checkConnectivity();

        if (!isConnected) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No hay conexión a internet. Por favor, conéctate e intenta nuevamente.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }
      } catch (e) {
        debugPrint("⚠️ Error al verificar conectividad para email: $e");
        // Continuar sin verificación
      }

      // 🔧 VALIDACIÓN 4: Analytics
      try {
        AnalyticsService()
            .logEvent(name: 'login_attempt', parameters: {'method': 'email'});
      } catch (e) {
        debugPrint("⚠️ Error en analytics para email: $e");
      }

      // 🔧 ESPERA FINAL: Para email también, evitar cualquier race condition
      debugPrint('⏳ Preparando email sign-in con sistema estable...');
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      // Crear evento de inicio de sesión
      context.read<AuthBloc>().add(
            SignInWithEmailPasswordEvent(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            ),
          );
    } catch (e) {
      debugPrint("❌ Error en _handleEmailSignIn: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error preparando inicio de sesión: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 🔧 MÉTODO SÚPER MEJORADO: Google Sign-In con todas las validaciones
  Widget _buildGoogleSignInButton(BuildContext context) {
    void attemptSignIn() async {
      try {
        // 🔧 VALIDACIÓN 1: Sistema debe estar completamente inicializado
        if (!_hasInitialized) {
          debugPrint('⏳ Sistema aún no inicializado para Google Sign-In');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'La aplicación se está inicializando, por favor espera...'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }

        // 🔧 VALIDACIÓN 2: Estado del BLoC
        final authBlocState = context.read<AuthBloc>().state;
        if (authBlocState is AuthLoadingState) {
          debugPrint('⏳ AuthBloc ocupado, esperando...');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Por favor espera, la aplicación se está inicializando...'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        // 🔧 VALIDACIÓN 3: Conectividad
        try {
          final connectivityService =
              Provider.of<ConnectivityService>(context, listen: false);
          final isConnected = await connectivityService.checkConnectivity();

          if (!isConnected) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'No hay conexión a internet. Por favor, conéctate e intenta nuevamente.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
            return;
          }
        } catch (e) {
          debugPrint("⚠️ Error al verificar conectividad: $e");
        }

        // 🔧 VALIDACIÓN 4: Analytics
        try {
          AnalyticsService().logEvent(
              name: 'login_attempt', parameters: {'method': 'google'});
        } catch (e) {
          debugPrint("⚠️ Error en analytics: $e");
        }

        // 🔧 ESPERA CRÍTICA: Sistema completamente estable antes de Google Sign-In
        debugPrint(
            '⏳ Preparando Google Sign-In con Firebase completamente estable...');
        await Future.delayed(const Duration(milliseconds: 500));

        if (!mounted) return;

        // Intentar el login
        debugPrint('🚀 Disparando Google Sign-In con sistema súper estable');
        context.read<AuthBloc>().add(SignInWithGoogleEvent());
      } catch (e) {
        debugPrint("❌ Error general en attemptSignIn: $e");

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error iniciando sesión: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }

    return ElevatedButton(
      onPressed: attemptSignIn,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        padding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 24,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        elevation: 5,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/google_logo.png',
            height: 24,
            width: 24,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.g_mobiledata,
                  size: 24, color: Colors.red);
            },
          ),
          const SizedBox(width: 12),
          const Text(
            'Iniciar sesión con Google',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
