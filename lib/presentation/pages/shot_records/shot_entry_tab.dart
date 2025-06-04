// lib/presentation/pages/shot_records/shot_entry_tab.dart
// CORREGIDO: Con debugging mejorado para límites diarios
// ACTUALIZADO: Debug solo para usuarios premium

import 'package:flutter/material.dart';
import 'package:goalkeeper_stats/data/models/match_model.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/domain/repositories/goalkeeper_passes_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/matches_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/shots_repository.dart';
import 'package:goalkeeper_stats/presentation/pages/shot_records/shot_form_page.dart';
import 'package:goalkeeper_stats/presentation/pages/match_records/match_selection_page.dart';
import 'package:goalkeeper_stats/presentation/pages/match_records/match_form_page.dart';
import 'package:goalkeeper_stats/presentation/pages/goalkeeper_passes/goalkeeper_pass_entry_tab.dart';
import 'package:goalkeeper_stats/services/cache_manager.dart';
import 'package:goalkeeper_stats/services/connectivity_service.dart';
import 'package:goalkeeper_stats/services/firebase_crashlytics_service.dart';
import 'package:goalkeeper_stats/services/daily_limits_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ShotEntryTab extends StatefulWidget {
  final UserModel user;
  final MatchesRepository matchesRepository;
  final ShotsRepository shotsRepository;
  final GoalkeeperPassesRepository passesRepository;
  final String? preSelectedMatchId;
  final Function? onDataRegistered;
  final bool isConnected;

  const ShotEntryTab({
    Key? key,
    required this.user,
    required this.matchesRepository,
    required this.shotsRepository,
    required this.passesRepository,
    required this.isConnected,
    this.preSelectedMatchId,
    this.onDataRegistered,
  }) : super(key: key);

  @override
  State<ShotEntryTab> createState() => _ShotEntryTabState();
}

class _ShotEntryTabState extends State<ShotEntryTab> {
  bool _isLoading = false;
  MatchModel? _preSelectedMatch;
  bool _isConnected = true;
  final CacheManager _cacheManager = CacheManager();
  final ConnectivityService _connectivityService = ConnectivityService();
  final FirebaseCrashlyticsService _crashlyticsService =
      FirebaseCrashlyticsService();

  // Servicio centralizado de límites
  late final DailyLimitsService _dailyLimitsService;
  DailyLimitInfo? _limitInfo;
  bool _isLoadingLimit = false;

  @override
  void initState() {
    super.initState();

    // Inicializar servicio de límites
    _dailyLimitsService = DailyLimitsService(
      cacheManager: _cacheManager,
      crashlyticsService: _crashlyticsService,
    );

    _setupConnectivity();
    _checkFreeTierLimits();

    // Si hay un ID de partido preseleccionado, cargarlo
    if (widget.preSelectedMatchId != null) {
      _loadPreSelectedMatch();
    }

    // DEBUG: Solo para usuarios premium en modo debug
    if (kDebugMode && widget.user.subscription.isPremium) {
      _debugFirestoreData();
    }
  }

  @override
  void dispose() {
    _connectivityService.dispose();
    super.dispose();
  }

  void _setupConnectivity() {
    _connectivityService.onConnectivityChanged.listen((result) {
      setState(() {
        _isConnected = result == ConnectivityResult.wifi ||
            result == ConnectivityResult.mobile ||
            result == ConnectivityResult.ethernet;
      });

      if (_isConnected && mounted) {
        _connectivityService.showConnectivitySnackBar(context);
      }
    });

    _connectivityService.checkConnectivity().then((connected) {
      setState(() {
        _isConnected = connected;
      });
    });
  }

  // CORREGIDO: Método mejorado con debugging
  Future<void> _checkFreeTierLimits() async {
    if (widget.user.subscription.isPremium) {
      debugPrint('✅ Usuario premium - saltando verificación de límites');
      return;
    }

    setState(() {
      _isLoadingLimit = true;
    });

    try {
      debugPrint('🔍 Verificando límites para usuario: ${widget.user.id}');

      final limitInfo = await _dailyLimitsService.getLimitInfo(widget.user);

      debugPrint('📊 Información de límites obtenida: $limitInfo');

      setState(() {
        _limitInfo = limitInfo;
        _isLoadingLimit = false;
      });
    } catch (e) {
      debugPrint('❌ Error al verificar límites: $e');

      _crashlyticsService.recordError(
        e,
        StackTrace.current,
        reason: 'Error al verificar límite de tiros diarios en entry tab',
      );

      setState(() {
        _isLoadingLimit = false;
        // En caso de error, asumir límite alcanzado para usuarios gratuitos
        _limitInfo = DailyLimitInfo(
          isPremium: false,
          dailyLimit: 20,
          todayCount: 20,
          hasReachedLimit: true,
          remainingShots: 0,
        );
      });
    }
  }

