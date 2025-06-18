import 'package:flutter/material.dart';
import 'package:goalkeeper_stats/data/models/position.dart';
import 'package:goalkeeper_stats/data/models/shot_model.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/domain/repositories/goalkeeper_passes_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/shots_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/matches_repository.dart';
import 'package:goalkeeper_stats/core/theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:goalkeeper_stats/services/cache_manager.dart';
import 'package:goalkeeper_stats/services/connectivity_service.dart';

/// Pestaña de estadísticas rediseñada
///
/// Muestra gráficos y análisis de los datos de forma consistente
/// con la selección de zonas de GoalSelector
class StatsTab extends StatefulWidget {
  final UserModel user;
  final ShotsRepository shotsRepository;
  final GoalkeeperPassesRepository passesRepository;
  final MatchesRepository? matchesRepository;
  final bool forceRefresh;
  final bool isConnected; // <-- Añadir parámetro

  const StatsTab({
    super.key,
    required this.user,
    required this.shotsRepository,
    required this.passesRepository,
    required this.isConnected, // <-- Incluir en el constructor
    this.matchesRepository,
    this.forceRefresh = false,
  });

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<Map<String, dynamic>> _statsFuture;
  String _selectedPeriod = 'all'; // all, week, month, year
  String _selectedMatchType = 'all'; // Filtro por tipo de partido
  bool _isLoading = false;
  bool _showTutorialTip = true;
  final CacheManager _cacheManager = CacheManager();
  final ConnectivityService _connectivityService = ConnectivityService();
  bool _isOffline = false;

  // Constantes para zonas de portería - índices de 0 a 11
  // Corresponden exactamente con GoalSelector
  static const List<String> zoneNames = [
    'Alta Izquierda',
    'Alta Centro',
    'Alta Derecha',
    'Media-Alta Izquierda',
    'Media-Alta Centro',
    'Media-Alta Derecha',
    'Media-Baja Izquierda',
    'Media-Baja Centro',
    'Media-Baja Derecha',
    'Rasa Izquierda',
    'Rasa Centro',
    'Rasa Derecha'
  ];

  // Mapeador de claves antiguas a nuevos índices
  static const Map<String, int> legacyZoneMapping = {
    'top-left': 0,
    'top-center': 1,
    'top-right': 2,
    'middle-top-left': 3,
    'middle-left': 3,
    'middle-top-center': 4,
    'middle-center': 4,
    'middle-top-right': 5,
    'middle-right': 5,
    'middle-bottom-left': 6,
    'middle-bottom-center': 7,
    'middle-bottom-right': 8,
    'bottom-left': 9,
    'bottom-center': 10,
    'bottom-right': 11
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initConnectivity();
    _loadStats();

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  void _initConnectivity() {
    _connectivityService.onConnectivityChanged.listen((result) {
      final wasOffline = _isOffline;
      setState(() {
        _isOffline = !_connectivityService.isConnected;
      });

      // Si recuperamos conexión después de estar offline, actualizar datos
      if (wasOffline && !_isOffline) {
        _loadStats(forceRefresh: true);
        if (mounted) {
          _connectivityService.showConnectivitySnackBar(context);
        }
      }
    });
  }

  @override
  void didUpdateWidget(StatsTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.forceRefresh && !oldWidget.forceRefresh) {
      _loadStats(forceRefresh: true);
    }
  }

  void _loadStats({bool forceRefresh = false}) {
    setState(() {
      _isLoading = true;
      _statsFuture = _fetchCombinedStats(forceRefresh: forceRefresh);
    });
  }

