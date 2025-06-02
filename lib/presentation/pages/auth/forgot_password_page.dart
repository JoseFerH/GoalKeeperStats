import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:goalkeeper_stats/presentation/blocs/auth/auth_bloc.dart';
import 'package:goalkeeper_stats/presentation/blocs/auth/auth_event.dart';
import 'package:goalkeeper_stats/presentation/blocs/auth/auth_state.dart';
import 'package:goalkeeper_stats/services/analytics_service.dart';
import 'package:provider/provider.dart';
import 'package:goalkeeper_stats/services/connectivity_service.dart';

/// Página para recuperación de contraseña
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is PasswordResetSentState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Se ha enviado un enlace de recuperación a ${state.email}. '
                'Revisa tu bandeja de entrada y spam.',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 6),
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

        if (state is AuthErrorState) {
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
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Recuperar Contraseña',
              style: TextStyle(color: Colors.white),
            ),
          ),
          body: Stack(
            children: [
              _buildContent(context),
              if (state is AuthLoadingState)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
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
                // Icono de recuperación
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
                    Icons.lock_reset,
                    size: 60,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 32),

                // Título
                const Text(
                  'Recuperar Contraseña',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // Descripción
                const Text(
                  'Ingresa tu email y te enviaremos un enlace para restablecer tu contraseña',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 32),

                // Formulario
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
                          // Campo de email
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email),
                              border: OutlineInputBorder(),
                              hintText: 'ejemplo@email.com',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Por favor ingresa tu email';
                              }
                              // Validación básica de email
                              final emailRegex =
                                  RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                              if (!emailRegex.hasMatch(value.trim())) {
                                return 'Por favor ingresa un email válido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Botón de enviar
                          ElevatedButton(
                            onPressed: _handleSendReset,
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
                              'Enviar Enlace de Recuperación',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Información adicional
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Instrucciones:',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '1. Revisa tu bandeja de entrada\n'
                        '2. Si no encuentras el email, revisa la carpeta de spam\n'
                        '3. Haz clic en el enlace del email\n'
                        '4. Crea una nueva contraseña segura',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Link para volver al login
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    '¿Recordaste tu contraseña? Volver al inicio de sesión',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleSendReset() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      // Verificar conectividad
      final connectivityService =
          Provider.of<ConnectivityService>(context, listen: false);
      final isConnected = await connectivityService.checkConnectivity();

      if (!isConnected) {
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
      AnalyticsService().logEvent(
        name: 'password_reset_requested',
        parameters: {'email': _emailController.text.trim()},
      );

      // Crear evento de recuperación de contraseña
      context.read<AuthBloc>().add(
            SendPasswordResetEvent(email: _emailController.text.trim()),
          );
    } catch (e) {
      debugPrint("Error al enviar recuperación: $e");
      // Si hay error obteniendo el servicio, continuar con la recuperación
      AnalyticsService().logEvent(
        name: 'password_reset_requested',
        parameters: {'email': _emailController.text.trim()},
      );

      context.read<AuthBloc>().add(
            SendPasswordResetEvent(email: _emailController.text.trim()),
          );
    }
  }
}
