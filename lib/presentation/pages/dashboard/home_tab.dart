import 'package:flutter/material.dart';
import 'package:goalkeeper_stats/data/models/match_model.dart';
import 'package:goalkeeper_stats/data/models/shot_model.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/domain/repositories/matches_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/shots_repository.dart';
import 'package:goalkeeper_stats/presentation/pages/subscription/subscription_page.dart';
import 'package:goalkeeper_stats/services/cache_manager.dart';
import 'package:goalkeeper_stats/services/firebase_crashlytics_service.dart';
import 'package:intl/intl.dart';

class HomeTab extends StatefulWidget {
  final UserModel user;
  final ShotsRepository shotsRepository;
  final MatchesRepository matchesRepository;
  final bool forceRefresh;
  final bool isConnected;

  const HomeTab({
    super.key,
    required this.user,
    required this.shotsRepository,
    required this.matchesRepository,
    this.forceRefresh = false,
    this.isConnected = true,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late Future<Map<String, int>> _shotStatsFuture;
  late Future<List<MatchModel>> _recentMatchesFuture;
  bool _isLoading = false;
  final CacheManager _cacheManager = CacheManager();
  final FirebaseCrashlyticsService _crashlytics = FirebaseCrashlyticsService();

  // Clave para cache de estadísticas
  static const String _statsCacheKey = 'home_stats_';
  static const String _matchesCacheKey = 'home_recent_matches_';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Si cambia la conectividad o se fuerza actualización, recargar datos
    if (widget.forceRefresh && !oldWidget.forceRefresh ||
        widget.isConnected != oldWidget.isConnected && widget.isConnected) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Iniciar ambas cargas en paralelo
      _shotStatsFuture = _loadShotStats();
      _recentMatchesFuture = _loadRecentMatches();

      // Permitir que el indicador de carga se muestre brevemente
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e, stack) {
      _crashlytics.recordError(
        e,
        stack,
        reason: 'Error cargando datos del HomeTab',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, int>> _loadShotStats() async {
    final String cacheKey = _statsCacheKey + widget.user.id;

    try {
      // Si no hay conexión, intentar usar la caché
      if (!widget.isConnected) {
        final cachedStats = await _cacheManager.get<Map<String, int>>(cacheKey);
        if (cachedStats != null) {
          return cachedStats;
        }
        // Si no hay caché, retornar valores por defecto
        return {'total': 0, 'goal': 0, 'saved': 0};
      }

      // Con conexión, obtener datos actualizados
      final stats =
          await widget.shotsRepository.countShotsByResult(widget.user.id);

      // Guardar en caché para uso offline
      await _cacheManager.set<Map<String, int>>(cacheKey, stats,
          duration: 3600); // 1 hora

      return stats;
    } catch (e, stack) {
      _crashlytics.recordError(
        e,
        stack,
        reason: 'Error cargando estadísticas de tiros',
      );

      // Intentar recuperar de caché
      final cachedStats = await _cacheManager.get<Map<String, int>>(cacheKey);
      if (cachedStats != null) {
        return cachedStats;
      }

      // Si todo falla, retornar valores por defecto
      return {'total': 0, 'goal': 0, 'saved': 0};
    }
  }

  Future<List<MatchModel>> _loadRecentMatches() async {
    final String cacheKey = _matchesCacheKey + widget.user.id;

    try {
      // Si no hay conexión, intentar usar la caché
      if (!widget.isConnected) {
        final cachedMatches = await _cacheManager.get<List<dynamic>>(cacheKey);
        if (cachedMatches != null) {
          // Convertir la lista dinámica a MatchModel
          return [];
        }
        return [];
      }

      // Obtener matches pasados (hasta hoy)
      final now = DateTime.now();
      final pastDate =
          DateTime(now.year - 1, now.month, now.day); // 1 año atrás

      final matches = await widget.matchesRepository.getMatchesByDateRange(
        widget.user.id,
        pastDate,
        now,
      );

      // Ordenar de más reciente a más antiguo y limitar a 5
      matches.sort((a, b) => b.date.compareTo(a.date));
      final recentMatches = matches.take(5).toList();

      // Guardar en caché
      await _cacheManager.set(cacheKey, recentMatches, duration: 3600);

      return recentMatches;
    } catch (e, stack) {
      _crashlytics.recordError(
        e,
        stack,
        reason: 'Error cargando partidos recientes',
      );

      // Intentar recuperar de caché en caso de error
      final cachedMatches = await _cacheManager.get<List<dynamic>>(cacheKey);
      if (cachedMatches != null) {
        return [];
      }
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        //title: const Text('Inicio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: widget.isConnected ? () => _loadData() : null,
            tooltip: widget.isConnected ? 'Actualizar' : 'Sin conexión',
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              if (widget.isConnected) {
                await _loadData();
              }
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tarjeta de bienvenida
                  _buildWelcomeCard(),
                  const SizedBox(height: 20),

                  // Resumen de estadísticas
                  _buildStatsSummary(),
                  const SizedBox(height: 20),

                  // Próximos partidos
                  _buildRecentMatches(),
                  const SizedBox(height: 20),

                  // Estado de la suscripción
                  _buildSubscriptionInfo(),

                  // Si no hay conexión, mostrar mensaje
                  if (!widget.isConnected)
                    Padding(
                      padding: const EdgeInsets.only(top: 30.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.cloud_off,
                                size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'Mostrando datos guardados',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Algunas funciones requieren conexión a internet',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Indicador de carga superpuesto
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.1),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundImage: widget.user.photoUrl != null
                  ? NetworkImage(widget.user.photoUrl!)
                  : null,
              child: widget.user.photoUrl == null
                  ? const Icon(Icons.person, size: 40)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¡Hola, ${widget.user.name}!',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.user.subscription.isPremium
                        ? '¡Disfrutando de tu suscripción Premium!'
                        : 'Utilizando la versión gratuita',
                    style: TextStyle(
                      fontSize: 14,
                      color: widget.user.subscription.isPremium
                          ? Colors.green
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resumen de Actividad',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<Map<String, int>>(
          future: _shotStatsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 30.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline,
                          color: Colors.red[300], size: 40),
                      const SizedBox(height: 8),
                      Text(
                        'Error al cargar estadísticas',
                        style: TextStyle(color: Colors.red[300]),
                      ),
                      if (widget.isConnected)
                        TextButton(
                          onPressed: _loadData,
                          child: const Text('Reintentar'),
                        ),
                    ],
                  ),
                ),
              );
            }

            final stats = snapshot.data ?? {'total': 0, 'goal': 0, 'saved': 0};
            final totalShots = stats['total'] ?? 0;
            final savedShots = stats['saved'] ?? 0;
            final goalShots = stats['goal'] ?? 0;

            // Calcular porcentaje de atajadas
            final savePercentage = totalShots > 0
                ? (savedShots / totalShots * 100).toStringAsFixed(1)
                : '0.0';

            return Column(
              children: [
                Row(
                  children: [
                    _buildStatCard(
                      'Tiros Totales',
                      totalShots.toString(),
                      Icons.sports_soccer,
                      Colors.blue,
                    ),
                    const SizedBox(width: 10),
                    _buildStatCard(
                      'Atajadas',
                      savedShots.toString(),
                      Icons.security,
                      Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildStatCard(
                      'Goles Recibidos',
                      goalShots.toString(),
                      Icons.sports_score,
                      Colors.red,
                    ),
                    const SizedBox(width: 10),
                    _buildStatCard(
                      'Porcentaje',
                      '$savePercentage%',
                      Icons.percent,
                      Colors.purple,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecentMatches() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Partidos Recientes',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<MatchModel>>(
          future: _recentMatchesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error al cargar partidos',
                  style: TextStyle(color: Colors.red[300]),
                ),
              );
            }

            final matches = snapshot.data ?? [];

            if (matches.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.sports_soccer,
                            size: 40, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        const Text(
                          'No hay partidos recientes',
                          style: TextStyle(color: Colors.grey),
                        ),
                        if (widget.user.subscription.isPremium)
                          TextButton(
                            onPressed: () {
                              // Navegar a la pestaña de partidos
                              final scaffold = Scaffold.of(context);
                              if (scaffold.hasDrawer) {
                                Navigator.of(context).pop();
                              }
                              DefaultTabController.of(context)?.animateTo(1);
                            },
                            child: const Text('Registrar un partido'),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: matches.length,
              itemBuilder: (context, index) {
                final match = matches[index];
                return _buildMatchCard(match);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildMatchCard(MatchModel match) {
    // Formatear fecha
    final date = match.date;
    final formattedDate = DateFormat('dd/MM/yyyy').format(date);

    // Determinar icono según tipo de partido
    IconData matchIcon;
    Color matchColor;

    switch (match.type) {
      case MatchModel.TYPE_OFFICIAL:
        matchIcon = Icons.emoji_events;
        matchColor = Colors.amber;
        break;
      case MatchModel.TYPE_FRIENDLY:
        matchIcon = Icons.handshake;
        matchColor = Colors.blue;
        break;
      case MatchModel.TYPE_TRAINING:
        matchIcon = Icons.fitness_center;
        matchColor = Colors.green;
        break;
      default:
        matchIcon = Icons.sports_soccer;
        matchColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: matchColor.withOpacity(0.2),
          child: Icon(matchIcon, color: matchColor),
        ),
        title: Text(
          match.opponent ?? 'Sin rival',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${match.type == MatchModel.TYPE_TRAINING ? 'Entrenamiento' : 'Partido'} - $formattedDate',
        ),
        trailing: (match.isOfficial || match.isFriendly)
            ? Text(
                match.result,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: match.isWin
                      ? Colors.green
                      : match.isLoss
                          ? Colors.red
                          : Colors.grey,
                ),
              )
            : null,
        onTap: () {
          // Implementar navegación a detalle de partido
        },
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionInfo() {
    final isPremium = widget.user.subscription.isPremium;
    final expirationDate = widget.user.subscription.expirationDate;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: isPremium ? Colors.green.shade50 : Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isPremium ? Icons.verified : Icons.info_outline,
                  color: isPremium ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Estado de Suscripción',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isPremium
                        ? Colors.green.shade800
                        : Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isPremium
                  ? 'Premium${widget.user.subscription.plan != null ? " (${widget.user.subscription.plan})" : ""}'
                  : 'Versión Gratuita',
              style: TextStyle(
                fontSize: 14,
                color: isPremium ? Colors.green.shade800 : Colors.grey.shade800,
              ),
            ),
            if (isPremium && expirationDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Expira: ${DateFormat('dd/MM/yyyy').format(expirationDate)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.green.shade600,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            if (!isPremium)
              ElevatedButton(
                onPressed: widget.isConnected
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                SubscriptionPage(user: widget.user),
                          ),
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 36),
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: Text(widget.isConnected
                    ? 'Actualizar a Premium'
                    : 'Requiere conexión a internet'),
              ),
          ],
        ),
      ),
    );
  }
}
