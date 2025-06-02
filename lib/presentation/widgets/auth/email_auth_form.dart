import 'package:flutter/material.dart';
import 'package:goalkeeper_stats/presentation/widgets/auth/password_field.dart';

/// Widget reutilizable para formularios de autenticación con email
class EmailAuthForm extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController? confirmPasswordController;
  final TextEditingController? nameController;
  final VoidCallback onSubmit;
  final String submitButtonText;
  final bool isRegistration;
  final bool isLoading;
  final Widget? additionalFields;
  final Widget? footer;

  const EmailAuthForm({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    this.confirmPasswordController,
    this.nameController,
    required this.onSubmit,
    required this.submitButtonText,
    this.isRegistration = false,
    this.isLoading = false,
    this.additionalFields,
    this.footer,
  });

  @override
  State<EmailAuthForm> createState() => _EmailAuthFormState();
}

class _EmailAuthFormState extends State<EmailAuthForm> {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: widget.formKey,
          child: Column(
            children: [
              // Campo de nombre (solo en registro)
              if (widget.isRegistration && widget.nameController != null) ...[
                TextFormField(
                  controller: widget.nameController,
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
              ],

              // Campo de email
              TextFormField(
                controller: widget.emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                validator: _validateEmail,
              ),
              const SizedBox(height: 16),

              // Campo de contraseña
              PasswordField(
                controller: widget.passwordController,
                labelText: 'Contraseña',
                showStrengthIndicator: widget.isRegistration,
                validator: widget.isRegistration
                    ? _validatePasswordForRegistration
                    : _validatePasswordForLogin,
              ),

              // Campo de confirmar contraseña (solo en registro)
              if (widget.isRegistration &&
                  widget.confirmPasswordController != null) ...[
                const SizedBox(height: 16),
                PasswordField(
                  controller: widget.confirmPasswordController!,
                  labelText: 'Confirmar contraseña',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor confirma tu contraseña';
                    }
                    if (value != widget.passwordController.text) {
                      return 'Las contraseñas no coinciden';
                    }
                    return null;
                  },
                ),
              ],

              // Campos adicionales (si se proporcionan)
              if (widget.additionalFields != null) ...[
                const SizedBox(height: 16),
                widget.additionalFields!,
              ],

              const SizedBox(height: 24),

              // Botón de envío
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: widget.isLoading ? null : widget.onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    disabledBackgroundColor: Colors.grey,
                  ),
                  child: widget.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          widget.submitButtonText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              // Footer (si se proporciona)
              if (widget.footer != null) ...[
                const SizedBox(height: 16),
                widget.footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Por favor ingresa tu email';
    }

    // Validación básica de email
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Por favor ingresa un email válido';
    }

    return null;
  }

  String? _validatePasswordForLogin(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa tu contraseña';
    }
    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    return null;
  }

  String? _validatePasswordForRegistration(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa una contraseña';
    }
    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    if (!RegExp(r'^(?=.*[a-zA-Z])(?=.*[0-9])').hasMatch(value)) {
      return 'La contraseña debe contener letras y números';
    }
    return null;
  }
}

/// Widget helper para crear un divisor con texto
class AuthDivider extends StatelessWidget {
  final String text;

  const AuthDivider({super.key, this.text = 'O'});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white30,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            text,
            style: const TextStyle(
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
    );
  }
}

/// Widget helper para botones de Google
class GoogleAuthButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final bool isLoading;

  const GoogleAuthButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
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
        disabledBackgroundColor: Colors.grey[300],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
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
          Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget helper para información/tips
class InfoCard extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;
  final Color? backgroundColor;

  const InfoCard({
    super.key,
    required this.title,
    required this.content,
    this.icon = Icons.info_outline,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
