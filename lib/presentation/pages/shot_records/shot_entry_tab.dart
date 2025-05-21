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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ShotEntryTab extends StatefulWidget {
  final UserModel user;
  final MatchesRepository matchesRepository;
  final ShotsRepository shotsRepository;
  final GoalkeeperPassesRepository passesRepository;
  final String? preSelectedMatchId; // Parámetro para preseleccionar partido
  final Function? onDataRegistered; // Callback para notificar registros
  
  final bool isConnected; // <-- Añadir parámetro

  const ShotEntryTab({
    Key? key,
    required this.user,
    required this.matchesRepository,
    required this.shotsRepository,
    required this.passesRepository,
    required this.isConnected, // <-- Incluir en el constructor
    
    this.preSelectedMatchId,
    this.onDataRegistered,
  }) : super(key: key);

  @override
  State<ShotEntryTab> createState() => _ShotEntryTabState();
}

class _ShotEntryTabState extends State<ShotEntryTab> {
  bool _isLoading = false;
  MatchModel? _preSelectedMatch; // Para almacenar el partido preseleccionado
  bool _isConnected = true;
  final CacheManager _cacheManager = CacheManager();
  final ConnectivityService _connectivityService = ConnectivityService();
  final FirebaseCrashlyticsService _crashlyticsService =
      FirebaseCrashlyticsService();
  int _todayShotsCount = 0;
  bool _isLoadingLimit = false;

  @override
  void initState() {
    super.initState();
    _setupConnectivity();
    _checkFreeTierLimits();

    // Si hay un ID de partido preseleccionado, cargarlo
    if (widget.preSelectedMatchId != null) {
      _loadPreSelectedMatch();
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

  Future<void> _checkFreeTierLimits() async {
    if (widget.user.subscription.isPremium) {
      return; // No hay límites para usuarios premium
    }

    setState(() {
      _isLoadingLimit = true;
    });

    try {
      // Verificar si hay datos en caché
      final cachedCount =
          await _cacheManager.get<int>('todayShotsCount_${widget.user.id}');
      if (cachedCount != null) {
        setState(() {
          _todayShotsCount = cachedCount;
          _isLoadingLimit = false;
        });
        return;
      }

      // Obtener conteo desde Firestore con timeframe preciso
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

      final shotsSnapshot = await FirebaseFirestore.instance
          .collection('shots')
          .where('userId', isEqualTo: widget.user.id)
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThanOrEqualTo: endOfDay)
          .get();

      final count = shotsSnapshot.docs.length;

      // Guardar en caché por 5 minutos
      await _cacheManager.set<int>('todayShotsCount_${widget.user.id}', count,
          duration: 300);

      setState(() {
        _todayShotsCount = count;
      });
    } catch (e) {
      _crashlyticsService.recordError(
        e,
        StackTrace.current,
        reason: 'Error al verificar límite de tiros diarios',
      );
      // Enfoque conservador: asumir que ya alcanzó el límite
      setState(() {
        _todayShotsCount = 20;
      });
    } finally {
      setState(() {
        _isLoadingLimit = false;
      });
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

  // Método para navegar al formulario de tiro con un partido específico
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

    // Si se regresa con un resultado exitoso, notificar y actualizar contadores
    if (result == true) {
      widget.onDataRegistered?.call();

      // Invalidar caché de límites para usuarios gratuitos
      if (!widget.user.subscription.isPremium) {
        await _cacheManager.remove('todayShotsCount_${widget.user.id}');
        _checkFreeTierLimits();
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

  Widget _buildContent() {
    final isPremium = widget.user.subscription.isPremium;
    final hasReachedLimit = _todayShotsCount >= 20;

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

            // Límite de tiros para usuarios gratuitos
            if (!isPremium)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: hasReachedLimit
                      ? Colors.red.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: hasReachedLimit
                          ? Colors.red.shade200
                          : Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasReachedLimit
                          ? Icons.error_outline
                          : Icons.check_circle,
                      color: hasReachedLimit ? Colors.red : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _isLoadingLimit
                          ? const Text("Verificando límites diarios...")
                          : Text(
                              hasReachedLimit
                                  ? 'Has alcanzado el límite de 20 tiros diarios. Actualiza a Premium para eliminar esta restricción.'
                                  : 'Tiros registrados hoy: $_todayShotsCount de 20',
                              style: TextStyle(
                                color: hasReachedLimit
                                    ? Colors.red.shade700
                                    : Colors.green.shade700,
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
              onTap: !_isConnected ? null : _startPassRegistration,
              disabled: !_isConnected,
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
                        'Con Premium podrás registrar tiros ilimitados, organizar por partidos y acceder a todas las estadísticas avanzadas.',
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
        content: const Text(
            'Has alcanzado el límite de 20 tiros diarios para usuarios gratuitos. '
            'Actualiza a Premium para registrar tiros ilimitados y tener acceso '
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

  void _startShotRegistration() async {
    final isPremium = widget.user.subscription.isPremium;

    if (!_isConnected) {
      _connectivityService.showConnectivitySnackBar(context);
      return;
    }

    // Verificar límite de tiros para usuarios gratuitos
    if (!isPremium && _todayShotsCount >= 20) {
      _showLimitReachedDialog();
      return;
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

          // Si se regresa con un resultado exitoso, notificar y actualizar conteo
          if (shotResult == true) {
            widget.onDataRegistered?.call();
            await _cacheManager.remove('todayShotsCount_${widget.user.id}');
            _checkFreeTierLimits();
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
            user: widget.user,  // Añadir este parámetro obligatorio
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