  // ACTUALIZADO: Método para debug de datos en Firestore (solo premium)
  Future<void> _debugFirestoreData() async {
    // Solo permitir debug para usuarios premium
    if (!widget.user.subscription.isPremium) {
      debugPrint('🚫 Debug restringido - Usuario no premium');
      return;
    }

    try {
      debugPrint('🚀 INICIANDO DEBUG DE FIRESTORE (USUARIO PREMIUM)...');
      final debugInfo =
          await _dailyLimitsService.debugFirestoreData(widget.user.id);

      debugPrint('🔍 INFORMACIÓN COMPLETA DE DEBUG:');
      debugPrint('${debugInfo.toString()}');
    } catch (e) {
      debugPrint('❌ Error en debug de Firestore: $e');
    }
  }

  // Método para cargar el partido preseleccionado
  Future<void> _loadPreSelectedMatch() async {
    if (widget.preSelectedMatchId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Verificar caché primero
      final String cacheKey = 'match_${widget.preSelectedMatchId}';
      final cachedMatch =
          await _cacheManager.get<Map<String, dynamic>>(cacheKey);

      if (cachedMatch != null) {
        final match =
            MatchModel.fromMap(cachedMatch, widget.preSelectedMatchId!);
        setState(() {
          _preSelectedMatch = match;
        });

        // Navegar directamente al formulario
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigateToShotForm(match);
        });
        return;
      }

      // Si no está en caché, obtener de Firestore
      final match = await widget.matchesRepository
          .getMatchById(widget.preSelectedMatchId!);

