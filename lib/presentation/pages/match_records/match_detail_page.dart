import 'package:flutter/material.dart';
import 'package:goalkeeper_stats/data/models/match_model.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/data/repositories/firebase_shots_repository.dart';
import 'package:goalkeeper_stats/data/repositories/firebase_auth_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/matches_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/shots_repository.dart';
import 'package:goalkeeper_stats/presentation/pages/match_records/match_form_page.dart';
import 'package:goalkeeper_stats/presentation/pages/shot_records/shot_entry_tab.dart';
import 'package:goalkeeper_stats/services/cache_manager.dart';
import 'package:goalkeeper_stats/services/firebase_crashlytics_service.dart';
import 'package:goalkeeper_stats/services/analytics_service.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:intl/intl.dart';
import 'package:goalkeeper_stats/core/utils/dependency_injection.dart';

/// Página que muestra los detalles de un partido
///
/// Incluye información del partido, estadísticas y acciones relacionadas.
class MatchDetailPage extends StatefulWidget {
  final MatchModel match;
  final MatchesRepository matchesRepository;
  final UserModel user; // Añadido para verificar permiso premium
  final String? preselectedMatchId;
  final bool isConnected;

  const MatchDetailPage({
    Key? key,
    required this.match,
    required this.matchesRepository,
    required this.user,
    this.preselectedMatchId,
    this.isConnected = true,
  }) : super(key: key);

  @override
  State<MatchDetailPage> createState() => _MatchDetailPageState();
}

class _MatchDetailPageState extends State<MatchDetailPage> {
  late Future<Map<String, dynamic>> _statsFuture;
  bool _isLoading = false;
  late MatchModel _match;

  // Repositorio de tiros y servicios
  late ShotsRepository _shotsRepository;
  final CacheManager _cacheManager = CacheManager();
  final FirebaseCrashlyticsService _crashlytics = FirebaseCrashlyticsService();
  final AnalyticsService _analytics = AnalyticsService();

  // Clave para la caché
  String get _statsCacheKey => 'match_stats_${_match.id}';

  @override
  void initState() {
    super.initState();
    _match = widget.match;

    // Inicializar repositorio de Firebase
    _shotsRepository = FirebaseShotsRepository(authRepository: DependencyInjection().authRepository);

    _loadData();

    // Registrar visualización en Analytics
    _analytics.logEvent(
      name:'match_detail_view',
      parameters: {
        'match_id': _match.id,
        'match_type': _match.type,
        'offline_mode': !widget.isConnected,
      },
    );
  }

  void _loadData() {
    _statsFuture = _fetchMatchStats();
  }

  Future<Map<String, dynamic>> _fetchMatchStats() async {
    try {
      // Si no hay conexión, intentar obtener de la caché
      if (!widget.isConnected) {
        final cachedStats =
            await _cacheManager.get<Map<String, dynamic>>(_statsCacheKey);
        if (cachedStats != null) {
          return cachedStats;
        }

        // Si no hay datos en caché, devolver valores por defecto
        return {
          'totalShots': 0,
          'savedShots': 0,
          'goals': 0,
          'savePercentage': 0.0,
          'goalZones': <String, int>{},
          'offline': true,
        };
      }

      // Contar tiros del partido con conexión
      final shots = await _shotsRepository.getShotsByMatch(_match.id);

      // Calcular estadísticas
      int totalShots = shots.length;
      int savedShots = shots.where((shot) => shot.isSaved).length;
      int goals = shots.where((shot) => shot.isGoal).length;
      double savePercentage =
          totalShots > 0 ? (savedShots / totalShots * 100) : 0;

      // Zonas de la portería
      Map<String, int> goalZones = {};
      for (final shot in shots) {
        if (shot.isGoal) {
          goalZones[shot.goalZone] = (goalZones[shot.goalZone] ?? 0) + 1;
        }
      }

      final stats = {
        'totalShots': totalShots,
        'savedShots': savedShots,
        'goals': goals,
        'savePercentage': savePercentage,
        'goalZones': goalZones,
      };

      // Guardar en caché para acceso offline
      await _cacheManager.set<Map<String, dynamic>>(_statsCacheKey, stats,
          duration: 3600);

      return stats;
    } catch (e, stack) {
      // Registrar error en Crashlytics
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'Error al obtener estadísticas del partido',
        fatal: false,
      );

      // Intentar recuperar de caché en caso de error
      final cachedStats =
          await _cacheManager.get<Map<String, dynamic>>(_statsCacheKey);
      if (cachedStats != null) {
        return {
          ...cachedStats,
          'error': 'Usando datos almacenados debido a un error.',
        };
      }

      return {
        'error': e.toString(),
        'totalShots': 0,
        'savedShots': 0,
        'goals': 0,
        'savePercentage': 0.0,
        'goalZones': <String, int>{},
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_getMatchTitle()),
        actions: [
          if (widget.isConnected && widget.user.subscription.isPremium) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _navigateToEditMatch,
              tooltip: 'Editar partido',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _confirmDelete,
              tooltip: 'Eliminar partido',
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            _buildContent(),

          // Indicador de modo sin conexión
          if (!widget.isConnected)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: isDarkMode
                    ? Colors.orange.shade900
                    : Colors.orange.shade100,
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.offline_bolt,
                      size: 18,
                      color: isDarkMode
                          ? Colors.orange.shade300
                          : Colors.orange.shade900,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Modo sin conexión. Algunas funciones no están disponibles.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode
                              ? Colors.orange.shade100
                              : Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton:
          (widget.isConnected && widget.user.subscription.isPremium)
              ? FloatingActionButton.extended(
                  onPressed: _navigateToAddShot,
                  icon: const Icon(Icons.add),
                  label: const Text('Registrar Tiro'),
                )
              : null,
    );
  }

