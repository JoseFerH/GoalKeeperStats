import 'package:flutter/material.dart';
import 'package:goalkeeper_stats/data/models/match_model.dart';
import 'package:goalkeeper_stats/data/models/shot_model.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/domain/repositories/shots_repository.dart';
import 'package:goalkeeper_stats/presentation/widgets/field_map/field_selector.dart';
import 'package:goalkeeper_stats/presentation/widgets/goal_map/goal_selector.dart';
import 'package:goalkeeper_stats/data/models/position.dart';
import 'package:goalkeeper_stats/core/constants/app_constants.dart';
import 'package:goalkeeper_stats/services/cache_manager.dart';
import 'package:goalkeeper_stats/services/connectivity_service.dart';
import 'package:goalkeeper_stats/services/firebase_crashlytics_service.dart';
import 'package:goalkeeper_stats/services/daily_limits_service.dart'; // NUEVO: Servicio de límites
import 'package:connectivity_plus/connectivity_plus.dart';

class ShotFormPage extends StatefulWidget {
  final UserModel user;
  final MatchModel? match; // Opcional, para usuarios premium
  final ShotsRepository shotsRepository;
  final Function? onDataRegistered; // Añadido este parámetro que faltaba

  const ShotFormPage({
    Key? key,
    required this.user,
    required this.shotsRepository,
    this.match,
    this.onDataRegistered, // Incluido como parámetro opcional
  }) : super(key: key);

  @override
  State<ShotFormPage> createState() => _ShotFormPageState();
}

class _ShotFormPageState extends State<ShotFormPage> {
  // Estado del tiro en proceso de registro
  Position? _selectedGoalPosition;
  Position? _selectedShooterPosition;
  Position? _selectedGoalkeeperPosition;
  String _shotResult = ShotModel.RESULT_SAVED; // Por defecto: atajado
  String? _shotType; // Tipo de tiro
  String? _goalType;
  String? _blockType; // Tipo de bloqueo
  int? _minute;
  String? _notes;

  // Estado de la interfaz
  int _currentStep = 0;
  bool _isLoading = false;
  bool _isGoal = false;
  bool _isConnected = true;

  // Servicios
  final CacheManager _cacheManager = CacheManager();
  final ConnectivityService _connectivityService = ConnectivityService();
  final FirebaseCrashlyticsService _crashlyticsService =
      FirebaseCrashlyticsService();

  // NUEVO: Usar servicio centralizado de límites
  late final DailyLimitsService _dailyLimitsService;
  DailyLimitInfo? _limitInfo; // NUEVO: Información del límite
  bool _isCheckingLimits = false;

  // Controladores
  final TextEditingController _minuteController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // NUEVO: Inicializar servicio de límites
    _dailyLimitsService = DailyLimitsService(
      cacheManager: _cacheManager,
      crashlyticsService: _crashlyticsService,
    );