  Future<Map<String, dynamic>> _fetchCombinedStats(
      {bool forceRefresh = false}) async {
    try {
      // Generar clave de caché basada en filtros seleccionados
      final cacheKey =
          'stats_${widget.user.id}_${_selectedPeriod}_${_selectedMatchType}';

      // Verificar caché primero si no es forzar actualización
      if (!forceRefresh && !widget.forceRefresh) {
        final cachedData =
            await _cacheManager.get<Map<String, dynamic>>(cacheKey);
        if (cachedData != null) {
          // Datos encontrados en caché
          return cachedData;
        }
      }

      // Si no hay conexión a internet y no hay caché, retornar error
      if (_isOffline && !await _cacheManager.exists(cacheKey)) {
        return {
          'error':
              'No hay conexión a internet y no se encontraron datos en caché'
        };
      }

      // Configurar rango de fechas según el período seleccionado
      DateTime? startDate;
      final now = DateTime.now();

      switch (_selectedPeriod) {
        case 'week':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case 'month':
          startDate = DateTime(now.year, now.month - 1, now.day);
          break;
        case 'year':
          startDate = DateTime(now.year - 1, now.month, now.day);
          break;
        case 'all':
        default:
          startDate = null;
          break;
      }

      // Obtener tiros filtrados por fecha con límite para optimizar rendimiento
      List<ShotModel> shots;
      if (startDate != null) {
        shots = await widget.shotsRepository.getShotsByDateRange(
          widget.user.id,
          startDate,
          now,
          //limit: 500, // Limitamos para mejorar rendimiento
        );
      } else {
        shots = await widget.shotsRepository.getShotsByUser(
          widget.user.id,
          //limit: 500, // Limitamos para mejorar rendimiento
        );
      }

      // Filtrar por tipo de partido si es necesario
      if (_selectedMatchType != 'all' && shots.isNotEmpty) {
        final matchesRepository = widget.matchesRepository;
        if (matchesRepository != null) {
          // Obtenemos IDs de partidos filtrados primero para eficiencia
          final typeMatches = await matchesRepository.getMatchesByType(
            widget.user.id,
            _selectedMatchType,
          );

          final matchIds = typeMatches.map((m) => m.id).toSet();
          shots = shots
              .where((shot) =>
                  shot.matchId != null && matchIds.contains(shot.matchId))
              .toList();
        }
      }

      // Obtener saques (con los mismos filtros)
      List<dynamic> passes;
      if (startDate != null) {
        passes = await widget.passesRepository.getPassesByDateRange(
          widget.user.id,
          startDate,
          now,
          //limit: 500, // Limitamos para mejorar rendimiento
        );
      } else {
        passes = await widget.passesRepository.getPassesByUser(
          widget.user.id,
          //limit: 500, // Limitamos para mejorar rendimiento
        );
      }

      // Estadísticas de tiros
      final shotsCount = shots.length;
      final savedShots = shots.where((shot) => shot.isSaved).length;
      final goalsAllowed = shots.where((shot) => shot.isGoal).length;

      // Estadísticas de saques
      final passesCount = passes.length;
      final successfulPasses = passes.where((pass) => pass.isSuccessful).length;
      final failedPasses = passes.where((pass) => pass.isFailed).length;

      // Porcentajes
      final savePercentage =
          shotsCount > 0 ? (savedShots / shotsCount * 100) : 0.0;
      final passAccuracy =
          passesCount > 0 ? (successfulPasses / passesCount * 100) : 0.0;

      // Nueva matriz de zonas usando índices
      List<Map<String, dynamic>> zoneStats = _generateZoneStatsFromShots(shots);

      // Analizar zonas para identificar fortalezas y debilidades
      final zoneAnalysis = _analyzeZonePerformance(zoneStats);

      // Datos para gráfico de tiros por día
      final shotsByDate = _groupShotsByDate(shots);

      // Datos para gráfico de progresión
      final progressData = _calculateProgressData(shots);

      // Análisis avanzado para consejos
      final advancedAnalysis = _performAdvancedAnalysis(shots, zoneStats);

      // Agrupar por resultado para visión general
      final aggregatedResults = {
        'total': shotsCount,
        'saved': savedShots,
        'goals': goalsAllowed,
        'save_percentage': savePercentage,
      };

      // Resultado final
      final result = {
        'shotsCount': shotsCount,
        'savedShots': savedShots,
        'goalsAllowed': goalsAllowed,
        'savePercentage': savePercentage,
        'passesCount': passesCount,
        'successfulPasses': successfulPasses,
        'failedPasses': failedPasses,
        'passAccuracy': passAccuracy,
        'zoneStats': zoneStats,
        'zoneAnalysis': zoneAnalysis,
        'shotsByDate': shotsByDate,
        'progressData': progressData,
        'advancedAnalysis': advancedAnalysis,
        'aggregatedResults': aggregatedResults,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isFromCache': false
      };

      // Guardar en caché para futuras consultas
      // Caché expire después de 30 minutos para datos que cambian frecuentemente
      await _cacheManager.set(cacheKey, result, duration: 1800);

      return result;
    } catch (e, stackTrace) {
      // Reportar error a Crashlytics
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Error cargando estadísticas',
        information: [
          'userId: ${widget.user.id}',
          'period: $_selectedPeriod',
          'matchType: $_selectedMatchType'
        ],
      );

      // Intentar recuperar caché expirada como plan B
      try {
        final cacheKey =
            'stats_${widget.user.id}_${_selectedPeriod}_${_selectedMatchType}';
        final cachedData =
            await _cacheManager.getExpired<Map<String, dynamic>>(cacheKey);

        if (cachedData != null) {
          // Marcar como datos de caché expirada
          cachedData['isFromCache'] = true;
          return cachedData;
        }
      } catch (_) {
        // Ignorar errores al intentar recuperar caché expirada
      }

      print('Error al cargar estadísticas: $e');

      if (e is FirebaseException) {
        // Manejar errores específicos de Firebase
        if (e.code == 'permission-denied') {
          return {'error': 'No tienes permiso para acceder a estos datos'};
        } else if (e.code == 'unavailable' ||
            e.code == 'network-request-failed') {
          return {
            'error':
                'Error de conexión con el servidor. Verifica tu conexión a internet'
          };
        }
        return {'error': 'Error de Firebase: ${e.message}'};
      }

      return {'error': e.toString()};
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Genera estadísticas por zona usando índices numéricos 0-11
  List<Map<String, dynamic>> _generateZoneStatsFromShots(
      List<ShotModel> shots) {
    List<Map<String, dynamic>> zoneStats = List.generate(
        12,
        (index) => {
              'zoneIndex': index,
              'zoneName': zoneNames[index],
              'total': 0,
              'saved': 0,
              'goal': 0,
              'saveRate': 0.0,
            });

    // Procesar cada tiro
    for (final shot in shots) {
      // Obtener posición de gol normalizada
      final x = shot.goalPosition.x;
      final y = shot.goalPosition.y;

      // Convertir a índice de zona (0-11)
      int zoneIndex = _getZoneIndexFromPosition(x, y);

      // Si usamos goalZone heredado, lo convertimos
      if (zoneIndex == -1 && shot.goalZone != null) {
        zoneIndex = legacyZoneMapping[shot.goalZone] ?? 0;
      }

      // Asegurar índice válido
      if (zoneIndex >= 0 && zoneIndex < 12) {
        // Incrementar contadores
        zoneStats[zoneIndex]['total'] =
            (zoneStats[zoneIndex]['total'] as int) + 1;

        if (shot.isGoal) {
          zoneStats[zoneIndex]['goal'] =
              (zoneStats[zoneIndex]['goal'] as int) + 1;
        } else {
          zoneStats[zoneIndex]['saved'] =
              (zoneStats[zoneIndex]['saved'] as int) + 1;
        }

        // Recalcular tasa de atajadas
        int total = zoneStats[zoneIndex]['total'] as int;
        int saved = zoneStats[zoneIndex]['saved'] as int;
        if (total > 0) {
          zoneStats[zoneIndex]['saveRate'] = saved / total;
        }
      }
    }

    return zoneStats;
  }

  // Convertir posiciones (x,y) a índice de zona (0-11)
  int _getZoneIndexFromPosition(double x, double y) {
    // Constante para la altura proporcional de zona de tiros rasos
    const bottomZoneHeightRatio = 0.125;

    // Determinar columna (0-2)
    int column;
    if (x < 1 / 3) {
      column = 0; // Izquierda
    } else if (x < 2 / 3) {
      column = 1; // Centro
    } else {
      column = 2; // Derecha
    }

    // Determinar fila (0-3)
    int row;
    if (y < (1 - bottomZoneHeightRatio) / 3) {
      row = 0; // Superior
    } else if (y < 2 * (1 - bottomZoneHeightRatio) / 3) {
      row = 1; // Media-alta
    } else if (y < (1 - bottomZoneHeightRatio)) {
      row = 2; // Media-baja
    } else {
      row = 3; // Rasa
    }

    // Calcular índice de zona: fila * 3 + columna
    return row * 3 + column;
  }

  Map<String, dynamic> _analyzeZonePerformance(
      List<Map<String, dynamic>> zoneStats) {
    // Filtrar zonas con datos suficientes
    final relevantZones = zoneStats
        .where((zone) =>
                (zone['total'] as int) >= 3 // Mínimo 3 tiros para análisis
            )
        .toList();

    // Ordenar por tasa de atajadas (mayor a menor)
    relevantZones.sort(
        (a, b) => (b['saveRate'] as double).compareTo(a['saveRate'] as double));

    // Inicializar resultados
    Map<String, dynamic> result = {
      'strongZones': <Map<String, dynamic>>[],
      'weakZones': <Map<String, dynamic>>[],
      'zoneRatings': <int, double>{},
    };

    // Si no hay suficientes datos, retornar resultado vacío
    if (relevantZones.isEmpty) {
      return result;
    }

    // Extraer zonas fuertes (hasta 2)
    for (int i = 0; i < relevantZones.length && i < 2; i++) {
      result['strongZones'].add({
        'zoneIndex': relevantZones[i]['zoneIndex'],
        'zoneName': relevantZones[i]['zoneName'],
        'saveRate': relevantZones[i]['saveRate'],
      });
    }

    // Extraer zonas débiles (hasta 2, desde el final)
    for (int i = relevantZones.length - 1;
        i >= 0 && i >= relevantZones.length - 2;
        i--) {
      result['weakZones'].add({
        'zoneIndex': relevantZones[i]['zoneIndex'],
        'zoneName': relevantZones[i]['zoneName'],
        'saveRate': relevantZones[i]['saveRate'],
      });
    }

    // Guardar todas las valoraciones
    for (final zone in relevantZones) {
      (result['zoneRatings'] as Map<int, double>)[zone['zoneIndex'] as int] =
          zone['saveRate'] as double;
    }

    return result;
  }

  Map<String, int> _groupShotsByDate(List<ShotModel> shots) {
    final map = <String, int>{};

    // Agrupar tiros por fecha
    for (final shot in shots) {
      final date = shot.timestamp;
      final dateStr = DateFormat('dd/MM/yyyy').format(date);

      if (map.containsKey(dateStr)) {
        map[dateStr] = map[dateStr]! + 1;
      } else {
        map[dateStr] = 1;
      }
    }

    return map;
  }

  List<Map<String, dynamic>> _calculateProgressData(List<ShotModel> shots) {
    if (shots.isEmpty) return [];

    // Ordenar por fecha
    shots.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Inicializar contadores
    int totalShots = 0;
    int savedShots = 0;
    double cumulativeSavePercentage = 0;

    // Datos para gráfico de progresión
    List<Map<String, dynamic>> progressData = [];

    // Procesar cada tiro para calcular porcentaje acumulativo
    for (final shot in shots) {
      totalShots++;
      if (shot.isSaved) savedShots++;

      cumulativeSavePercentage = savedShots / totalShots * 100;

      progressData.add({
        'date': shot.timestamp,
        'totalShots': totalShots,
        'savePercentage': cumulativeSavePercentage,
      });
    }

    return progressData;
  }

  Map<String, dynamic> _performAdvancedAnalysis(
      List<ShotModel> shots, List<Map<String, dynamic>> zoneStats) {
    // Encontrar zona más débil (con mínimo 3 tiros)
    int? weakestZoneIndex;
    double lowestSaveRate = 1.0;

    for (final zone in zoneStats) {
      final total = zone['total'] as int;
      final saveRate = zone['saveRate'] as double;

      if (total >= 3 && saveRate < lowestSaveRate) {
        lowestSaveRate = saveRate;
        weakestZoneIndex = zone['zoneIndex'] as int;
      }
    }

    // Consejos personalizados basados en zonas débiles
    final Map<int, String> tipsByZoneIndex = {
      0: 'Mejora tu alcance y salto hacia tu lado izquierdo en la zona alta. Practica estiramientos laterales con extensión completa.',
      1: 'Trabaja en tus saltos verticales con ejercicios pliométricos para mejorar tu alcance en la zona alta central.',
      2: 'Mejora tu alcance hacia tu lado derecho en la zona alta. Aumenta la fuerza en tu pierna izquierda para impulsos más efectivos.',
      3: 'Practica reacciones rápidas hacia tu lado izquierdo en zonas medias-altas. Mejora tu posición inicial del cuerpo.',
      4: 'Trabaja en tus reflejos para tiros centrales a media altura. Fortalece tus abdominales para reacciones más rápidas.',
      5: 'Practica reacciones rápidas hacia tu lado derecho en zonas medias-altas. Mejora tu equilibrio y distribución de peso.',
      6: 'Mejora tu velocidad de reacción para zonas medias-bajas izquierdas. Practica caídas laterales con menor tiempo de reacción.',
      7: 'Trabaja en tus movimientos para tiros a media-baja altura central. Practica la técnica de achique correcta.',
      8: 'Mejora tu velocidad de reacción en la zona media-baja derecha. Practica extensiones laterales rápidas.',
      9: 'Mejora tu velocidad para tiros rasos a tu izquierda. Practica el desplazamiento lateral a ras de suelo.',
      10: 'Trabaja en tus movimientos bajos para tiros rasos centrales. Mejora la técnica de extensión de piernas.',
      11: 'Mejora tu velocidad para tiros rasos a tu derecha. Practica la técnica de extensión lateral baja.',
    };

    // Consejo general siempre presente
    const String generalTip =
        'Mantén siempre una buena posición base con las rodillas flexionadas y el peso adelantado para reaccionar más rápido en cualquier dirección.';

    return {
      'weakestZoneIndex': weakestZoneIndex,
      'weakestZoneName':
          weakestZoneIndex != null ? zoneNames[weakestZoneIndex] : null,
      'zoneTip':
          weakestZoneIndex != null ? tipsByZoneIndex[weakestZoneIndex] : null,
      'generalTip': generalTip,
      'hasEnoughData': shots.length >= 10,
    };
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        //title: const Text('Estadísticas'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Resumen'),
            Tab(text: 'Análisis'),
          ],
        ),
        actions: [
          // Indicador de estado offline
          if (_isOffline)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Tooltip(
                message:
                    "Modo sin conexión. Datos podrían no estar actualizados",
                child: Icon(
                  Icons.cloud_off,
                  color: Colors.grey,
                ),
              ),
            ),
          // Filtro de período
          PopupMenuButton<String>(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Seleccionar período',
            onSelected: (value) {
              setState(() {
                _selectedPeriod = value;
                _loadStats();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text('Todo el tiempo'),
              ),
              const PopupMenuItem(
                value: 'week',
                child: Text('Última semana'),
              ),
              const PopupMenuItem(
                value: 'month',
                child: Text('Último mes'),
              ),
              const PopupMenuItem(
                value: 'year',
                child: Text('Último año'),
              ),
            ],
          ),
          // Filtro de tipo de partido
          if (widget.matchesRepository != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.filter_list),
              tooltip: 'Filtrar por tipo',
              onSelected: (value) {
                setState(() {
                  _selectedMatchType = value;
                  _loadStats();
                });
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'all',
                  child: Text('Todos los partidos'),
                ),
                const PopupMenuItem(
                  value: 'official',
                  child: Text('Partidos Oficiales'),
                ),
                const PopupMenuItem(
                  value: 'friendly',
                  child: Text('Partidos Amistosos'),
                ),
                const PopupMenuItem(
                  value: 'training',
                  child: Text('Entrenamientos'),
                ),
              ],
            ),
        ],
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildSummaryTab(isDarkMode),
              _buildAnalysisTab(isDarkMode),
            ],
          ),
          // Indicador de carga superpuesto
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.2),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryTab(bool isDarkMode) {
    // Mensaje de ayuda para interactividad
    if (_showTutorialTip) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Solo mostrar si hay datos y es la primera vez
        if (!_isLoading && mounted) {
          _showInteractivityTip(context);
        }
      });
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError ||
            (snapshot.hasData && snapshot.data!.containsKey('error'))) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline,
                    size: 48,
                    color: isDarkMode
                        ? AppTheme.errorColor.withOpacity(0.8)
                        : AppTheme.errorColor),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    'Error al cargar estadísticas: ${snapshot.error ?? snapshot.data!['error']}',
                    style: TextStyle(
                        color: isDarkMode
                            ? AppTheme.errorColor.withOpacity(0.8)
                            : AppTheme.errorColor),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _loadStats(forceRefresh: true),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }

        final stats = snapshot.data!;

        // Mostrar indicador de datos de caché
        final isFromCache = stats['isFromCache'] == true;

        final shotsCount = stats['shotsCount'] as int;

        if (shotsCount == 0) {
          return _buildNoDataView();
        }

        final savedShots = stats['savedShots'] as int;
        final goalsAllowed = stats['goalsAllowed'] as int;
        final savePercentage = stats['savePercentage'] as double;
        final passesCount = stats['passesCount'] as int;
        final successfulPasses = stats['successfulPasses'] as int;
        final passAccuracy = stats['passAccuracy'] as double;
        final shotsByDate = stats['shotsByDate'] as Map<String, int>;

        return RefreshIndicator(
          onRefresh: () async {
            _loadStats(forceRefresh: true);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Período seleccionado e indicador de caché
                Row(
                  children: [
                    Expanded(child: _buildPeriodIndicator(isDarkMode)),
                    if (isFromCache)
                      Tooltip(
                        message:
                            "Mostrando datos en caché. Actualiza para ver información más reciente.",
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.history,
                                size: 14,
                                color: Colors.amber.shade800,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Caché',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),

                // Tarjetas con estadísticas principales
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: _buildMainStatsCards(
                      savePercentage, shotsCount, isDarkMode),
                ),

                // Gráfico circular de atajadas/goles
                _buildSavesDonutChart(savedShots, goalsAllowed, isDarkMode),
                const SizedBox(height: 24),

                // Estadísticas de saques
                _buildPassingStats(
                    passesCount, successfulPasses, passAccuracy, isDarkMode),
                const SizedBox(height: 24),

                // Actividad reciente
                Text(
                  'Actividad Reciente',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? AppTheme.lightTextColor
                        : AppTheme.darkTextColor,
                  ),
                ),
                const SizedBox(height: 16),

                // Gráfico de actividad
                _buildActivityChart(shotsByDate, isDarkMode),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnalysisTab(bool isDarkMode) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError ||
            (snapshot.hasData && snapshot.data!.containsKey('error'))) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                'Error al cargar estadísticas: ${snapshot.error ?? snapshot.data!['error']}',
                style: TextStyle(
                    color: isDarkMode
                        ? AppTheme.errorColor.withOpacity(0.8)
                        : AppTheme.errorColor),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        }

        final stats = snapshot.data!;
        final shotsCount = stats['shotsCount'] as int;

        if (shotsCount == 0) {
          return _buildNoDataView();
        }

        final zoneStats = stats['zoneStats'] as List<Map<String, dynamic>>;
        final zoneAnalysis = stats['zoneAnalysis'] as Map<String, dynamic>;
        final advancedAnalysis =
            stats['advancedAnalysis'] as Map<String, dynamic>;
        final progressData =
            stats['progressData'] as List<Map<String, dynamic>>;

        // Mostrar indicador de datos de caché
        final isFromCache = stats['isFromCache'] == true;

        return RefreshIndicator(
          onRefresh: () async {
            _loadStats(forceRefresh: true);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Período seleccionado e indicador de caché
                Row(
                  children: [
                    Expanded(child: _buildPeriodIndicator(isDarkMode)),
                    if (isFromCache)
                      Tooltip(
                        message:
                            "Mostrando datos en caché. Actualiza para ver información más reciente.",
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.history,
                                size: 14,
                                color: Colors.amber.shade800,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Caché',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),

                // Mapa de calor de la portería
                Text(
                  'Mapa de Atajadas y Goles',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? AppTheme.lightTextColor
                        : AppTheme.darkTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Distribución de tiros por zona de la portería',
                  style: TextStyle(
                    color: isDarkMode
                        ? AppTheme.mediumTextDark
                        : AppTheme.mediumTextLight,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),

                _buildGoalHeatMap(zoneStats, isDarkMode),

                const SizedBox(height: 32),

                // Análisis de fortalezas y debilidades
                _buildStrengthsWeaknesses(zoneAnalysis, isDarkMode),

                const SizedBox(height: 32),

                // Gráfico de progresión temporal
                Text(
                  'Progresión de Efectividad',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? AppTheme.lightTextColor
                        : AppTheme.darkTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Evolución de tu porcentaje de atajadas con el tiempo',
                  style: TextStyle(
                    color: isDarkMode
                        ? AppTheme.mediumTextDark
                        : AppTheme.mediumTextLight,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),

                _buildProgressionChart(progressData, isDarkMode),

                const SizedBox(height: 32),

                // Consejos de mejora
                _buildImprovementTips(advancedAnalysis, isDarkMode),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoDataView() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sports_soccer,
            size: 64,
            color:
                isDarkMode ? AppTheme.mediumTextDark : AppTheme.mediumTextLight,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay datos para mostrar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color:
                  isDarkMode ? AppTheme.lightTextColor : AppTheme.darkTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Registra algunos tiros para ver estadísticas',
            style: TextStyle(
                color: isDarkMode
                    ? AppTheme.mediumTextDark
                    : AppTheme.mediumTextLight),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Navegar a la pestaña de registro de tiros
              final bottomNavBar = (context
                  .findAncestorWidgetOfExactType<Scaffold>()
                  ?.bottomNavigationBar as BottomNavigationBar?);
              if (bottomNavBar != null) {
                bottomNavBar.onTap!(2); // Índice de la pestaña de registro
              }
            },
            icon: const Icon(Icons.add_circle),
            label: const Text('Registrar Tiro'),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodIndicator(bool isDarkMode) {
    String periodText;
    String filterText = '';

    switch (_selectedPeriod) {
      case 'week':
        periodText = 'Última semana';
        break;
      case 'month':
        periodText = 'Último mes';
        break;
      case 'year':
        periodText = 'Último año';
        break;
      case 'all':
      default:
        periodText = 'Todo el tiempo';
        break;
    }

    if (_selectedMatchType != 'all') {
      switch (_selectedMatchType) {
        case 'official':
          filterText = ' • Oficiales';
          break;
        case 'friendly':
          filterText = ' • Amistosos';
          break;
        case 'training':
          filterText = ' • Entrenamientos';
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDarkMode
            ? AppTheme.darkCardColor
            : Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today, size: 16),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '$periodText$filterText',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDarkMode
                    ? AppTheme.lightTextColor
                    : AppTheme.darkTextColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainStatsCards(
      double savePercentage, int totalShots, bool isDarkMode) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Efectividad',
            value: '${savePercentage.toStringAsFixed(1)}%',
            icon: Icons.shield,
            valueColor: AppTheme.secondaryColor,
            iconBackground: isDarkMode
                ? AppTheme.primaryColor.withOpacity(0.2)
                : AppTheme.secondaryColor.withOpacity(0.1),
            isDarkMode: isDarkMode,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            title: 'Tiros Enfrentados',
            value: totalShots.toString(),
            icon: Icons.sports_soccer,
            valueColor: AppTheme.primaryColor,
            iconBackground: isDarkMode
                ? AppTheme.primaryColor.withOpacity(0.2)
                : AppTheme.primaryColor.withOpacity(0.1),
            isDarkMode: isDarkMode,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color valueColor,
    required Color iconBackground,
    required bool isDarkMode,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: valueColor),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? AppTheme.lightTextColor
                          : AppTheme.darkTextColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? valueColor.withOpacity(0.9) : valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavesDonutChart(int saved, int conceded, bool isDarkMode) {
    // Cálculo para evitar errores si no hay datos
    final totalTiros = saved + conceded;
    final savedRatio = totalTiros > 0 ? saved / totalTiros : 0;
    final concededRatio = totalTiros > 0 ? conceded / totalTiros : 0;

    // Colores para el gráfico
    final savedColor =
        isDarkMode ? AppTheme.secondaryColor : AppTheme.primaryColor;
    final concededColor =
        isDarkMode ? AppTheme.errorColor.withOpacity(0.8) : AppTheme.errorColor;

    return SizedBox(
      height: 250,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 70,
              sections: [
                PieChartSectionData(
                  color: savedColor,
                  value: saved.toDouble(),
                  title: '', // Eliminamos el título interno
                  radius: 60,
                  badgeWidget: _buildDonutLabel(
                    text: 'Atajadas',
                    value: saved,
                    color: AppTheme.lightTextColor,
                    bgColor: savedColor.withOpacity(0.8),
                  ),
                  // Ajuste crítico: mejorar posicionamiento
                  badgePositionPercentageOffset: savedRatio < 0.15 ? 1.4 : 0.8,
                ),
                PieChartSectionData(
                  color: concededColor,
                  value: conceded.toDouble(),
                  title: '', // Eliminamos el título interno
                  radius: 60,
                  badgeWidget: _buildDonutLabel(
                    text: 'Goles',
                    value: conceded,
                    color: AppTheme.lightTextColor,
                    bgColor: concededColor,
                  ),
                  // Ajuste crítico: mejorar posicionamiento
                  badgePositionPercentageOffset:
                      concededRatio < 0.15 ? 1.4 : 0.8,
                ),
              ],
            ),
            swapAnimationDuration: const Duration(milliseconds: 500),
            swapAnimationCurve: Curves.easeInOutQuint,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${saved + conceded}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode
                      ? AppTheme.lightTextColor
                      : AppTheme.darkTextColor,
                ),
              ),
              Text(
                'Total',
                style: TextStyle(
                  color: isDarkMode
                      ? AppTheme.mediumTextDark
                      : AppTheme.mediumTextLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDonutLabel({
    required String text,
    required int value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        // Añadir borde para mejorar visibilidad
        border: Border.all(color: Colors.white, width: 1),
        // Añadir sombra para mejor separación visual
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14, // Reducido
              color: color,
            ),
          ),
          Text(
            text,
            style: TextStyle(
              fontSize: 11, // Reducido
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassingStats(int totalPasses, int successfulPasses,
      double passAccuracy, bool isDarkMode) {
    if (totalPasses == 0) {
      return const SizedBox.shrink(); // No mostrar nada si no hay saques
    }

    // Colores adaptados al tema
    final accentColorPrimary =
        isDarkMode ? AppTheme.accentColor : AppTheme.secondaryColor;
    final accentColorSecondary = isDarkMode
        ? AppTheme.premiumColor.withOpacity(0.8)
        : AppTheme.premiumColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Estadísticas de Saques',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color:
                isDarkMode ? AppTheme.lightTextColor : AppTheme.darkTextColor,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Precisión',
                value: '${passAccuracy.toStringAsFixed(1)}%',
                icon: Icons.sports_handball,
                valueColor: accentColorPrimary,
                iconBackground: isDarkMode
                    ? accentColorPrimary.withOpacity(0.2)
                    : accentColorPrimary.withOpacity(0.1),
                isDarkMode: isDarkMode,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                title: 'Total Saques',
                value: totalPasses.toString(),
                icon: Icons.flight_takeoff,
                valueColor: accentColorSecondary,
                iconBackground: isDarkMode
                    ? accentColorSecondary.withOpacity(0.2)
                    : accentColorSecondary.withOpacity(0.1),
                isDarkMode: isDarkMode,
              ),
            ),
          ],
        ),
        if (totalPasses > 0) ...[
          const SizedBox(height: 16),
          // Minigráfico de saques correctos/fallidos
          SizedBox(
            height: 100,
            child: Row(
              children: [
                Expanded(
                  flex: successfulPasses,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? accentColorPrimary.withOpacity(0.3)
                          : accentColorPrimary.withOpacity(0.2),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          successfulPasses.toString(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? accentColorPrimary.withOpacity(0.9)
                                : accentColorPrimary,
                          ),
                        ),
                        Text(
                          'Correctos',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode
                                ? accentColorPrimary.withOpacity(0.9)
                                : accentColorPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: totalPasses - successfulPasses,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? accentColorSecondary.withOpacity(0.3)
                          : accentColorSecondary.withOpacity(0.2),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          (totalPasses - successfulPasses).toString(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? accentColorSecondary
                                : accentColorSecondary.withOpacity(0.8),
                          ),
                        ),
                        Text(
                          'Fallidos',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode
                                ? accentColorSecondary
                                : accentColorSecondary.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActivityChart(Map<String, int> shotsByDate, bool isDarkMode) {
    if (shotsByDate.isEmpty) {
      return Card(
        color: isDarkMode ? AppTheme.darkCardColor : null,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'No hay datos de actividad para mostrar en este período',
              style: TextStyle(
                color: isDarkMode
                    ? AppTheme.mediumTextDark
                    : AppTheme.mediumTextLight,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // Ordenar fechas
    final sortedDates = shotsByDate.keys.toList()
      ..sort((a, b) {
        final dateA = DateFormat('dd/MM/yyyy').parse(a);
        final dateB = DateFormat('dd/MM/yyyy').parse(b);
        return dateA.compareTo(dateB);
      });

    // Limitar a máximo 7 días para no saturar el gráfico
    List<String> displayDates;
    if (sortedDates.length > 7) {
      displayDates = sortedDates.sublist(sortedDates.length - 7);
    } else {
      displayDates = sortedDates;
    }

    // Crear puntos para el gráfico
    final spots = <FlSpot>[];
    for (int i = 0; i < displayDates.length; i++) {
      final date = displayDates[i];
      spots.add(FlSpot(i.toDouble(), shotsByDate[date]!.toDouble()));
    }

    // Formatear etiquetas de fecha para que sean más cortas
    final xLabels = displayDates.map((date) {
      final parts = date.split('/');
      return '${parts[0]}/${parts[1]}'; // Formato "día/mes"
    }).toList();

    // Color del gráfico adaptado al tema
    final lineColor =
        isDarkMode ? AppTheme.primaryColor : AppTheme.secondaryColor;

    // Color de texto
    final textColor =
        isDarkMode ? AppTheme.mediumTextDark : AppTheme.mediumTextLight;

    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            horizontalInterval: 2,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: isDarkMode
                    ? AppTheme.mediumTextDark.withOpacity(0.15)
                    : AppTheme.mediumTextLight.withOpacity(0.2),
                strokeWidth: 1,
              );
            },
            drawVerticalLine: false,
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value < 0 || value >= xLabels.length) {
                    return const SizedBox.shrink();
                  }
                  // Rotar ligeramente las etiquetas para mejor legibilidad
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Transform.rotate(
                      angle: 0.3, // ~17 grados
                      child: Text(
                        xLabels[value.toInt()],
                        style: TextStyle(
                          fontSize: 10,
                          color: textColor,
                        ),
                      ),
                    ),
                  );
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value % 1 != 0) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      fontSize: 10,
                      color: textColor,
                    ),
                  );
                },
                reservedSize: 30,
              ),
            ),
          ),
          borderData: FlBorderData(
            show: false,
          ),
          minX: 0,
          maxX: displayDates.length - 1.0,
          minY: 0,
          // Añadir un poco de espacio arriba para que el gráfico no quede pegado al borde
          maxY: spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b) + 2,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: lineColor.withOpacity(0.8),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((touchedSpot) {
                  final date = displayDates[touchedSpot.x.toInt()];
                  return LineTooltipItem(
                    '${date}: ${touchedSpot.y.toInt()} tiros',
                    const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  );
                }).toList();
              },
            ),
            handleBuiltInTouches: true,
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: lineColor,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: lineColor,
                    strokeWidth: 1,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: lineColor.withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalHeatMap(
      List<Map<String, dynamic>> zoneStats, bool isDarkMode) {
    // Encontrar el valor máximo para normalizar la intensidad del color
    int maxGoals = 0;
    for (final zone in zoneStats) {
      final goals = zone['goal'] as int;
      if (goals > maxGoals) maxGoals = goals;
    }

    // Relación de aspecto consistente con GoalSelector
    const aspectRatio = 7.32 / 3.5;
    const bottomZoneHeightRatio = 0.125;

    // Colores adaptados al tema
    final skyGradientStart = isDarkMode
        ? AppTheme.primaryColor.withOpacity(0.3)
        : AppTheme.secondaryColor.withOpacity(0.3);
    final skyGradientEnd = isDarkMode
        ? AppTheme.primaryColor.withOpacity(0.5)
        : AppTheme.secondaryColor.withOpacity(0.6);
    final groundColor = isDarkMode
        ? AppTheme.primaryColor.withOpacity(0.7)
        : AppTheme.primaryColor;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        decoration: BoxDecoration(
          // Gradiente del cielo
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              skyGradientStart,
              skyGradientEnd,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 5,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        foregroundDecoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.transparent,
              groundColor,
            ],
            stops: const [0.0, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Portería
            Center(
              child: Container(
                width: aspectRatio * 100, // Dimensión arbitraria
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 2),
                  color: Colors.white.withOpacity(0.9),
                ),
                child: Stack(
                  children: [
                    // Red
                    Positioned.fill(
                      child: CustomPaint(
                        painter: GoalNetPainter(isDarkMode: isDarkMode),
                      ),
                    ),

                    // Estructura 3x4 del mapa de calor
                    Column(
                      children: [
                        // Fila superior (índices 0, 1, 2)
                        Expanded(
                          flex: (100 * (1 - bottomZoneHeightRatio) / 3).round(),
                          child: Row(
                            children: [
                              _buildHeatMapCell(
                                  zoneStats, 0, maxGoals, isDarkMode),
                              _buildHeatMapCell(
                                  zoneStats, 1, maxGoals, isDarkMode),
                              _buildHeatMapCell(
                                  zoneStats, 2, maxGoals, isDarkMode),
                            ],
                          ),
                        ),
                        // Fila media-alta (índices 3, 4, 5)
                        Expanded(
                          flex: (100 * (1 - bottomZoneHeightRatio) / 3).round(),
                          child: Row(
                            children: [
                              _buildHeatMapCell(
                                  zoneStats, 3, maxGoals, isDarkMode),
                              _buildHeatMapCell(
                                  zoneStats, 4, maxGoals, isDarkMode),
                              _buildHeatMapCell(
                                  zoneStats, 5, maxGoals, isDarkMode),
                            ],
                          ),
                        ),
                        // Fila media-baja (índices 6, 7, 8)
                        Expanded(
                          flex: (100 * (1 - bottomZoneHeightRatio) / 3).round(),
                          child: Row(
                            children: [
                              _buildHeatMapCell(
                                  zoneStats, 6, maxGoals, isDarkMode),
                              _buildHeatMapCell(
                                  zoneStats, 7, maxGoals, isDarkMode),
                              _buildHeatMapCell(
                                  zoneStats, 8, maxGoals, isDarkMode),
                            ],
                          ),
                        ),
                        // Fila inferior - rasos (índices 9, 10, 11)
                        Expanded(
                          flex: (100 * bottomZoneHeightRatio).round(),
                          child: Row(
                            children: [
                              _buildHeatMapCell(
                                  zoneStats, 9, maxGoals, isDarkMode),
                              _buildHeatMapCell(
                                  zoneStats, 10, maxGoals, isDarkMode),
                              _buildHeatMapCell(
                                  zoneStats, 11, maxGoals, isDarkMode),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Marco de la portería (postes y travesaño)
                    // Post izquierdo
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 6,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.white,
                              Colors.grey.shade400,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Post derecho
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: 6,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                            colors: [
                              Colors.white,
                              Colors.grey.shade400,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Travesaño
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 6,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white,
                              Colors.grey.shade400,
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildHeatMapCell(List<Map<String, dynamic>> zoneStats, int zoneIndex,
      int maxGoals, bool isDarkMode) {
    // Encontrar estadísticas para esta zona
    final zone = zoneStats.firstWhere(
      (z) => z['zoneIndex'] == zoneIndex,
      orElse: () => {
        'zoneIndex': zoneIndex,
        'zoneName': zoneNames[zoneIndex],
        'total': 0,
        'saved': 0,
        'goal': 0,
        'saveRate': 0.0,
      },
    );

    final total = zone['total'] as int;
    final goals = zone['goal'] as int;
    final saved = zone['saved'] as int;

    // Calcular intensidad del color para el mapa de calor
    double intensity = maxGoals > 0 ? goals / maxGoals : 0;

    // Crear un color adaptado al tema
    final Color cellColor;
    if (intensity > 0) {
      if (isDarkMode) {
        // Modo oscuro: de amarillo verdoso a rojo oscuro
        cellColor = HSLColor.fromAHSL(
          1.0,
          intensity < 0.3 ? 70 - (intensity * 70) : 0,
          0.8,
          0.5 - (intensity * 0.3),
        ).toColor();
      } else {
        // Modo claro: de amarillo a rojo
        cellColor = HSLColor.fromAHSL(
          1.0,
          intensity < 0.3 ? 60 - (intensity * 60) : 0,
          0.7 + (intensity * 0.3),
          0.9 - (intensity * 0.3),
        ).toColor();
      }
    } else {
      cellColor = Colors.white;
    }

    // Color adaptativo para texto según fondo
    final textColor = _getContrastTextColor(cellColor);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (total > 0) {
            _showZoneDetails(zone);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: cellColor,
            border: Border.all(
                color: isDarkMode
                    ? AppTheme.mediumTextDark.withOpacity(0.2)
                    : AppTheme.mediumTextLight.withOpacity(0.4),
                width: 0.5),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Contenido principal: SOLO NÚMERO DE GOLES
              total > 0
                  ? Text(
                      goals.toString(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        shadows: intensity > 0.3
                            ? [
                                Shadow(
                                  offset: const Offset(1, 1),
                                  blurRadius: 2,
                                  color: Colors.black.withOpacity(0.5),
                                ),
                              ]
                            : [],
                      ),
                    )
                  : Icon(Icons.add,
                      color: isDarkMode
                          ? AppTheme.mediumTextDark.withOpacity(0.5)
                          : AppTheme.mediumTextLight.withOpacity(0.5),
                      size: 14),

              // Indicador de interactividad
              if (total > 0)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Icon(
                    Icons.info_outline,
                    size: 10,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Función auxiliar para determinar el color de texto con mejor contraste
  Color _getContrastTextColor(Color backgroundColor) {
    // Fórmula YIQ para calcular brillo percibido
    final brightness = (backgroundColor.red * 299 +
            backgroundColor.green * 587 +
            backgroundColor.blue * 114) /
        1000;
    return brightness > 125 ? Colors.black : Colors.white;
  }

  // Función para mostrar detalles al tocar una zona
  void _showZoneDetails(Map<String, dynamic> zone) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final int zoneIndex = zone['zoneIndex'] as int;
    final String zoneName = zone['zoneName'] as String;
    final int total = zone['total'] as int;
    final int goals = zone['goal'] as int;
    final int saved = zone['saved'] as int;

    final goalPercentage =
        total > 0 ? (goals / total * 100).toStringAsFixed(1) : '0.0';
    final savePercentage =
        total > 0 ? (saved / total * 100).toStringAsFixed(1) : '0.0';

    // Mostrar diálogo con detalles
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? AppTheme.darkCardColor : Colors.white,
        title: Text(
          'Zona $zoneName',
          style: TextStyle(
            color:
                isDarkMode ? AppTheme.lightTextColor : AppTheme.darkTextColor,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.sports_soccer,
                  color: isDarkMode
                      ? AppTheme.primaryColor
                      : AppTheme.secondaryColor),
              title: Text(
                'Tiros totales',
                style: TextStyle(
                  color: isDarkMode
                      ? AppTheme.lightTextColor
                      : AppTheme.darkTextColor,
                ),
              ),
              trailing: Text(
                total.toString(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode
                      ? AppTheme.lightTextColor
                      : AppTheme.darkTextColor,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.check_circle,
                  color: isDarkMode
                      ? AppTheme.secondaryColor
                      : AppTheme.secondaryColor),
              title: Text(
                'Atajadas',
                style: TextStyle(
                  color: isDarkMode
                      ? AppTheme.lightTextColor
                      : AppTheme.darkTextColor,
                ),
              ),
              trailing: Text(
                '$saved ($savePercentage%)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode
                      ? AppTheme.lightTextColor
                      : AppTheme.darkTextColor,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.dangerous,
                  color: isDarkMode
                      ? AppTheme.errorColor.withOpacity(0.8)
                      : AppTheme.errorColor),
              title: Text(
                'Goles',
                style: TextStyle(
                  color: isDarkMode
                      ? AppTheme.lightTextColor
                      : AppTheme.darkTextColor,
                ),
              ),
              trailing: Text(
                '$goals ($goalPercentage%)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode
                      ? AppTheme.lightTextColor
                      : AppTheme.darkTextColor,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cerrar',
              style: TextStyle(
                color:
                    isDarkMode ? AppTheme.accentColor : AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthsWeaknesses(
      Map<String, dynamic> zoneAnalysis, bool isDarkMode) {
    final strongZones = zoneAnalysis['strongZones'] as List<dynamic>;
    final weakZones = zoneAnalysis['weakZones'] as List<dynamic>;

    // Colores adaptados al tema
    final strengthColor =
        isDarkMode ? AppTheme.secondaryColor : AppTheme.primaryColor;
    final weaknessColor =
        isDarkMode ? AppTheme.errorColor.withOpacity(0.8) : AppTheme.errorColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fortalezas y Debilidades',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color:
                isDarkMode ? AppTheme.lightTextColor : AppTheme.darkTextColor,
          ),
        ),
        const SizedBox(height: 16),
        if (strongZones.isEmpty && weakZones.isEmpty)
          Text(
            'Necesitas más datos para un análisis detallado (mínimo 3 tiros por zona)',
            style: TextStyle(
              color: isDarkMode
                  ? AppTheme.mediumTextDark
                  : AppTheme.mediumTextLight,
            ),
          )
        else ...[
          // Fortalezas
          if (strongZones.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.thumb_up, color: strengthColor),
                const SizedBox(width: 8),
                Text(
                  'Puntos fuertes:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? AppTheme.lightTextColor
                        : AppTheme.darkTextColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final zone in strongZones)
              Padding(
                padding: const EdgeInsets.only(left: 32.0, bottom: 4.0),
                child: Text(
                  '${zone['zoneName']}: ${(zone['saveRate'] * 100).toStringAsFixed(0)}% de atajadas',
                  style: TextStyle(color: strengthColor),
                ),
              ),
          ],

          if (strongZones.isNotEmpty && weakZones.isNotEmpty)
            const SizedBox(height: 16),

          // Debilidades
          if (weakZones.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.thumb_down, color: weaknessColor),
                const SizedBox(width: 8),
                Text(
                  'Puntos débiles:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? AppTheme.lightTextColor
                        : AppTheme.darkTextColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final zone in weakZones)
              Padding(
                padding: const EdgeInsets.only(left: 32.0, bottom: 4.0),
                child: Text(
                  '${zone['zoneName']}: ${(zone['saveRate'] * 100).toStringAsFixed(0)}% de atajadas',
                  style: TextStyle(color: weaknessColor),
                ),
              ),
          ],
        ],
      ],
    );
  }

  Widget _buildProgressionChart(
      List<Map<String, dynamic>> progressData, bool isDarkMode) {
    if (progressData.isEmpty) {
      return Card(
        color: isDarkMode ? AppTheme.darkCardColor : null,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'No hay suficientes datos para mostrar la progresión',
              style: TextStyle(
                color: isDarkMode
                    ? AppTheme.mediumTextDark
                    : AppTheme.mediumTextLight,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // Crear puntos para el gráfico (cada 5 tiros o menos para no saturar)
    final spots = <FlSpot>[];
    final interval = progressData.length > 30 ? progressData.length ~/ 30 : 1;

    for (int i = 0; i < progressData.length; i += interval) {
      final data = progressData[i];
      spots.add(FlSpot(
        i.toDouble(),
        (data['savePercentage'] as double),
      ));
    }

    // Asegurar que el último punto siempre esté incluido
    if (progressData.isNotEmpty && (progressData.length - 1) % interval != 0) {
      final lastData = progressData.last;
      spots.add(FlSpot(
        (progressData.length - 1).toDouble(),
        (lastData['savePercentage'] as double),
      ));
    }

    // Colores adaptados al tema
    final lineColor =
        isDarkMode ? AppTheme.secondaryColor : AppTheme.primaryColor;
    final textColor =
        isDarkMode ? AppTheme.mediumTextDark : AppTheme.mediumTextLight;
    final gridLineColor = isDarkMode
        ? AppTheme.mediumTextDark.withOpacity(0.15)
        : AppTheme.mediumTextLight.withOpacity(0.2);

    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            horizontalInterval: 10, // Intervalos de 10%
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: gridLineColor,
                strokeWidth: 1,
              );
            },
            drawVerticalLine: false,
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value % (spots.length ~/ 5 + 1) != 0 &&
                      value != spots.length - 1) {
                    return const SizedBox.shrink();
                  }

                  if (value >= progressData.length) {
                    return const SizedBox.shrink();
                  }

                  // Reducir tamaño de texto para mejorar legibilidad
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '#${value.toInt() + 1}', // Simplificado a "#N" en lugar de "Tiro N"
                      style: TextStyle(
                        fontSize: 9,
                        color: textColor,
                      ),
                    ),
                  );
                },
                reservedSize: 25,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value % 10 != 0 && value != 100) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    '${value.toInt()}%',
                    style: TextStyle(
                      fontSize: 10,
                      color: textColor,
                    ),
                  );
                },
                reservedSize: 40,
              ),
            ),
          ),
          borderData: FlBorderData(
            show: false,
          ),
          minX: 0,
          maxX: spots.isEmpty ? 0 : spots.last.x,
          minY: 0,
          maxY: 100, // Porcentaje de 0 a 100
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: lineColor.withOpacity(0.8),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((touchedSpot) {
                  final idx = touchedSpot.x.toInt();
                  if (idx >= progressData.length) return null;

                  final data = progressData[idx];
                  final totalShots = data['totalShots'] as int;
                  final percentage = data['savePercentage'] as double;

                  return LineTooltipItem(
                    'Tiro #$totalShots: ${percentage.toStringAsFixed(1)}%',
                    const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  );
                }).toList();
              },
            ),
            handleBuiltInTouches: true,
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: lineColor,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show:
                    false, // Ocultar puntos por defecto para gráficos con muchos datos
                checkToShowDot: (spot, barData) {
                  // Mostrar solo algunos puntos para no saturar
                  return spot.x == 0 ||
                      spot.x == spots.last.x ||
                      spot.x % (spots.length ~/ 5 + 1) == 0;
                },
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: lineColor,
                    strokeWidth: 1,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: lineColor.withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImprovementTips(
      Map<String, dynamic> advancedAnalysis, bool isDarkMode) {
    final hasEnoughData = advancedAnalysis['hasEnoughData'] as bool;
    final weakestZoneIndex = advancedAnalysis['weakestZoneIndex'] as int?;
    final weakestZoneName = advancedAnalysis['weakestZoneName'] as String?;
    final zoneTip = advancedAnalysis['zoneTip'] as String?;
    final generalTip = advancedAnalysis['generalTip'] as String;

    // Colores adaptados al tema
    final cardBgColor = isDarkMode
        ? AppTheme.primaryColor.withOpacity(0.15)
        : AppTheme.secondaryColor.withOpacity(0.05);
    final titleColor = isDarkMode
        ? AppTheme.primaryColor.withOpacity(0.9)
        : AppTheme.primaryColor;
    final tipColor = isDarkMode
        ? AppTheme.lightTextColor.withOpacity(0.9)
        : AppTheme.darkTextColor;
    final highlightColor = isDarkMode
        ? AppTheme.premiumColor
        : AppTheme.premiumColor.withOpacity(0.8);

    return Card(
      color: cardBgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDarkMode
              ? AppTheme.primaryColor.withOpacity(0.2)
              : AppTheme.secondaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tips_and_updates, color: titleColor),
                const SizedBox(width: 8),
                Text(
                  'Consejos de Mejora',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!hasEnoughData)
              Text(
                'Registra más tiros para recibir consejos personalizados basados en tu rendimiento.',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: tipColor),
              )
            else if (weakestZoneIndex != null && zoneTip != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Zona a mejorar: $weakestZoneName',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: tipColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    zoneTip,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: tipColor),
                  ),
                ],
              )
            else
              Text(
                'Continúa registrando tiros para obtener consejos más específicos.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: tipColor),
              ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: highlightColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    generalTip,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: isDarkMode
                          ? AppTheme.lightTextColor
                          : AppTheme.primaryColor,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showInteractivityTip(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Solo mostrar una vez por sesión
    setState(() {
      _showTutorialTip = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.touch_app, color: AppTheme.lightTextColor),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                  'Toca o desliza sobre los gráficos para ver más detalles'),
            ),
          ],
        ),
        duration: const Duration(seconds: 5),
        backgroundColor:
            isDarkMode ? AppTheme.primaryColor : AppTheme.secondaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        action: SnackBarAction(
          label: 'Entendido',
          textColor: AppTheme.lightTextColor,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}

/// Pintor personalizado para dibujar la red de la portería
class GoalNetPainter extends CustomPainter {
  final bool isDarkMode;

  GoalNetPainter({this.isDarkMode = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDarkMode
          ? AppTheme.mediumTextDark.withOpacity(0.3)
          : Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    final verticalLines = 16; // Número de líneas verticales
    final horizontalLines = 8; // Número de líneas horizontales

    // Dibujar líneas verticales
    final verticalSpacing = size.width / verticalLines;
    for (int i = 1; i < verticalLines; i++) {
      canvas.drawLine(
        Offset(i * verticalSpacing, 0),
        Offset(i * verticalSpacing, size.height),
        paint,
      );
    }

    // Dibujar líneas horizontales
    final horizontalSpacing = size.height / horizontalLines;
    for (int i = 1; i < horizontalLines; i++) {
      canvas.drawLine(
        Offset(0, i * horizontalSpacing),
        Offset(size.width, i * horizontalSpacing),
        paint,
      );
    }

    // Dibujar líneas diagonales para dar efecto de perspectiva a la red
    paint.strokeWidth = 0.4;
    for (int i = 1; i < verticalLines; i += 2) {
      for (int j = 1; j < horizontalLines; j += 2) {
        canvas.drawLine(
          Offset(i * verticalSpacing, j * horizontalSpacing),
          Offset((i - 0.5) * verticalSpacing, (j - 0.5) * horizontalSpacing),
          paint,
        );
        canvas.drawLine(
          Offset(i * verticalSpacing, j * horizontalSpacing),
          Offset((i + 0.5) * verticalSpacing, (j - 0.5) * horizontalSpacing),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