      if (match != null) {
        // Guardar en caché por 1 hora
        await _cacheManager.set<Map<String, dynamic>>(cacheKey, match.toMap(),
            duration: 3600);

        setState(() {
          _preSelectedMatch = match;
        });

        // Navegar directamente al formulario de tiro con el partido preseleccionado
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigateToShotForm(match);
        });
      }
    } catch (e) {
      _crashlyticsService.recordError(
        e,
        StackTrace.current,
        reason: 'Error al cargar partido preseleccionado',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar partido: $e'),
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

  // CORREGIDO: Método con invalidación de caché mejorada
  void _navigateToShotForm(MatchModel match) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShotFormPage(
          user: widget.user,
          match: match,
          shotsRepository: widget.shotsRepository,
          onDataRegistered: widget.onDataRegistered,
        ),
      ),
    );

    // Si se regresa con éxito, actualizar límites
    if (result == true) {
      widget.onDataRegistered?.call();

      // Invalidar caché de límites para usuarios gratuitos
      if (!widget.user.subscription.isPremium) {
        debugPrint('🔄 Invalidando caché después del registro exitoso...');
        await _dailyLimitsService.invalidateTodayCache(widget.user.id);
        _checkFreeTierLimits(); // Recargar información de límites
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Datos'),
        actions: [
          if (!_isConnected)
            IconButton(
              icon: const Icon(Icons.wifi_off),
              onPressed: () =>
                  _connectivityService.showConnectivitySnackBar(context),
              tooltip: 'Sin conexión',
            ),
          // ACTUALIZADO: Botón de debug solo para usuarios premium en modo desarrollo
          if (kDebugMode && widget.user.subscription.isPremium)
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: _debugFirestoreData,
              tooltip: 'Debug Firestore (Premium)',
            ),
        ],
      ),
      body: _isLoading ? _buildLoadingIndicator() : _buildContent(),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Cargando...'),
        ],
      ),
    );
  }

  // CORREGIDO: Contenido con información de debug mejorada
  Widget _buildContent() {
    final isPremium = widget.user.subscription.isPremium;
    final hasReachedLimit = _limitInfo?.hasReachedLimit ?? false;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Advertencia de conectividad
            if (!_isConnected)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sin conexión a internet. Algunas funciones pueden no estar disponibles.',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),

            // CORREGIDO: Card de límites con información detallada
            if (!isPremium)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _isLoadingLimit
                      ? Colors.blue.shade50
                      : hasReachedLimit
                          ? Colors.red.shade50
                          : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isLoadingLimit
                        ? Colors.blue.shade200
                        : hasReachedLimit
                            ? Colors.red.shade200
                            : Colors.green.shade200,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isLoadingLimit
                              ? Icons.hourglass_empty
                              : hasReachedLimit
                                  ? Icons.error_outline
                                  : Icons.check_circle,
                          color: _isLoadingLimit
                              ? Colors.blue
                              : hasReachedLimit
                                  ? Colors.red
                                  : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _isLoadingLimit
                              ? const Text("Verificando límites diarios...")
                              : Text(
                                  _limitInfo?.displayMessage ??
                                      'Información no disponible',
                                  style: TextStyle(
                                    color: hasReachedLimit
                                        ? Colors.red.shade700
                                        : Colors.green.shade700,
                                  ),
                                ),
                        ),
                      ],
                    ),
                    // ACTUALIZADO: Información detallada solo para usuarios premium en modo debug
                    if (kDebugMode &&
                        widget.user.subscription.isPremium &&
                        _limitInfo != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DEBUG INFO (PREMIUM):',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              Text(
                                'Límite: ${_limitInfo!.dailyLimit}',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade700),
                              ),
                              Text(
                                'Hoy: ${_limitInfo!.todayCount}',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade700),
                              ),
                              Text(
                                'Restantes: ${_limitInfo!.remainingShots}',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade700),
                              ),
                              Text(
                                'Límite alcanzado: ${_limitInfo!.hasReachedLimit}',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // Tarjeta de registro de tiros
            _buildActionCard(
              title: 'Registrar Tiro',
              icon: Icons.sports_soccer,
              color: Colors.blue,
              description:
                  'Registra un nuevo tiro con posiciones en el campo y resultado.',
              onTap: !isPremium && hasReachedLimit
                  ? _showLimitReachedDialog
                  : _startShotRegistration,
              disabled: !_isConnected || (!isPremium && hasReachedLimit),
            ),

            const SizedBox(height: 16),

            // Tarjeta de registro de saques
            _buildActionCard(
              title: 'Registrar Saque',
              icon: Icons.sports_handball,
              color: Colors.purple,
              description:
                  'Registra un saque realizado con su tipo y resultado.',
              onTap: !isPremium && hasReachedLimit
                  ? _showLimitReachedDialog
                  : !_isConnected
                      ? null
                      : _startPassRegistration,
              disabled: !_isConnected || (!isPremium && hasReachedLimit),
            ),

            if (isPremium) ...[
              const SizedBox(height: 16),

              // Tarjeta para crear partido (solo premium)
              _buildActionCard(
                title: 'Crear Partido',
                icon: Icons.add_to_photos,
                color: Colors.green,
                description:
                    'Registra un nuevo partido o entrenamiento para organizar tus estadísticas.',
                onTap: !_isConnected ? null : _createNewMatch,
                disabled: !_isConnected,
              ),
            ],

            const SizedBox(height: 24),

            // Información para usuarios gratuitos
            if (!isPremium)
              Card(
                color: Colors.amber.shade50,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber),
                          SizedBox(width: 8),
                          Text(
                            'Mejora a Premium',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Con Premium podrás registrar tiros y saques ilimitados, organizar por partidos y acceder a todas las estadísticas avanzadas.',
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          // Navegar a pantalla de suscripción
                          Navigator.pushNamed(context, '/subscription');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Ver planes Premium'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required String description,
    required VoidCallback? onTap,
    bool disabled = false,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor:
                    disabled ? Colors.grey.shade200 : color.withOpacity(0.2),
                child: Icon(
                  icon,
                  color: disabled ? Colors.grey : color,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: disabled ? Colors.grey : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: disabled ? Colors.grey : Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: disabled ? Colors.grey.shade300 : Colors.grey.shade400,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLimitReachedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Límite diario alcanzado'),
        content: Text(_limitInfo?.displayMessage ??
            'Has alcanzado el límite de 20 registros diarios para usuarios gratuitos. '
                'Actualiza a Premium para registrar tiros y saques ilimitados y tener acceso '
                'a todas las funciones.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navegar a pantalla de suscripción
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

  void _startPassRegistration() async {
    final isPremium = widget.user.subscription.isPremium;

    if (!_isConnected) {
      _connectivityService.showConnectivitySnackBar(context);
      return;
    }

    // CORREGIDO: Verificar límite usando servicio centralizado
    if (!isPremium) {
      final canCreate = await _dailyLimitsService.canCreatePass(widget.user);
      if (!canCreate) {
        _showLimitReachedDialog();
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (isPremium) {
        // Usuarios premium: primero seleccionan un partido
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MatchSelectionPage(
              user: widget.user,
              matchesRepository: widget.matchesRepository,
              onMatchCreated: _createNewMatch,
            ),
          ),
        );

        // Si se seleccionó un partido, navegar al formulario de saques
        if (result != null && result is MatchModel) {
          if (mounted) {
            final passResult = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GoalkeeperPassEntryTab(
                  user: widget.user,
                  match: result,
                  passesRepository: widget.passesRepository,
                  matchesRepository: widget.matchesRepository,
                  onDataRegistered: widget.onDataRegistered,
                ),
              ),
            );

            // Si se regresa con un resultado exitoso, notificar
            if (passResult == true) {
              widget.onDataRegistered?.call();
              // CORREGIDO: Invalidar caché después del registro
              await _dailyLimitsService.invalidateTodayCache(widget.user.id);
              _checkFreeTierLimits();
            }
          }
        }
      } else {
        // Usuarios gratuitos: directamente al formulario de saques
        if (mounted) {
          final passResult = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GoalkeeperPassEntryTab(
                user: widget.user,
                match: null, // Sin partido asociado
                passesRepository: widget.passesRepository,
                matchesRepository: widget.matchesRepository,
                onDataRegistered: widget.onDataRegistered,
              ),
            ),
          );

          // Si se regresa con un resultado exitoso, notificar
          if (passResult == true) {
            widget.onDataRegistered?.call();
            // CORREGIDO: Invalidar caché después del registro
            await _dailyLimitsService.invalidateTodayCache(widget.user.id);
            _checkFreeTierLimits();
          }
        }
      }
    } catch (e) {
      _crashlyticsService.recordError(
        e,
        StackTrace.current,
        reason: 'Error al iniciar registro de saque',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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

  // CORREGIDO: Método con verificación de límites mejorada
  void _startShotRegistration() async {
    final isPremium = widget.user.subscription.isPremium;

    if (!_isConnected) {
      _connectivityService.showConnectivitySnackBar(context);
      return;
    }

    // CORREGIDO: Verificar límite usando servicio centralizado
    if (!isPremium) {
      final canCreate = await _dailyLimitsService.canCreateShot(widget.user);
      if (!canCreate) {
        _showLimitReachedDialog();
        return;
      }
    }

    // Si ya hay un partido preseleccionado, usarlo directamente
    if (_preSelectedMatch != null) {
      _navigateToShotForm(_preSelectedMatch!);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (isPremium) {
        // Usuarios premium: primero seleccionan un partido
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MatchSelectionPage(
              user: widget.user,
              matchesRepository: widget.matchesRepository,
              onMatchCreated: _createNewMatch,
            ),
          ),
        );

        // Si se seleccionó un partido, navegar al formulario de tiro
        if (result != null && result is MatchModel) {
          if (mounted) {
            _navigateToShotForm(result);
          }
        }
      } else {
        // Usuarios gratuitos: directamente al formulario de tiro
        if (mounted) {
          final shotResult = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ShotFormPage(
                user: widget.user,
                match: null, // Sin partido asociado
                shotsRepository: widget.shotsRepository,
                onDataRegistered: widget.onDataRegistered,
              ),
            ),
          );

          // CORREGIDO: Si se regresa con éxito, actualizar límites
          if (shotResult == true) {
            widget.onDataRegistered?.call();
            await _dailyLimitsService.invalidateTodayCache(widget.user.id);
            _checkFreeTierLimits(); // Recargar información de límites
          }
        }
      }
    } catch (e) {
      _crashlyticsService.recordError(
        e,
        StackTrace.current,
        reason: 'Error al iniciar registro de tiro',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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

  void _createNewMatch() async {
    if (!_isConnected) {
      _connectivityService.showConnectivitySnackBar(context);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Navegar a la página de creación de partido
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MatchFormPage(
            userId: widget.user.id,
            matchesRepository: widget.matchesRepository,
            user: widget.user,
          ),
        ),
      );

      // Verificar si se recibió un partido como resultado
      if (result != null && result is MatchModel && mounted) {
        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Partido creado correctamente'),
            backgroundColor: Colors.green,
          ),
        );

        // Notificar cambio de datos
        widget.onDataRegistered?.call();

        // Redireccionar al formulario de tiro con el partido recién creado
        _navigateToShotForm(result);
      }
    } catch (e) {
      _crashlyticsService.recordError(
        e,
        StackTrace.current,
        reason: 'Error al crear partido',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear partido: $e'),
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
}
