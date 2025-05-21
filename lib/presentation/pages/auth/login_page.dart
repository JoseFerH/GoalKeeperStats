import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:goalkeeper_stats/data/repository_provider.dart';
import 'package:goalkeeper_stats/services/analytics_service.dart';
import 'package:goalkeeper_stats/services/connectivity_service.dart';
import 'package:goalkeeper_stats/presentation/blocs/auth/auth_bloc.dart';
import 'package:goalkeeper_stats/presentation/blocs/auth/auth_event.dart';
import 'package:goalkeeper_stats/presentation/blocs/auth/auth_state.dart';
import 'package:goalkeeper_stats/presentation/pages/dashboard/dashboard_page.dart';
import 'package:goalkeeper_stats/core/utils/dependency_injection.dart';

/// Página de inicio de sesión
///
/// Permite a los usuarios iniciar sesión con su cuenta de Google.
/// Es la primera pantalla que ven los usuarios no autenticados.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // Crear e inyectar el AuthBloc con dependencias de Firebase
      create: (context) => AuthBloc(
        authRepository: repositoryProvider.authRepository,
        analyticsService: AnalyticsService(),
        crashlytics: FirebaseCrashlytics.instance,
        connectivityService: repositoryProvider.connectivityService,
      )..add(
          CheckAuthStatusEvent()), // Verificar estado de autenticación al inicio

      child: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          // Navegar al dashboard si el usuario está autenticado
          if (state is AuthenticatedState) {
            debugPrint(
                "Estado autenticado detectado. Navegando al dashboard...");
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) =>  DashboardPage(user: state.user,),
              ),
            );
          }

          // Mostrar mensajes de error
          if (state is AuthErrorState) {
            // Registrar el error para análisis
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
                // Fondo y contenido principal
                _buildContent(context),

                // Indicador de carga
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
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // Gradiente de fondo verde (colores del campo de fútbol)
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
                // Logo de la aplicación (temporalmente usando un icono)
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
                const SizedBox(height: 60),

                // Botón de inicio de sesión con Google
                _buildGoogleSignInButton(context),

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

  Widget _buildGoogleSignInButton(BuildContext context) {
    // Verificar conectividad antes de intentar iniciar sesión
    void attemptSignIn() async {
      try {
        final isConnected =
            await repositoryProvider.connectivityService.checkConnectivity();

        if (!isConnected) {
          // Mostrar mensaje si no hay conexión
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No hay conexión a internet. Por favor, conéctate e intenta nuevamente.'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        // Registrar evento de analítica
        AnalyticsService()
            .logEvent(name: 'login_attempt', parameters: {'method': 'google'});

        // Disparar evento de inicio de sesión con Google
        context.read<AuthBloc>().add(SignInWithGoogleEvent());
      } catch (e) {
        debugPrint("Error al verificar conectividad: $e");
        // Intentar login de todas formas
        context.read<AuthBloc>().add(SignInWithGoogleEvent());
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
          // Logo de Google
          Image.asset(
            'assets/images/google_logo.png',
            height: 24,
            width: 24,
            errorBuilder: (context, error, stackTrace) {
              // Si no se puede cargar el logo, mostrar un ícono alternativo
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
