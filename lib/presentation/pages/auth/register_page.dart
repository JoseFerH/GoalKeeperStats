import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:goalkeeper_stats/presentation/blocs/auth/auth_bloc.dart';
import 'package:goalkeeper_stats/presentation/blocs/auth/auth_event.dart';
import 'package:goalkeeper_stats/presentation/blocs/auth/auth_state.dart';
import 'package:goalkeeper_stats/presentation/pages/dashboard/dashboard_page.dart';
import 'package:goalkeeper_stats/services/analytics_service.dart';
import 'package:provider/provider.dart';
import 'package:goalkeeper_stats/services/connectivity_service.dart';

/// Página de registro para nuevos usuarios
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _acceptTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthenticatedState) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => DashboardPage(user: state.user),
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
                    size: 60,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 32),

                // Título
                const Text(
                  'Crear Cuenta',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // Descripción
                const Text(
                  'Únete a la comunidad de porteros y mejora tu rendimiento',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 32),

                // Formulario de registro
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
                          // Campo de nombre
                          TextFormField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Nombre completo',
                              prefixIcon: Icon(Icons.person),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Por favor ingresa tu nombre';
                              }
                              if (value.trim().length < 2) {
                                return 'El nombre debe tener al menos 2 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Campo de email
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email),
                              border: OutlineInputBorder(),
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
                          const SizedBox(height: 16),

                          // Campo de contraseña
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
                                return 'Por favor ingresa una contraseña';
                              }
                              if (value.length < 6) {
                                return 'La contraseña debe tener al menos 6 caracteres';
                              }
                              if (!RegExp(r'^(?=.*[a-zA-Z])(?=.*[0-9])')
                                  .hasMatch(value)) {
                                return 'La contraseña debe contener letras y números';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Campo de confirmar contraseña
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: !_isConfirmPasswordVisible,
                            decoration: InputDecoration(
                              labelText: 'Confirmar contraseña',
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isConfirmPasswordVisible
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isConfirmPasswordVisible =
                                        !_isConfirmPasswordVisible;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor confirma tu contraseña';
                              }
                              if (value != _passwordController.text) {
                                return 'Las contraseñas no coinciden';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Checkbox de términos y condiciones
                          Row(
                            children: [
                              Checkbox(
                                value: _acceptTerms,
                                onChanged: (value) {
                                  setState(() {
                                    _acceptTerms = value ?? false;
                                  });
                                },
                                activeColor: Colors.green,
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _acceptTerms = !_acceptTerms;
                                    });
                                  },
                                  child: const Text(
                                    'Acepto los términos y condiciones de uso',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Botón de registrarse
                          ElevatedButton(
                            onPressed: _acceptTerms ? _handleRegister : null,
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
                              disabledBackgroundColor: Colors.grey,
                            ),
                            child: const Text(
                              'Registrarse',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
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

                // Botón de registro con Google
                _buildGoogleSignUpButton(context),

                const SizedBox(height: 24),

                // Link para ir al login
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    '¿Ya tienes una cuenta? Inicia sesión',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Nota sobre versión gratuita
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
                          'Comenzarás con una cuenta gratuita con funciones limitadas. Podrás actualizar a Premium en cualquier momento.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
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

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Debes aceptar los términos y condiciones para continuar'),
          backgroundColor: Colors.orange,
        ),
      );
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
      AnalyticsService()
          .logEvent(name: 'register_attempt', parameters: {'method': 'email'});

      // Crear evento de registro
      context.read<AuthBloc>().add(
            RegisterWithEmailPasswordEvent(
              email: _emailController.text.trim(),
              password: _passwordController.text,
              displayName: _nameController.text.trim(),
            ),
          );
    } catch (e) {
      debugPrint("Error al registrarse: $e");
      // Si hay error obteniendo el servicio, continuar con el registro
      AnalyticsService()
          .logEvent(name: 'register_attempt', parameters: {'method': 'email'});

      context.read<AuthBloc>().add(
            RegisterWithEmailPasswordEvent(
              email: _emailController.text.trim(),
              password: _passwordController.text,
              displayName: _nameController.text.trim(),
            ),
          );
    }
  }

  Widget _buildGoogleSignUpButton(BuildContext context) {
    void attemptGoogleSignUp() async {
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

        AnalyticsService().logEvent(
            name: 'register_attempt', parameters: {'method': 'google'});

        context.read<AuthBloc>().add(SignInWithGoogleEvent());
      } catch (e) {
        debugPrint("Error al verificar conectividad: $e");
        // Si hay error obteniendo el servicio, continuar con el registro
        AnalyticsService().logEvent(
            name: 'register_attempt', parameters: {'method': 'google'});

        context.read<AuthBloc>().add(SignInWithGoogleEvent());
      }
    }

    return ElevatedButton(
      onPressed: attemptGoogleSignUp,
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
            'Registrarse con Google',
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
