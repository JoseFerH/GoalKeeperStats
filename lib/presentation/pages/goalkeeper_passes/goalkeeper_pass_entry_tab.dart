import 'package:flutter/material.dart';
import 'package:goalkeeper_stats/data/models/goalkeeper_pass_model.dart';
import 'package:goalkeeper_stats/data/models/match_model.dart';
import 'package:goalkeeper_stats/data/models/position.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/domain/repositories/goalkeeper_passes_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/matches_repository.dart';
import 'package:goalkeeper_stats/presentation/widgets/field_map/pass_field_selector.dart';
import 'package:goalkeeper_stats/core/theme/app_theme.dart';

/// Pestaña para el registro de saques del portero siguiendo un flujo de pasos secuenciales
class GoalkeeperPassEntryTab extends StatefulWidget {
  final UserModel user;
  final MatchModel? match; // Permite recibir un partido preseleccionado
  final MatchesRepository matchesRepository;
  final GoalkeeperPassesRepository passesRepository;
  final Function(String)? onSelectRegisterType; // Añadir este parámetro

  const GoalkeeperPassEntryTab({
    Key? key,
    required this.user,
    required this.passesRepository,
    required this.matchesRepository,
    this.onSelectRegisterType, // Incluirlo en el constructor
    this.match,
    Function? onDataRegistered,
  }) : super(key: key);

  @override
  State<GoalkeeperPassEntryTab> createState() => _GoalkeeperPassEntryTabState();
}

class _GoalkeeperPassEntryTabState extends State<GoalkeeperPassEntryTab> {
  // Estado del saque en proceso de registro
  Position? _selectedEndPosition;
  String _passType = GoalkeeperPassModel.TYPE_HAND; // Por defecto: mano
  String _passResult =
      GoalkeeperPassModel.RESULT_SUCCESSFUL; // Por defecto: exitoso
  String? _matchId;
  int? _minute;
  String? _notes;

  // Categorías específicas para el saque
  String _passDistance = 'corto'; // corto, 15m, 20m, 25m
  String _passHeight = 'abajo'; // abajo, media, alto

  // Estado de la interfaz - flujo de pasos
  int _currentStep = 0;
  bool _isLoading = false;

  // Lista de partidos para el selector
  List<MatchModel> _matches = [];
  bool _loadingMatches = false;

  // Controladores
  final TextEditingController _minuteController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Si viene con un partido preseleccionado
    if (widget.match != null) {
      _matchId = widget.match!.id;
    }