    _setupConnectivity();
    if (!widget.user.subscription.isPremium) {
      _checkFreeTierLimits(); // CORREGIDO: Usar nuevo método
    }
  }

  @override
  void dispose() {
    _minuteController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _setupConnectivity() {
    _connectivityService.onConnectivityChanged.listen((result) {
      setState(() {
        _isConnected = result == ConnectivityResult.wifi ||
            result == ConnectivityResult.mobile ||
            result == ConnectivityResult.ethernet;
      });

      if (!_isConnected && mounted) {
        _connectivityService.showConnectivitySnackBar(context);
      }
    });

    _connectivityService.checkConnectivity().then((connected) {
      setState(() {
        _isConnected = connected;
      });
    });
  }

  // CORREGIDO: Nuevo método usando servicio centralizado
  Future<void> _checkFreeTierLimits() async {
    if (widget.user.subscription.isPremium) {
      return;
    }

    setState(() {
      _isCheckingLimits = true;
    });

    try {
      final limitInfo = await _dailyLimitsService.getLimitInfo(widget.user);

      setState(() {
        _limitInfo = limitInfo;
        _isCheckingLimits = false;
      });

      // Si ya alcanzó el límite, mostrar diálogo
      if (limitInfo.hasReachedLimit) {
        _showLimitReachedDialog();
      }
    } catch (e) {
      _crashlyticsService.recordError(
        e,
        StackTrace.current,
        reason: 'Error al verificar límite de tiros diarios en formulario',
      );

      setState(() {
        _isCheckingLimits = false;
        // En caso de error, asumir límite alcanzado para usuarios gratuitos
        _limitInfo = DailyLimitInfo(
          isPremium: false,
          dailyLimit: 20,
          todayCount: 20,
          hasReachedLimit: true,
          remainingShots: 0,
        );
      });

      // Mostrar diálogo de límite alcanzado
      _showLimitReachedDialog();
    }
  }

  void _showLimitReachedDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Límite diario alcanzado'),
        content: Text(_limitInfo?.displayMessage ??
            'Has alcanzado el límite de 20 tiros diarios para usuarios gratuitos. '
                'Actualiza a Premium para registrar tiros ilimitados y tener acceso '
                'a todas las funciones.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Volver a la pantalla anterior
            },
            child: const Text('Entendido'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Volver a la pantalla anterior
              Navigator.pushNamed(context, '/subscription');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
            ),
            child: const Text('Ver planes Premium'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        //title: const Text('Registrar Tiro'),
        actions: [
          if (!_isConnected)
            IconButton(
              icon: const Icon(Icons.wifi_off),
              onPressed: () =>
                  _connectivityService.showConnectivitySnackBar(context),
              tooltip: 'Sin conexión',
            ),
          if (_currentStep > 0)
            IconButton(
              icon: const Icon(Icons.restart_alt),
              onPressed: _resetForm,
              tooltip: 'Reiniciar',
            ),
        ],
      ),
      body: _buildCurrentStep(),
    );
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
            Text('Guardando tiro...'),
          ],
        ),
      );
    }

    // Advertencia de conectividad en la parte superior
    if (!_isConnected) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.red.shade100,
            child: const Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.red),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sin conexión a internet. Puedes seguir completando el formulario, pero será necesario estar conectado para guardar.',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildStepContent()),
        ],
      );
    }

    return _buildStepContent();
  }

  Widget _buildStepContent() {
    // Mostrar el paso actual del asistente
    switch (_currentStep) {
      case 0:
        return _buildInitialStep();
      case 1:
        return _buildGoalPositionStep();
      case 2:
        return _buildFieldPositionStep();
      case 3:
        return _buildResultStep();
      case 4:
        return _buildDetailsStep();
      default:
        return const Center(
          child: Text('Paso no válido'),
        );
    }
  }

  // CORREGIDO: Método _buildInitialStep usando nueva información de límites
  Widget _buildInitialStep() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isPremium = widget.user.subscription.isPremium;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // CORREGIDO: Mostrar información de límites usando el servicio centralizado
          if (!isPremium && _limitInfo != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _limitInfo!.hasReachedLimit
                    ? Colors.red.shade50
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: _limitInfo!.hasReachedLimit
                        ? Colors.red.shade200
                        : Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    _limitInfo!.hasReachedLimit
                        ? Icons.error_outline
                        : Icons.check_circle,
                    color:
                        _limitInfo!.hasReachedLimit ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _isCheckingLimits
                        ? const Text("Verificando límites diarios...")
                        : Text(
                            _limitInfo!.displayMessage,
                            style: TextStyle(
                              color: _limitInfo!.hasReachedLimit
                                  ? Colors.red.shade700
                                  : Colors.green.shade700,
                            ),
                          ),
                  ),
                ],
              ),
            ),

          // Tarjeta de explicación
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(
                    Icons.sports_soccer,
                    size: 48,
                    color: isDarkMode
                        ? Theme.of(context).colorScheme.primary
                        : Colors.green,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Registro Visual de Tiros',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? Theme.of(context).colorScheme.onSurface
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Este asistente te guiará paso a paso para registrar los tiros recibidos durante partidos o entrenamientos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Pasos del proceso
                  _buildStepIndicator(
                    step: 1,
                    title: 'Posición en la Portería',
                    description: 'Selecciona dónde fue el tiro',
                    icon: Icons.sports_score,
                  ),
                  _buildStepIndicator(
                    step: 2,
                    title: 'Posición en el Campo',
                    description: 'Indica desde dónde vino el tiro',
                    icon: Icons.map,
                  ),
                  _buildStepIndicator(
                    step: 3,
                    title: 'Resultado',
                    description: 'Gol o atajada',
                    icon: Icons.rule,
                  ),
                  _buildStepIndicator(
                    step: 4,
                    title: 'Detalles',
                    description: 'Información adicional',
                    icon: Icons.description,
                    isLast: true,
                  ),
                ],
              ),
            ),
          ),

          // Si hay partido seleccionado, mostrar info
          if (widget.match != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Card(
                color: isDarkMode
                    ? Theme.of(context)
                        .colorScheme
                        .secondaryContainer
                        .withOpacity(0.4)
                    : Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(
                        _getMatchIcon(widget.match!.type),
                        color: _getMatchColor(widget.match!.type),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Registrando tiro para:',
                              style: TextStyle(
                                color: isDarkMode
                                    ? Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                    : Colors.grey.shade700,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _getMatchDescription(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? Theme.of(context).colorScheme.onSurface
                                    : null,
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

          const Spacer(),

          // CORREGIDO: Botón para iniciar el proceso
          ElevatedButton(
            onPressed: (!isPremium && (_limitInfo?.hasReachedLimit ?? false)) ||
                    !_isConnected
                ? null // Deshabilitar si se alcanzó el límite o no hay conexión
                : () {
                    setState(() {
                      _currentStep = 1;
                    });
                  },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              !_isConnected
                  ? 'Se requiere conexión a internet'
                  : 'Comenzar a Registrar',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // CORREGIDO: Mensaje adicional para límite alcanzado
          if (!isPremium && (_limitInfo?.hasReachedLimit ?? false))
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Volver a la pantalla anterior
                  Navigator.pushNamed(context, '/subscription');
                },
                child: const Text('Actualizar a Premium para continuar'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator({
    required int step,
    required String title,
    required String description,
    required IconData icon,
    bool isLast = false,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDarkMode ? Theme.of(context).colorScheme.primary : Colors.green;
    final primaryColorLight = isDarkMode
        ? Theme.of(context).colorScheme.primaryContainer
        : Colors.green.shade200;
    final textColor = isDarkMode
        ? Theme.of(context).colorScheme.onSurface
        : Colors.green.shade700;
    final subtitleColor = isDarkMode
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : Colors.grey.shade600;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Círculo con número
        CircleAvatar(
          radius: 14,
          backgroundColor: primaryColor,
          child: Text(
            step.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        // Línea vertical conectora
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Container(
              height: 30,
              width: 2,
              color: primaryColorLight,
            ),
          ),
        const SizedBox(width: 16),
        // Descripción del paso
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: textColor),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                Text(
                  description,
                  style: TextStyle(color: subtitleColor, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoalPositionStep() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Descripción del paso
          Text(
            'Posición en la Portería',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color:
                  isDarkMode ? Theme.of(context).colorScheme.onSurface : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toca la portería para indicar dónde fue el tiro',
            style: TextStyle(
              color: isDarkMode
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Colors.grey,
            ),
          ),
          const SizedBox(height: 16),

          // Selector de posición en la portería
          Expanded(
            child: GoalSelector(
              onPositionSelected: (position) {
                setState(() {
                  _selectedGoalPosition = position;
                });
              },
              selectedPosition: _selectedGoalPosition,
            ),
          ),

          // Indicador de posición seleccionada
          if (_selectedGoalPosition != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
              child: Text(
                'Posición seleccionada: (${(_selectedGoalPosition!.x * 100).toStringAsFixed(1)}%, ${(_selectedGoalPosition!.y * 100).toStringAsFixed(1)}%)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDarkMode
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Colors.grey,
                ),
              ),
            ),

          // Botones de navegación
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _currentStep = 0;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDarkMode
                        ? Theme.of(context).colorScheme.onSurface
                        : null,
                    side: BorderSide(
                      color: isDarkMode
                          ? Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5)
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  child: const Text('Anterior'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _selectedGoalPosition != null
                      ? () {
                          setState(() {
                            _currentStep = 2;
                          });
                        }
                      : null,
                  child: const Text('Siguiente'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFieldPositionStep() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Descripción del paso
          Text(
            'Posición en el Campo',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color:
                  isDarkMode ? Theme.of(context).colorScheme.onSurface : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toca el campo para indicar desde dónde vino el tiro y la posición del portero',
            style: TextStyle(
              color: isDarkMode
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Colors.grey,
            ),
          ),
          const SizedBox(height: 16),

          // Selector de posición en el campo
          Expanded(
            child: FieldSelector(
              onShooterPositionSelected: (position) {
                setState(() {
                  _selectedShooterPosition = position;
                });
              },
              onGoalkeeperPositionSelected: (position) {
                setState(() {
                  _selectedGoalkeeperPosition = position;
                });
              },
              selectedShooterPosition: _selectedShooterPosition,
              selectedGoalkeeperPosition: _selectedGoalkeeperPosition,
            ),
          ),

          // Indicadores de posiciones seleccionadas
          if (_selectedShooterPosition != null ||
              _selectedGoalkeeperPosition != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
              child: Column(
                children: [
                  if (_selectedShooterPosition != null)
                    Text(
                      'Tirador: (${(_selectedShooterPosition!.x * 100).toStringAsFixed(1)}%, ${(_selectedShooterPosition!.y * 100).toStringAsFixed(1)}%)',
                      style: TextStyle(
                        color: isDarkMode ? Colors.blue.shade300 : Colors.blue,
                      ),
                    ),
                  if (_selectedGoalkeeperPosition != null)
                    Text(
                      'Portero: (${(_selectedGoalkeeperPosition!.x * 100).toStringAsFixed(1)}%, ${(_selectedGoalkeeperPosition!.y * 100).toStringAsFixed(1)}%)',
                      style: TextStyle(
                        color:
                            isDarkMode ? Colors.green.shade300 : Colors.green,
                      ),
                    ),
                ],
              ),
            ),

          // Botones de navegación
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _currentStep = 1;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDarkMode
                        ? Theme.of(context).colorScheme.onSurface
                        : null,
                    side: BorderSide(
                      color: isDarkMode
                          ? Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5)
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  child: const Text('Anterior'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: (_selectedShooterPosition != null &&
                          _selectedGoalkeeperPosition != null)
                      ? () {
                          setState(() {
                            _currentStep = 3;
                          });
                        }
                      : null,
                  child: const Text('Siguiente'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultStep() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Descripción del paso
            Text(
              'Resultado del Tiro',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color:
                    isDarkMode ? Theme.of(context).colorScheme.onSurface : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Selecciona si fue gol o atajada',
              style: TextStyle(
                color: isDarkMode
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Colors.grey,
              ),
            ),
            const SizedBox(height: 24),

            // Opciones de resultado
            Row(
              children: [
                Expanded(
                  child: _buildResultOption(
                    title: 'Atajada',
                    value: ShotModel.RESULT_SAVED,
                    icon: Icons.security,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildResultOption(
                    title: 'Gol',
                    value: ShotModel.RESULT_GOAL,
                    icon: Icons.sports_score,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Tipo de tiro (aplicable para todos los casos)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tipo de Tiro',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? Theme.of(context).colorScheme.onSurface
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildShotTypeChip(
                      title: 'Tiro en jugada',
                      value: ShotModel.SHOT_TYPE_OPEN_PLAY,
                    ),
                    _buildShotTypeChip(
                      title: 'Saque de banda',
                      value: ShotModel.SHOT_TYPE_THROW_IN,
                    ),
                    _buildShotTypeChip(
                      title: 'Tiro libre',
                      value: ShotModel.SHOT_TYPE_FREE_KICK,
                    ),
                    _buildShotTypeChip(
                      title: 'Sexta falta',
                      value: ShotModel.SHOT_TYPE_SIXTH_FOUL,
                    ),
                    _buildShotTypeChip(
                      title: 'Penalti',
                      value: ShotModel.SHOT_TYPE_PENALTY,
                    ),
                    _buildShotTypeChip(
                      title: 'Tiro de esquina',
                      value: ShotModel.SHOT_TYPE_CORNER,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Si es gol, mostrar tipos de gol
            if (_isGoal)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tipo de Gol',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? Theme.of(context).colorScheme.onSurface
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildGoalTypeChip(
                        title: 'Cabezazo',
                        value: ShotModel.GOAL_TYPE_HEADER,
                      ),
                      _buildGoalTypeChip(
                        title: 'Volea',
                        value: ShotModel.GOAL_TYPE_VOLLEY,
                      ),
                      _buildGoalTypeChip(
                        title: 'Mano a mano',
                        value: ShotModel.GOAL_TYPE_ONE_ON_ONE,
                      ),
                      _buildGoalTypeChip(
                        title: 'Segundo palo',
                        value: ShotModel.GOAL_TYPE_FAR_POST,
                      ),
                      _buildGoalTypeChip(
                        title: 'Entre piernas',
                        value: ShotModel.GOAL_TYPE_NUTMEG,
                      ),
                      _buildGoalTypeChip(
                        title: 'Rebote de portero',
                        value: ShotModel.GOAL_TYPE_REBOUND,
                      ),
                      _buildGoalTypeChip(
                        title: 'Autogol',
                        value: ShotModel.GOAL_TYPE_OWN_GOAL,
                      ),
                      _buildGoalTypeChip(
                        title: 'Desvío de trayectoria',
                        value: ShotModel.GOAL_TYPE_DEFLECTION,
                      ),
                    ],
                  ),
                ],
              ),

            // Si es atajada, mostrar tipos de bloqueo
            if (!_isGoal)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tipo de Bloqueo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? Theme.of(context).colorScheme.onSurface
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildBlockTypeChip(
                        title: 'Bloqueo',
                        value: ShotModel.BLOCK_TYPE_BLOCK,
                      ),
                      _buildBlockTypeChip(
                        title: 'Desvío',
                        value: ShotModel.BLOCK_TYPE_DEFLECTION,
                      ),
                      _buildBlockTypeChip(
                        title: 'Paso de valla',
                        value: ShotModel.BLOCK_TYPE_BARRIER,
                      ),
                      _buildBlockTypeChip(
                        title: 'Ataje de balón con pie',
                        value: ShotModel.BLOCK_TYPE_FOOT_SAVE,
                      ),
                      _buildBlockTypeChip(
                        title: 'Caída lateral con bloqueo',
                        value: ShotModel.BLOCK_TYPE_SIDE_FALL_BLOCK,
                      ),
                      _buildBlockTypeChip(
                        title: 'Caída lateral con desvío',
                        value: ShotModel.BLOCK_TYPE_SIDE_FALL_DEFLECTION,
                      ),
                      _buildBlockTypeChip(
                        title: 'Cruz',
                        value: ShotModel.BLOCK_TYPE_CROSS,
                      ),
                      _buildBlockTypeChip(
                        title: 'Despeje',
                        value: ShotModel.BLOCK_TYPE_CLEARANCE,
                      ),
                      _buildBlockTypeChip(
                        title: 'Achique',
                        value: ShotModel.BLOCK_TYPE_NARROW_ANGLE,
                      ),
                    ],
                  ),
                ],
              ),

            const SizedBox(height: 24),

            // Botones de navegación
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
                      foregroundColor: isDarkMode
                          ? Theme.of(context).colorScheme.onSurface
                          : null,
                      side: BorderSide(
                        color: isDarkMode
                            ? Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5)
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    child: const Text('Anterior'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _currentStep = 4;
                      });
                    },
                    child: const Text('Siguiente'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsStep() {
    final isPremium = widget.user.subscription.isPremium;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Descripción del paso
          Text(
            'Detalles Adicionales',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color:
                  isDarkMode ? Theme.of(context).colorScheme.onSurface : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Completa la información adicional sobre el tiro',
            style: TextStyle(
              color: isDarkMode
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Colors.grey,
            ),
          ),
          const SizedBox(height: 24),

          // Minuto del partido
          TextFormField(
            controller: _minuteController,
            decoration: InputDecoration(
              labelText: 'Minuto (opcional)',
              prefixIcon: const Icon(Icons.timer),
              labelStyle: TextStyle(
                color: isDarkMode
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : null,
              ),
              filled: isDarkMode,
              fillColor: isDarkMode
                  ? Theme.of(context)
                      .colorScheme
                      .surfaceVariant
                      .withOpacity(0.3)
                  : null,
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
            style: TextStyle(
              color:
                  isDarkMode ? Theme.of(context).colorScheme.onSurface : null,
            ),
          ),
          const SizedBox(height: 16),

          // Notas adicionales
          TextFormField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: 'Notas (opcional)',
              prefixIcon: const Icon(Icons.note),
              labelStyle: TextStyle(
                color: isDarkMode
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : null,
              ),
              filled: isDarkMode,
              fillColor: isDarkMode
                  ? Theme.of(context)
                      .colorScheme
                      .surfaceVariant
                      .withOpacity(0.3)
                  : null,
            ),
            maxLines: 3,
            onChanged: (value) {
              setState(() {
                _notes = value.isEmpty ? null : value;
              });
            },
            style: TextStyle(
              color:
                  isDarkMode ? Theme.of(context).colorScheme.onSurface : null,
            ),
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
                    'Resumen',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDarkMode
                          ? Theme.of(context).colorScheme.onSurface
                          : null,
                    ),
                  ),
                  Divider(
                    color: isDarkMode
                        ? Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withOpacity(0.3)
                        : null,
                  ),
                  Text(
                    'Resultado: ${_isGoal ? 'Gol' : 'Atajada'}',
                    style: TextStyle(
                      color: isDarkMode
                          ? Theme.of(context).colorScheme.onSurface
                          : null,
                    ),
                  ),
                  if (_shotType != null)
                    Text(
                      'Tipo de tiro: ${_translateShotType(_shotType!)}',
                      style: TextStyle(
                        color: isDarkMode
                            ? Theme.of(context).colorScheme.onSurface
                            : null,
                      ),
                    ),
                  if (_isGoal && _goalType != null)
                    Text(
                      'Tipo de gol: ${_translateGoalType(_goalType!)}',
                      style: TextStyle(
                        color: isDarkMode
                            ? Theme.of(context).colorScheme.onSurface
                            : null,
                      ),
                    ),
                  if (!_isGoal && _blockType != null)
                    Text(
                      'Tipo de bloqueo: ${_translateBlockType(_blockType!)}',
                      style: TextStyle(
                        color: isDarkMode
                            ? Theme.of(context).colorScheme.onSurface
                            : null,
                      ),
                    ),
                  if (widget.match != null)
                    Text(
                      'Partido: ${_getMatchDescription()}',
                      style: TextStyle(
                        color: isDarkMode
                            ? Theme.of(context).colorScheme.onSurface
                            : null,
                      ),
                    ),
                  if (_minute != null)
                    Text(
                      'Minuto: $_minute',
                      style: TextStyle(
                        color: isDarkMode
                            ? Theme.of(context).colorScheme.onSurface
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Botones de navegación
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _currentStep = 3;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDarkMode
                        ? Theme.of(context).colorScheme.onSurface
                        : null,
                    side: BorderSide(
                      color: isDarkMode
                          ? Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5)
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  child: const Text('Anterior'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: !_isConnected ? null : _saveShot,
                  child: Text(!_isConnected ? 'Requiere conexión' : 'Guardar'),
                ),
              ),
            ],
          ),

          // Botón adicional para usuarios premium con partido seleccionado
          if (isPremium && widget.match != null)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: !_isConnected ? null : _saveAndRegisterAnother,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Guardar y registrar otro tiro'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isDarkMode ? Colors.green.shade700 : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultOption({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _shotResult == value;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Colores ajustados para modo oscuro
    final selectedColor = isDarkMode
        ? (value == ShotModel.RESULT_SAVED
            ? Colors.green.shade700
            : Colors.red.shade700)
        : color;
    final selectedBgColor = isDarkMode
        ? (value == ShotModel.RESULT_SAVED
            ? Colors.green.shade900
            : Colors.red.shade900)
        : color.withOpacity(0.1);
    final iconColor = isSelected
        ? selectedColor
        : (isDarkMode ? Colors.grey.shade400 : Colors.grey);
    final textColor = isSelected
        ? selectedColor
        : (isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700);

    return GestureDetector(
      onTap: () {
        setState(() {
          _shotResult = value;
          _isGoal = value == ShotModel.RESULT_GOAL;

          // Si cambia de gol a atajada, resetear tipo de gol
          if (!_isGoal) {
            _goalType = null;
          } else {
            // Si cambia de atajada a gol, resetear tipo de bloqueo
            _blockType = null;
          }
        });
      },
      child: Card(
        elevation: isSelected ? 4 : 1,
        color: isSelected ? selectedBgColor : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected
                ? selectedColor
                : (isDarkMode ? Colors.grey.shade700 : Colors.transparent),
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Column(
            children: [
              Icon(
                icon,
                size: 48,
                color: iconColor,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Chip para seleccionar tipo de tiro
  Widget _buildShotTypeChip({
    required String title,
    required String value,
  }) {
    final isSelected = _shotType == value;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return FilterChip(
      label: Text(
        title,
        style: TextStyle(
          color: isSelected
              ? (isDarkMode ? Colors.black87 : Colors.blue.shade900)
              : (isDarkMode ? Colors.white70 : null),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _shotType = selected ? value : null;
        });
      },
      backgroundColor: isDarkMode
          ? Theme.of(context).colorScheme.surfaceVariant
          : Colors.grey.shade200,
      selectedColor: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade100,
      checkmarkColor: isDarkMode ? Colors.black : Colors.blue,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _buildGoalTypeChip({
    required String title,
    required String value,
  }) {
    final isSelected = _goalType == value;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return FilterChip(
      label: Text(
        title,
        style: TextStyle(
          color: isSelected
              ? (isDarkMode ? Colors.black87 : Colors.red.shade900)
              : (isDarkMode ? Colors.white70 : null),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _goalType = selected ? value : null;
        });
      },
      backgroundColor: isDarkMode
          ? Theme.of(context).colorScheme.surfaceVariant
          : Colors.grey.shade200,
      selectedColor: isDarkMode ? Colors.red.shade300 : Colors.red.shade100,
      checkmarkColor: isDarkMode ? Colors.black : Colors.red,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  // Chip para seleccionar tipo de bloqueo
  Widget _buildBlockTypeChip({
    required String title,
    required String value,
  }) {
    final isSelected = _blockType == value;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return FilterChip(
      label: Text(
        title,
        style: TextStyle(
          color: isSelected
              ? (isDarkMode ? Colors.black87 : Colors.green.shade900)
              : (isDarkMode ? Colors.white70 : null),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _blockType = selected ? value : null;
        });
      },
      backgroundColor: isDarkMode
          ? Theme.of(context).colorScheme.surfaceVariant
          : Colors.grey.shade200,
      selectedColor: isDarkMode ? Colors.green.shade300 : Colors.green.shade100,
      checkmarkColor: isDarkMode ? Colors.black : Colors.green,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  void _resetForm() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Reiniciar Formulario',
          style: TextStyle(
            color: isDarkMode ? Theme.of(context).colorScheme.onSurface : null,
          ),
        ),
        content: Text(
          '¿Estás seguro de que quieres reiniciar el formulario? '
          'Perderás todos los datos ingresados.',
          style: TextStyle(
            color: isDarkMode
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor:
                  isDarkMode ? Theme.of(context).colorScheme.primary : null,
            ),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentStep = 0;
                _selectedGoalPosition = null;
                _selectedShooterPosition = null;
                _selectedGoalkeeperPosition = null;
                _shotResult = ShotModel.RESULT_SAVED;
                _isGoal = false;
                _shotType = null;
                _goalType = null;
                _blockType = null;
                _minute = null;
                _notes = null;
                _minuteController.clear();
                _notesController.clear();
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: isDarkMode ? Colors.red.shade300 : Colors.red,
            ),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );
  }

  // CORREGIDO: Método _saveShot usando servicio centralizado
  Future<void> _saveShot() async {
    // Verificar que hay conexión
    if (!_isConnected) {
      _connectivityService.showConnectivitySnackBar(context);
      return;
    }

    // CORREGIDO: Verificar límite usando servicio centralizado
    if (!widget.user.subscription.isPremium) {
      final canCreate = await _dailyLimitsService.canCreateShot(widget.user);
      if (!canCreate) {
        _showLimitReachedDialog();
        return;
      }
    }

    // Verificar datos mínimos necesarios
    if (_selectedGoalPosition == null ||
        _selectedShooterPosition == null ||
        _selectedGoalkeeperPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Falta información importante del tiro'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Crear tiro con los nuevos campos
      final newShot = ShotModel.create(
        userId: widget.user.id,
        matchId: widget.match?.id,
        minute: _minute,
        goalPosition: _selectedGoalPosition!,
        shooterPosition: _selectedShooterPosition!,
        goalkeeperPosition: _selectedGoalkeeperPosition!,
        result: _shotResult,
        shotType: _shotType,
        goalType: _isGoal ? _goalType : null,
        blockType: !_isGoal ? _blockType : null,
        notes: _notes,
      );

      // Guardar tiro en repositorio
      await widget.shotsRepository.createShot(newShot);

      // CORREGIDO: Invalidar caché usando servicio centralizado
      await _dailyLimitsService.invalidateTodayCache(widget.user.id);

      // Notificar al padre
      widget.onDataRegistered?.call();

      // Registrar evento de éxito en crashlytics
      _crashlyticsService.log('Tiro registrado correctamente: ${newShot.id}');

      // Mostrar mensaje de éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tiro registrado correctamente'),
            backgroundColor: Colors.green,
          ),
        );

        // Volver a la pantalla anterior con resultado exitoso
        Navigator.pop(context, true);
      }
    } catch (e) {
      // Registrar error en Crashlytics
      _crashlyticsService.recordError(
        e,
        StackTrace.current,
        reason: 'Error al guardar tiro',
        fatal: false,
      );

      // Mostrar error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar el tiro: $e'),
            backgroundColor: Colors.red,
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

  // CORREGIDO: Método _saveAndRegisterAnother usando servicio centralizado
  Future<void> _saveAndRegisterAnother() async {
    // Verificar que hay conexión
    if (!_isConnected) {
      _connectivityService.showConnectivitySnackBar(context);
      return;
    }

    // CORREGIDO: Verificar límite usando servicio centralizado
    if (!widget.user.subscription.isPremium) {
      final canCreate = await _dailyLimitsService.canCreateShot(widget.user);
      if (!canCreate) {
        _showLimitReachedDialog();
        return;
      }
    }

    // Verificar datos mínimos necesarios
    if (_selectedGoalPosition == null ||
        _selectedShooterPosition == null ||
        _selectedGoalkeeperPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Falta información importante del tiro'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Crear tiro con los nuevos campos
      final newShot = ShotModel.create(
        userId: widget.user.id,
        matchId: widget.match?.id,
        minute: _minute,
        goalPosition: _selectedGoalPosition!,
        shooterPosition: _selectedShooterPosition!,
        goalkeeperPosition: _selectedGoalkeeperPosition!,
        result: _shotResult,
        shotType: _shotType,
        goalType: _isGoal ? _goalType : null,
        blockType: !_isGoal ? _blockType : null,
        notes: _notes,
      );

      // Guardar tiro en repositorio
      await widget.shotsRepository.createShot(newShot);

      // CORREGIDO: Invalidar caché usando servicio centralizado
      await _dailyLimitsService.invalidateTodayCache(widget.user.id);

      // Notificar al padre
      widget.onDataRegistered?.call();

      // Registrar evento de éxito en crashlytics
      _crashlyticsService.log(
          'Tiro registrado correctamente: ${newShot.id} (continuar registrando)');

      // Mostrar mensaje de éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tiro registrado correctamente'),
            backgroundColor: Colors.green,
          ),
        );

        // CORREGIDO: Actualizar información de límites antes de continuar
        if (!widget.user.subscription.isPremium) {
          await _checkFreeTierLimits();

          // Si después de actualizar se alcanza el límite, no permitir continuar
          if (_limitInfo?.hasReachedLimit ?? false) {
            _showLimitReachedDialog();
            return;
          }
        }

        // Reiniciar formulario para registrar otro tiro
        setState(() {
          _currentStep = 1; // Volver al primer paso real
          _selectedGoalPosition = null;
          _selectedShooterPosition = null;
          _selectedGoalkeeperPosition = null;
          _shotResult = ShotModel.RESULT_SAVED;
          _isGoal = false;
          _shotType = null;
          _goalType = null;
          _blockType = null;
          _minute = null;
          _notes = null;
          _minuteController.clear();
          _notesController.clear();
        });
      }
    } catch (e) {
      // Registrar error en Crashlytics
      _crashlyticsService.recordError(
        e,
        StackTrace.current,
        reason: 'Error al guardar tiro (continuar registrando)',
        fatal: false,
      );

      // Mostrar error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar el tiro: $e'),
            backgroundColor: Colors.red,
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

  String _getMatchDescription() {
    if (widget.match == null) return '';

    final match = widget.match!;
    final date = match.date;
    final formattedDate = '${date.day}/${date.month}/${date.year}';

    switch (match.type) {
      case MatchModel.TYPE_OFFICIAL:
        return 'Partido Oficial vs ${match.opponent ?? "Rival"} - $formattedDate';
      case MatchModel.TYPE_FRIENDLY:
        return 'Amistoso vs ${match.opponent ?? "Rival"} - $formattedDate';
      case MatchModel.TYPE_TRAINING:
        return 'Entrenamiento ${match.opponent != null ? "con ${match.opponent}" : ""} - $formattedDate';
      default:
        return 'Partido - $formattedDate';
    }
  }

  IconData _getMatchIcon(String type) {
    switch (type) {
      case MatchModel.TYPE_OFFICIAL:
        return Icons.emoji_events;
      case MatchModel.TYPE_FRIENDLY:
        return Icons.handshake;
      case MatchModel.TYPE_TRAINING:
        return Icons.fitness_center;
      default:
        return Icons.sports_soccer;
    }
  }

  Color _getMatchColor(String type) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    switch (type) {
      case MatchModel.TYPE_OFFICIAL:
        return isDarkMode ? Colors.amber.shade300 : Colors.amber;
      case MatchModel.TYPE_FRIENDLY:
        return isDarkMode ? Colors.blue.shade300 : Colors.blue;
      case MatchModel.TYPE_TRAINING:
        return isDarkMode ? Colors.green.shade300 : Colors.green;
      default:
        return isDarkMode ? Colors.grey.shade300 : Colors.grey;
    }
  }

  // Traducir tipo de tiro
  String _translateShotType(String type) {
    return AppConstants.shotTypes[type] ?? type;
  }

  // Traducir tipo de gol
  String _translateGoalType(String type) {
    return AppConstants.goalTypes[type] ?? type;
  }

  // Traducir tipo de bloqueo
  String _translateBlockType(String type) {
    return AppConstants.blockTypes[type] ?? type;
  }
}
