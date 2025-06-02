import 'package:flutter/material.dart';

/// Widget reutilizable para campos de contraseña
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final FormFieldValidator<String>? validator;
  final bool showStrengthIndicator;
  final VoidCallback? onChanged;

  const PasswordField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.validator,
    this.showStrengthIndicator = false,
    this.onChanged,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _isPasswordVisible = false;
  PasswordStrength _strength = PasswordStrength.weak;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPasswordChanged);
    super.dispose();
  }

  void _onPasswordChanged() {
    if (widget.showStrengthIndicator) {
      setState(() {
        _strength = _calculatePasswordStrength(widget.controller.text);
      });
    }
    if (widget.onChanged != null) {
      widget.onChanged!();
    }
  }

  PasswordStrength _calculatePasswordStrength(String password) {
    if (password.isEmpty) return PasswordStrength.weak;

    int score = 0;

    // Longitud
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;

    // Contiene minúsculas
    if (password.contains(RegExp(r'[a-z]'))) score++;

    // Contiene mayúsculas
    if (password.contains(RegExp(r'[A-Z]'))) score++;

    // Contiene números
    if (password.contains(RegExp(r'[0-9]'))) score++;

    // Contiene caracteres especiales
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score++;

    if (score <= 2) return PasswordStrength.weak;
    if (score <= 4) return PasswordStrength.medium;
    return PasswordStrength.strong;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          obscureText: !_isPasswordVisible,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.lock),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
            ),
          ),
          validator: widget.validator,
        ),
        if (widget.showStrengthIndicator &&
            widget.controller.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildStrengthIndicator(),
        ],
      ],
    );
  }

  Widget _buildStrengthIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: _strength.value,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(_strength.color),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _strength.label,
              style: TextStyle(
                fontSize: 12,
                color: _strength.color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _getStrengthTips(),
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  String _getStrengthTips() {
    final password = widget.controller.text;
    List<String> tips = [];

    if (password.length < 8) tips.add('al menos 8 caracteres');
    if (!password.contains(RegExp(r'[a-z]'))) tips.add('minúsculas');
    if (!password.contains(RegExp(r'[A-Z]'))) tips.add('mayúsculas');
    if (!password.contains(RegExp(r'[0-9]'))) tips.add('números');
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')))
      tips.add('símbolos');

    if (tips.isEmpty) {
      return '¡Contraseña segura!';
    } else {
      return 'Añade: ${tips.join(', ')}';
    }
  }
}

/// Enum para la fuerza de la contraseña
enum PasswordStrength {
  weak(0.3, Colors.red, 'Débil'),
  medium(0.6, Colors.orange, 'Media'),
  strong(1.0, Colors.green, 'Fuerte');

  const PasswordStrength(this.value, this.color, this.label);

  final double value;
  final Color color;
  final String label;
}