    // Si el usuario es premium, cargar partidos recientes
    if (widget.user.subscription.isPremium) {
      _loadMatches();
    }
  }

  Future<void> _loadMatches() async {
    if (_loadingMatches) return;

    setState(() {
      _loadingMatches = true;
    });

    try {
      // Cargar partidos recientes y futuros en 14 días
      final now = DateTime.now();
      final twoWeeksAgo = now.subtract(const Duration(days: 14));
      final twoWeeksLater = now.add(const Duration(days: 14));

      final matches = await widget.matchesRepository.getMatchesByDateRange(
        widget.user.id,
        twoWeeksAgo,
        twoWeeksLater,
      );

      // Ordenar por fecha descendente
      matches.sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        _matches = matches;
      });
    } catch (e) {
      // Mostrar error si falla la carga
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar partidos: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingMatches = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _minuteController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getStepTitle()),
        actions: [
          // Botón para reiniciar el formulario
          if (_currentStep > 0)
            IconButton(
              icon: const Icon(Icons.restart_alt),
              tooltip: 'Reiniciar',
              onPressed: _resetForm,
            ),
        ],
      ),
      body: _buildCurrentStep(),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Registrar Saque';
      case 1:
        return 'Tipo de Saque';
      case 2:
        return 'Posición del Saque';
      case 3:
        return 'Detalles del Saque';
      default:
        return 'Registrar Saque';
    }
  }

  Widget _buildCurrentStep() {
    // Mostrar indicador de carga mientras se procesa el registro
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Guardando saque...'),
          ],
        ),
      );
    }

    // Mostrar el paso actual según el estado
    switch (_currentStep) {
      case 0:
        return _buildInitialStep();
      case 1:
        return _buildConfigurationStep();
      case 2:
        return _buildPositionStep();
      case 3:
        return _buildDetailsStep();
      default:
        return const Center(
          child: Text('Paso no válido'),
        );
    }
  }

  // PASO 0: Introducción y bienvenida
  Widget _buildInitialStep() {
    final ThemeData theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Contenido principal expandible
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tarjeta de explicación
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.sports_handball,
                          size: 48,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Registro de Saques del Portero',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Registra los saques realizados durante partidos o entrenamientos para mejorar tu técnica y precisión.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 16),

                        // Pasos del proceso
                        _buildStepIndicator(
                          step: 1,
                          title: 'Tipo y Resultado',
                          description:
                              'Configura las características del saque',
                          icon: Icons.settings,
                          theme: theme,
                        ),
                        _buildStepIndicator(
                          step: 2,
                          title: 'Posición',
                          description: 'Indica dónde terminó el saque',
                          icon: Icons.map,
                          theme: theme,
                        ),
                        _buildStepIndicator(
                          step: 3,
                          title: 'Detalles',
                          description: 'Información adicional',
                          icon: Icons.description,
                          isLast: true,
                          theme: theme,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Verificación de límites para usuarios gratuitos
                if (!widget.user.subscription.isPremium)
                  FutureBuilder<int>(
                    future: _countTodayPasses(),
                    builder: (context, snapshot) {
                      final passesCount = snapshot.data ?? 0;
                      final limit = 20; // Límite para usuarios gratuitos
                      final remaining = limit - passesCount;

                      final cardDecoration =
                          AppTheme.premiumCardDecoration(isDarkMode);
                      final Color bgColor = remaining > 5
                          ? (isDarkMode
                              ? AppTheme.darkCardColor.withOpacity(0.7)
                              : Colors.green.shade50)
                          : remaining > 0
                              ? (isDarkMode
                                  ? const Color(0xFF423000).withOpacity(0.7)
                                  : Colors.amber.shade50)
                              : (isDarkMode
                                  ? AppTheme.darkCardColor.withOpacity(0.7)
                                  : Colors.red.shade50);

                      final Color iconColor = remaining > 5
                          ? theme.colorScheme.primary
                          : remaining > 0
                              ? (isDarkMode
                                  ? AppTheme.premiumDarkColor
                                  : Colors.amber)
                              : theme.colorScheme.error;

                      return Card(
                        color: bgColor,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Icon(
                                remaining > 5
                                    ? Icons.check_circle
                                    : remaining > 0
                                        ? Icons.warning
                                        : Icons.error,
                                color: iconColor,
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                remaining > 0
                                    ? 'Te quedan $remaining saques de $limit hoy'
                                    : 'Has alcanzado el límite diario de saques',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (remaining <= 0)
                                TextButton.icon(
                                  onPressed: () {
                                    // Navegar a pantalla de suscripción
                                  },
                                  icon: const Icon(Icons.star),
                                  label: const Text('Actualizar a Premium'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: isDarkMode
                                        ? AppTheme.premiumDarkColor
                                        : AppTheme.premiumColor,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),

        // Botones de navegación - Fijos en la parte inferior
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _currentStep = 1;
              });
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 48),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            child: const Text(
              'Comenzar a Registrar',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // PASO 1: Configuración del tipo de saque y resultado
  Widget _buildConfigurationStep() {
    final ThemeData theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Contenido principal expandible
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Descripción del paso
                Text(
                  'Configura las características del saque:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onBackground,
                  ),
                ),
                const SizedBox(height: 24),

                // Tipo de saque (Mano/Pie)
                Text(
                  '1. Tipo de saque:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onBackground,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildPassTypeOption(
                        title: 'Mano',
                        value: GoalkeeperPassModel.TYPE_HAND,
                        icon: Icons.back_hand,
                        theme: theme,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildPassTypeOption(
                        title: 'Pie',
                        value: GoalkeeperPassModel.TYPE_GROUND,
                        icon: Icons.sports_soccer,
                        theme: theme,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Altura del saque
                Text(
                  '2. Altura:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onBackground,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildHeightOption(
                        title: 'Abajo',
                        value: 'abajo',
                        icon: Icons.keyboard_arrow_down,
                        theme: theme,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildHeightOption(
                        title: 'Media',
                        value: 'media',
                        icon: Icons.remove,
                        theme: theme,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildHeightOption(
                        title: 'Alto',
                        value: 'alto',
                        icon: Icons.keyboard_arrow_up,
                        theme: theme,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Resultado del saque
                Text(
                  '3. Resultado:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onBackground,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildResultOption(
                        title: 'Exitoso',
                        value: GoalkeeperPassModel.RESULT_SUCCESSFUL,
                        icon: Icons.check_circle,
                        color: theme.colorScheme.primary,
                        theme: theme,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildResultOption(
                        title: 'Fallido',
                        value: GoalkeeperPassModel.RESULT_FAILED,
                        icon: Icons.cancel,
                        color: theme.colorScheme.error,
                        theme: theme,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Botones de navegación - Fijos en la parte inferior
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _currentStep = 0;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: theme.colorScheme.primary,
                    side: BorderSide(color: theme.colorScheme.primary),
                  ),
                  child: const Text('Anterior'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _currentStep = 2;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                  child: const Text('Siguiente'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // PASO 2: Selección de posición en el campo
  Widget _buildPositionStep() {
    final ThemeData theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Contenido principal expandible
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Descripción del paso
                Text(
                  'Toca el campo para indicar dónde terminó el saque:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onBackground,
                  ),
                ),
                const SizedBox(height: 8),

                // Resumen de selecciones anteriores
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? theme.colorScheme.surface.withOpacity(0.5)
                        : theme.colorScheme.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Saque de ${_passType == GoalkeeperPassModel.TYPE_HAND ? "mano" : "pie"} - '
                    'Altura: $_passHeight - '
                    'Resultado: ${_passResult == GoalkeeperPassModel.RESULT_SUCCESSFUL ? "Exitoso" : "Fallido"}',
                    style: TextStyle(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Selector de posición en el campo (ocupa la mayor parte de la pantalla)
                Expanded(
                  child: PassFieldSelector(
                    onEndPositionSelected: (position, distance) {
                      setState(() {
                        _selectedEndPosition = position;
                        _passDistance = distance;
                      });
                    },
                    selectedEndPosition: _selectedEndPosition,
                  ),
                ),

                // Mensaje que indica la selección actual
                if (_selectedEndPosition != null)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? theme.colorScheme.surface.withOpacity(0.5)
                          : theme.colorScheme.tertiary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Distancia seleccionada: $_passDistance',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colorScheme.tertiary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Botones de navegación - Fijos en la parte inferior
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _currentStep = 1;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: theme.colorScheme.primary,
                    side: BorderSide(color: theme.colorScheme.primary),
                  ),
                  child: const Text('Anterior'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _selectedEndPosition != null
                      ? () {
                          setState(() {
                            _currentStep = 3;
                          });
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                  child: const Text('Siguiente'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // PASO 3: Detalles adicionales
  Widget _buildDetailsStep() {
    final ThemeData theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;
    final isPremium = widget.user.subscription.isPremium;

    return Column(
      children: [
        // Contenido principal expandible
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Descripción del paso
                Text(
                  'Completa la información adicional:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onBackground,
                  ),
                ),
                const SizedBox(height: 16),

                // Selector de partido (solo para usuarios premium)
                if (isPremium && widget.match == null) ...[
                  Text(
                    'Partido:',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onBackground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildMatchSelector(theme),
                  const SizedBox(height: 16),
                ],

                // Minuto del partido
                TextFormField(
                  controller: _minuteController,
                  decoration: InputDecoration(
                    labelText: 'Minuto (opcional)',
                    prefixIcon:
                        Icon(Icons.timer, color: theme.colorScheme.primary),
                    labelStyle:
                        TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    if (value.isNotEmpty) {
                      setState(() {
                        _minute = int.tryParse(value);
                      });
                    } else {
                      setState(() {
                        _minute = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Notas adicionales
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: 'Observaciones (opcional)',
                    prefixIcon:
                        Icon(Icons.note, color: theme.colorScheme.primary),
                    labelStyle:
                        TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  maxLines: 3,
                  onChanged: (value) {
                    setState(() {
                      _notes = value.isEmpty ? null : value;
                    });
                  },
                ),
                const SizedBox(height: 24),

                // Resumen de los datos seleccionados
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resumen del Saque',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Divider(
                            color: theme.colorScheme.onSurfaceVariant
                                .withOpacity(0.3)),
                        Text(
                            'Tipo: ${_passType == GoalkeeperPassModel.TYPE_HAND ? "Mano" : "Pie"}',
                            style:
                                TextStyle(color: theme.colorScheme.onSurface)),
                        Text('Altura: $_passHeight',
                            style:
                                TextStyle(color: theme.colorScheme.onSurface)),
                        Text('Distancia: $_passDistance',
                            style:
                                TextStyle(color: theme.colorScheme.onSurface)),
                        Text(
                            'Resultado: ${_passResult == GoalkeeperPassModel.RESULT_SUCCESSFUL ? "Exitoso" : "Fallido"}',
                            style:
                                TextStyle(color: theme.colorScheme.onSurface)),
                        if (isPremium && widget.match != null)
                          Text('Partido: ${widget.match!.displayName}',
                              style:
                                  TextStyle(color: theme.colorScheme.onSurface))
                        else if (isPremium && _matchId != null)
                          Text('Partido: ${_getMatchDisplayName()}',
                              style: TextStyle(
                                  color: theme.colorScheme.onSurface)),
                        if (_minute != null)
                          Text('Minuto: $_minute',
                              style: TextStyle(
                                  color: theme.colorScheme.onSurface)),
                        if (_notes != null && _notes!.isNotEmpty)
                          Text('Observaciones: $_notes',
                              style: TextStyle(
                                  color: theme.colorScheme.onSurface)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Botones de navegación - Fijos en la parte inferior
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _currentStep = 2;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        foregroundColor: theme.colorScheme.primary,
                        side: BorderSide(color: theme.colorScheme.primary),
                      ),
                      child: const Text('Anterior'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _savePass,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                      child: const Text('Guardar'),
                    ),
                  ),
                ],
              ),

              // NUEVO: Botón adicional para usuarios premium con partido seleccionado
              if (isPremium && (widget.match != null || _matchId != null))
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _saveAndRegisterAnother,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Guardar y registrar otro saque'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDarkMode
                            ? AppTheme.selectedGreen
                            : Theme.of(context).colorScheme.secondary,
                        foregroundColor: isDarkMode
                            ? AppTheme.selectedTextDark
                            : theme.colorScheme.onSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepIndicator({
    required int step,
    required String title,
    required String description,
    required IconData icon,
    bool isLast = false,
    required ThemeData theme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: theme.colorScheme.primary,
          child: Text(
            step.toString(),
            style: TextStyle(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Container(
              height: 30,
              width: 2,
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
          ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                Text(
                  description,
                  style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPassTypeOption({
    required String title,
    required String value,
    required IconData icon,
    required ThemeData theme,
    required bool isDarkMode,
  }) {
    final isSelected = _passType == value;

    final buttonStyle = AppTheme.selectionButtonStyle(
      isDarkMode: isDarkMode,
      isSelected: isSelected,
    );

    return GestureDetector(
      onTap: () {
        setState(() {
          _passType = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkMode
                  ? AppTheme.darkCardColor
                  : theme.colorScheme.secondary.withOpacity(0.1))
              : (isDarkMode ? AppTheme.unselectedDark : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? (isDarkMode
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.secondary)
                : (isDarkMode ? AppTheme.unselectedDark : Colors.grey.shade300),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected
                  ? theme.colorScheme.secondary
                  : (isDarkMode ? AppTheme.unselectedTextDark : Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? theme.colorScheme.secondary
                    : (isDarkMode
                        ? AppTheme.unselectedTextDark
                        : Colors.grey.shade800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeightOption({
    required String title,
    required String value,
    required IconData icon,
    required ThemeData theme,
    required bool isDarkMode,
  }) {
    final isSelected = _passHeight == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _passHeight = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkMode
                  ? AppTheme.darkCardColor
                  : theme.colorScheme.tertiary.withOpacity(0.1))
              : (isDarkMode ? AppTheme.unselectedDark : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? (isDarkMode
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.tertiary)
                : (isDarkMode ? AppTheme.unselectedDark : Colors.grey.shade300),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? theme.colorScheme.tertiary
                  : (isDarkMode ? AppTheme.unselectedTextDark : Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? theme.colorScheme.tertiary
                    : (isDarkMode
                        ? AppTheme.unselectedTextDark
                        : Colors.grey.shade800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultOption({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required ThemeData theme,
    required bool isDarkMode,
  }) {
    final isSelected = _passResult == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _passResult = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkMode ? color.withOpacity(0.2) : color.withOpacity(0.1))
              : (isDarkMode ? AppTheme.unselectedDark : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? color
                : (isDarkMode ? AppTheme.unselectedDark : Colors.grey.shade300),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected
                  ? color
                  : (isDarkMode ? AppTheme.unselectedTextDark : Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? color
                    : (isDarkMode
                        ? AppTheme.unselectedTextDark
                        : Colors.grey.shade800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchSelector(ThemeData theme) {
    return DropdownButtonFormField<String>(
      value: _matchId,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        hintText: 'Seleccionar partido',
        hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.colorScheme.outline),
        ),
      ),
      dropdownColor: theme.colorScheme.surface,
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text('Sin asignar a partido',
              style: TextStyle(color: theme.colorScheme.onSurface)),
        ),
        ..._matches.map((match) {
          final date = match.date;
          final formattedDate = '${date.day}/${date.month}/${date.year}';

          String typeText;
          switch (match.type) {
            case MatchModel.TYPE_OFFICIAL:
              typeText = 'Oficial';
              break;
            case MatchModel.TYPE_FRIENDLY:
              typeText = 'Amistoso';
              break;
            case MatchModel.TYPE_TRAINING:
              typeText = 'Entreno';
              break;
            default:
              typeText = 'Partido';
          }

          return DropdownMenuItem<String>(
            value: match.id,
            child: Text(
              '[$typeText] ${match.opponent ?? 'Sin rival'} - $formattedDate',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
          );
        }),
      ],
      onChanged: (value) {
        setState(() {
          _matchId = value;
        });
      },
    );
  }

  String _getMatchDisplayName() {
    final match = _matches.firstWhere(
      (match) => match.id == _matchId,
      orElse: () => MatchModel(
        id: '',
        userId: '',
        date: DateTime.now(),
        type: MatchModel.TYPE_FRIENDLY,
      ),
    );

    if (match.id.isEmpty) return 'Desconocido';

    final date = match.date;
    final formattedDate = '${date.day}/${date.month}/${date.year}';

    String typeText;
    switch (match.type) {
      case MatchModel.TYPE_OFFICIAL:
        typeText = 'Partido Oficial';
        break;
      case MatchModel.TYPE_FRIENDLY:
        typeText = 'Amistoso';
        break;
      case MatchModel.TYPE_TRAINING:
        typeText = 'Entrenamiento';
        break;
      default:
        typeText = 'Partido';
    }

    return '$typeText ${match.opponent != null ? "vs ${match.opponent}" : ""} - $formattedDate';
  }

  Future<int> _countTodayPasses() async {
    if (widget.user.subscription.isPremium) {
      return 0; // No hay límite para usuarios premium
    }

    try {
      // Contar saques de hoy
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final todayPasses = await widget.passesRepository.getPassesByDateRange(
        widget.user.id,
        startOfDay,
        endOfDay,
      );

      return todayPasses.length;
    } catch (e) {
      print('Error al contar saques de hoy: $e');
      return 0; // Asumir 0 si hay error
    }
  }

  void _resetForm() {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reiniciar Formulario'),
        content: const Text(
          '¿Estás seguro de que quieres reiniciar el formulario? '
          'Perderás todos los datos ingresados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: TextStyle(color: theme.colorScheme.primary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentStep = 0;
                _selectedEndPosition = null;
                _passType = GoalkeeperPassModel.TYPE_HAND;
                _passResult = GoalkeeperPassModel.RESULT_SUCCESSFUL;
                _passDistance = 'corto';
                _passHeight = 'abajo';
                if (widget.match == null) _matchId = null;
                _minute = null;
                _notes = null;
                _minuteController.clear();
                _notesController.clear();
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );
  }

  Future<void> _savePass() async {
    // Verificación y guardado
    if (_selectedEndPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Falta información importante del saque'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    // Verificar límite diario para usuarios gratuitos
    if (!widget.user.subscription.isPremium) {
      final todayPassesCount = await _countTodayPasses();
      if (todayPassesCount >= 20) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Has alcanzado el límite diario de saques para usuarios gratuitos',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Crear saque
      final combinedNotes = _notes != null && _notes!.isNotEmpty
          ? 'Altura: $_passHeight | Distancia: $_passDistance | $_notes'
          : 'Altura: $_passHeight | Distancia: $_passDistance';

      final newPass = GoalkeeperPassModel.create(
        userId: widget.user.id,
        matchId: _matchId,
        minute: _minute,
        type: _passType,
        result: _passResult,
        // Solo utilizamos endPosition para simplicidad
        endPosition: _selectedEndPosition!,
        notes: combinedNotes,
      );

      // Guardar saque en repositorio
      await widget.passesRepository.createPass(newPass);

      // Mostrar mensaje de éxito y reiniciar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Saque registrado correctamente'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      // Mostrar error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar el saque: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // NUEVO: Método para guardar y comenzar un nuevo registro
  Future<void> _saveAndRegisterAnother() async {
    // Verificación y guardado
    if (_selectedEndPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Falta información importante del saque'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Crear saque igual que en _savePass()
      final combinedNotes = _notes != null && _notes!.isNotEmpty
          ? 'Altura: $_passHeight | Distancia: $_passDistance | $_notes'
          : 'Altura: $_passHeight | Distancia: $_passDistance';

      final newPass = GoalkeeperPassModel.create(
        userId: widget.user.id,
        matchId:
            _matchId ?? widget.match?.id, // Mantenemos la referencia al partido
        minute: _minute,
        type: _passType,
        result: _passResult,
        endPosition: _selectedEndPosition!,
        notes: combinedNotes,
      );

      // Guardar saque en repositorio
      await widget.passesRepository.createPass(newPass);

      // Mostrar mensaje de éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Saque registrado correctamente'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );

        // Reiniciar formulario PARCIALMENTE - mantenemos la referencia al partido
        setState(() {
          _currentStep = 1; // Volvemos al paso 1 (configuración del saque)
          _selectedEndPosition = null;
          _passType = GoalkeeperPassModel.TYPE_HAND;
          _passResult = GoalkeeperPassModel.RESULT_SUCCESSFUL;
          _passHeight = 'abajo';
          _passDistance = 'corto';
          // NO reiniciamos matchId o widget.match para mantener el mismo partido
          _minute = null;
          _notes = null;
          _minuteController.clear();
          _notesController.clear();
        });
      }
    } catch (e) {
      // Mostrar error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar el saque: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