  String _getMatchTitle() {
    switch (_match.type) {
      case MatchModel.TYPE_OFFICIAL:
        return 'Partido Oficial';
      case MatchModel.TYPE_FRIENDLY:
        return 'Partido Amistoso';
      case MatchModel.TYPE_TRAINING:
        return 'Entrenamiento';
      default:
        return 'Partido';
    }
  }

  Widget _buildContent() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tarjeta de info general
          _buildInfoCard(),
          const SizedBox(height: 20),

          // Estadísticas
          Row(
            children: [
              const Text(
                'Estadísticas',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (widget.isConnected)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    setState(() {
                      _loadData();
                    });
                  },
                  tooltip: 'Actualizar estadísticas',
                ),
            ],
          ),
          const SizedBox(height: 8),
          _buildStatsSection(),
          const SizedBox(height: 20),

          // Botones de acción
          _buildActionButtons(),

          // Si no hay conexión, mostrar mensaje informativo
          if (!widget.isConnected)
            Container(
              margin: const EdgeInsets.only(top: 30),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 28,
                    color: isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Funcionalidad limitada sin conexión',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? Colors.grey.shade300
                          : Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Para gestionar tiros y editar partidos, es necesario tener conexión a internet',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),

          // Si no es premium, mostrar banner de actualización
          if (!widget.user.subscription.isPremium)
            Container(
              margin: const EdgeInsets.only(top: 30),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.amber.shade900.withOpacity(0.3)
                    : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDarkMode
                      ? Colors.amber.shade700
                      : Colors.amber.shade300,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.workspace_premium,
                    size: 28,
                    color: isDarkMode
                        ? Colors.amber.shade400
                        : Colors.amber.shade700,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mejora a Premium',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? Colors.amber.shade400
                          : Colors.amber.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Registra tiros ilimitados, gestiona partidos y accede a estadísticas avanzadas',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode
                          ? Colors.amber.shade300
                          : Colors.amber.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      // Navegar a pantalla de suscripción
                      _analytics.logEvent(name:'premium_upgrade_click', parameters: {
                        'screen': 'match_detail',
                        'match_id': _match.id
                      });
                      // Implementar navegación a pantalla de suscripción
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: isDarkMode
                          ? Colors.amber.shade700
                          : Colors.amber.shade500,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Ver planes Premium'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final formattedDate = DateFormat('dd/MM/yyyy').format(_match.date);

    return Card(
      elevation: isDarkMode ? 2 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_match.opponent != null) ...[
              Text(
                'Rival',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey,
                  fontSize: 14,
                ),
              ),
              Text(
                _match.opponent!,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode
                      ? Theme.of(context).colorScheme.onSurface
                      : null,
                ),
              ),
              const Divider(),
            ],
            Row(
              children: [
                Icon(Icons.calendar_today,
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey),
                const SizedBox(width: 8),
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode
                        ? Theme.of(context).colorScheme.onSurface
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_match.venue != null) ...[
              Row(
                children: [
                  Icon(Icons.location_on,
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _match.venue!,
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode
                            ? Theme.of(context).colorScheme.onSurface
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (_match.isOfficial || _match.isFriendly) ...[
              Row(
                children: [
                  Icon(Icons.sports_score,
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Resultado: ${_match.result}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _match.isWin
                          ? (isDarkMode ? Colors.green.shade300 : Colors.green)
                          : _match.isLoss
                              ? (isDarkMode ? Colors.red.shade300 : Colors.red)
                              : _match.isDraw
                                  ? (isDarkMode
                                      ? Colors.amber.shade300
                                      : Colors.amber.shade800)
                                  : (isDarkMode
                                      ? Colors.grey.shade300
                                      : Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (_match.notes != null && _match.notes!.isNotEmpty) ...[
              const Divider(),
              Text(
                'Notas',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _match.notes!,
                style: TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: isDarkMode
                      ? Theme.of(context).colorScheme.onSurface
                      : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<Map<String, dynamic>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError ||
            (snapshot.hasData && snapshot.data!.containsKey('error'))) {
          return Center(
            child: Column(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 40,
                  color: isDarkMode ? Colors.red.shade300 : Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error al cargar estadísticas',
                  style: TextStyle(
                    color: isDarkMode ? Colors.red.shade300 : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (snapshot.data?.containsKey('error') ?? false)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 8.0),
                    child: Text(
                      snapshot.data!['error'],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode
                            ? Colors.grey.shade300
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                if (widget.isConnected)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _loadData();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
              ],
            ),
          );
        }

        final stats = snapshot.data!;
        final totalShots = stats['totalShots'];
        final savedShots = stats['savedShots'];
        final goals = stats['goals'];
        final savePercentage = stats['savePercentage'];
        final isOffline = stats['offline'] == true;

        if (totalShots == 0) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.sports_soccer,
                      size: 40,
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No hay datos de tiros para este partido',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    if (isOffline)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Conecta a internet para ver datos actualizados',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode
                                ? Colors.orange.shade300
                                : Colors.orange.shade800,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }

        return Column(
          children: [
            if (isOffline)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                decoration: BoxDecoration(
                  color:
                      isDarkMode ? Colors.blue.shade900 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info,
                      size: 16,
                      color: isDarkMode
                          ? Colors.blue.shade300
                          : Colors.blue.shade800,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Mostrando datos almacenados',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode
                            ? Colors.blue.shade300
                            : Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Tiros',
                    value: totalShots.toString(),
                    icon: Icons.sports_soccer,
                    color: isDarkMode ? Colors.blue.shade300 : Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: 'Atajadas',
                    value: savedShots.toString(),
                    icon: Icons.security,
                    color: isDarkMode ? Colors.green.shade300 : Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Goles',
                    value: goals.toString(),
                    icon: Icons.sports_score,
                    color: isDarkMode ? Colors.red.shade300 : Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: 'Efectividad',
                    value: '${savePercentage.toStringAsFixed(1)}%',
                    icon: Icons.percent,
                    color: isDarkMode ? Colors.purple.shade300 : Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: isDarkMode ? 1 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final isPremium = widget.user.subscription.isPremium;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        OutlinedButton.icon(
          onPressed:
              (widget.isConnected && isPremium) ? _navigateToAddShot : null,
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Registrar Tiro'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: (widget.isConnected && isPremium)
              ? () {
                  // Navegar a estadísticas detalladas del partido
                  _analytics.logEvent(name:'match_detailed_stats_view', parameters: {
                    'match_id': _match.id,
                    'match_type': _match.type,
                  });

                  // Mostrar mensaje de función próximamente
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Función disponible próximamente'),
                    ),
                  );
                }
              : null,
          icon: const Icon(Icons.bar_chart),
          label: const Text('Ver Detalles'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToAddShot() {
    if (!widget.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pueden registrar tiros sin conexión'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!widget.user.subscription.isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta función requiere una suscripción Premium'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    // Registrar evento en Analytics
    _analytics.logEvent(name:'add_shot_from_match', parameters: {
      'match_id': _match.id,
      'match_type': _match.type,
    });

    // Navegar a la pantalla de registro con el partido preseleccionado
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShotEntryTab(
          user: widget.user,
          matchesRepository: widget.matchesRepository,
          shotsRepository: _shotsRepository,
          passesRepository: DependencyInjection().passesRepository, // Será proporcionado por la pantalla real
          //preselectedMatchId: _match.id,
          isConnected: true,
        ),
      ),
    ).then((_) {
      // Recargar estadísticas al volver
      _loadData();
    });
  }

  void _navigateToEditMatch() async {
    if (!widget.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se puede editar sin conexión'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!widget.user.subscription.isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta función requiere una suscripción Premium'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    // Registrar evento en Analytics
    _analytics.logEvent(name:'edit_match', parameters: {
      'match_id': _match.id,
      'match_type': _match.type,
    });

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MatchFormPage(
          userId: _match.userId,
          matchesRepository: widget.matchesRepository,
          match: _match,
          
          user: widget.user,
        ),
      ),
    );

    if (result != null && result is MatchModel) {
      // Actualizar con el partido retornado
      setState(() {
        _match = result;
        _loadData();
      });
    }
  }

  void _confirmDelete() {
    if (!widget.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se puede eliminar sin conexión'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!widget.user.subscription.isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta función requiere una suscripción Premium'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Partido'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar este partido? '
          'Esta acción no se puede deshacer y se eliminarán todos los tiros asociados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color:
                    isDarkMode ? Theme.of(context).colorScheme.primary : null,
              ),
            ),
          ),
          TextButton(
            onPressed: _deleteMatch,
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMatch() async {
    Navigator.pop(context); // Cerrar diálogo

    setState(() {
      _isLoading = true;
    });

    try {
      await widget.matchesRepository.deleteMatch(_match.id);

      // Eliminar caché
      await _cacheManager.remove(_statsCacheKey);

      // Registrar evento en Analytics
      _analytics.logEvent(name:'delete_match', parameters: {
        'match_id': _match.id,
        'match_type': _match.type,
      });

      // Volver a la pantalla anterior
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Partido eliminado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e, stack) {
      // Registrar error en Crashlytics
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'Error al eliminar partido',
        fatal: false,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar partido: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
