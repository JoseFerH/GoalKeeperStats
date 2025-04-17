import 'package:flutter/material.dart';
import 'package:goalkeeper_stats/data/models/match_model.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/domain/repositories/matches_repository.dart';
import 'package:goalkeeper_stats/presentation/pages/match_records/match_detail_page.dart';
import 'package:goalkeeper_stats/presentation/pages/match_records/match_form_page.dart';
import 'package:goalkeeper_stats/presentation/pages/subscription/subscription_page.dart';
import 'package:goalkeeper_stats/core/constants/app_constants.dart';
import 'package:goalkeeper_stats/services/cache_manager.dart';
import 'package:goalkeeper_stats/services/firebase_crashlytics_service.dart';
import 'package:intl/intl.dart';

/// Pestaña que muestra los partidos y eventos del usuario
///
/// Permite visualizar, filtrar y gestionar los partidos registrados.
class MatchesTab extends StatefulWidget {
  final UserModel user;
  final MatchesRepository matchesRepository;
  final bool isConnected;

  const MatchesTab({
    super.key,
    required this.user,
    required this.matchesRepository,
    this.isConnected = true,
  });

  @override
  State<MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<MatchesTab> {
  Stream<List<MatchModel>>? _matchesStream;
  List<MatchModel>? _cachedMatches;
  String _searchQuery = '';
  String? _selectedType;
  bool _isLoading = true;
  final CacheManager _cacheManager = CacheManager();
  final FirebaseCrashlyticsService _crashlytics = FirebaseCrashlyticsService();

  // Clave para la caché de partidos
  static const String _matchesCacheKey = 'matches_list_';

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void didUpdateWidget(MatchesTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reiniciar datos si cambia la conectividad
    if (widget.isConnected != oldWidget.isConnected && widget.isConnected) {
      _initData();
    }
  }

  Future<void> _initData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final String cacheKey = _matchesCacheKey + widget.user.id;

      // Si hay conexión, inicializar el stream
      if (widget.isConnected) {
        _matchesStream =
            widget.matchesRepository.watchUserMatches(widget.user.id);

        // Cargar datos iniciales para evitar la carga infinita
        final matches =
            await widget.matchesRepository.getMatchesByUser(widget.user.id);

        // Guardar en caché
        await _cacheManager.set<List<MatchModel>>(cacheKey, matches,
            duration: 3600);

        if (mounted) {
          setState(() {
            _cachedMatches = matches;
            _isLoading = false;
          });
        }
      } else {
        // Sin conexión, intentar usar caché
        final cachedData = await _cacheManager.get<List<dynamic>>(cacheKey);
        if (cachedData != null) {
          // Convertir data de caché (esto es simplificado, necesitaría adaptar según la implementación real de caché)
          final List<MatchModel> matches = [];

          if (mounted) {
            setState(() {
              _cachedMatches = matches;
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _cachedMatches = [];
              _isLoading = false;
            });
          }
        }
      }
    } catch (e, stack) {
      _crashlytics.recordError(
        e,
        stack,
        reason: 'Error cargando datos de partidos',
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = widget.user.subscription.isPremium;
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Partidos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed:
                (isPremium && widget.isConnected) ? _showFilterDialog : null,
            tooltip: isPremium
                ? (widget.isConnected ? 'Filtrar partidos' : 'Sin conexión')
                : 'Función premium',
          ),
          if (widget.isConnected)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: isPremium ? _initData : null,
              tooltip: isPremium ? 'Actualizar' : 'Función premium',
            ),
        ],
      ),
      body: Column(
        children: [
          if (isPremium) ...[
            // Barra de búsqueda
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar partidos...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  filled: true,
                  fillColor: isDarkMode
                      ? Theme.of(context).colorScheme.surfaceVariant
                      : Colors.grey.shade100,
                  enabled: widget.isConnected,
                  // Mostrar mensaje cuando está deshabilitado
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),

            // Filtros activos
            if (_selectedType != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Text(
                      'Filtro: ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isDarkMode
                            ? Theme.of(context).colorScheme.onSurface
                            : Colors.black87,
                      ),
                    ),
                    Chip(
                      label: Text(
                        AppConstants.matchTypes[_selectedType] ??
                            _selectedType!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.black : null,
                        ),
                      ),
                      onDeleted: widget.isConnected
                          ? () {
                              setState(() {
                                _selectedType = null;
                              });
                            }
                          : null,
                      backgroundColor: isDarkMode
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.7)
                          : Colors.blue.shade100,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      deleteIconColor: isDarkMode ? Colors.black87 : null,
                    ),
                  ],
                ),
              ),

            // Indicador de modo sin conexión
            if (!widget.isConnected)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.orange.shade900
                      : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.offline_bolt,
                      size: 20,
                      color: isDarkMode
                          ? Colors.orange.shade300
                          : Colors.orange.shade900,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mostrando datos guardados. Algunas funciones no están disponibles sin conexión.',
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
          ],

          // Contenido principal - Lista o mensaje
          Expanded(
            child: isPremium ? _buildMatchesList() : _buildFreeUserMessage(),
          ),
        ],
      ),
      floatingActionButton: (isPremium && widget.isConnected)
          ? FloatingActionButton(
              onPressed: () async {
                final result = await _navigateToAddMatch();
                if (result == true) {
                  // Refrescar datos explícitamente después de agregar
                  _initData();
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildMatchesList() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Si estamos cargando y no hay datos en caché, mostrar indicador
    if (_isLoading && _cachedMatches == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // Si no hay conexión, usar datos en caché directamente
    if (!widget.isConnected) {
      return _buildMatchesListContent(_cachedMatches ?? []);
    }

    return StreamBuilder<List<MatchModel>>(
      stream: _matchesStream,
      initialData: _cachedMatches, // Datos iniciales para evitar carga infinita
      builder: (context, snapshot) {
        // Si tenemos error, mostrarlo
        if (snapshot.hasError) {
          _crashlytics.recordError(
            snapshot.error,
            StackTrace.current,
            reason: 'Error en stream de partidos',
          );

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: isDarkMode ? Colors.red.shade300 : Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error al cargar partidos',
                  style: TextStyle(
                    color: isDarkMode ? Colors.red.shade300 : Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Intenta recargar o comprueba tu conexión',
                  style: TextStyle(
                    color: isDarkMode
                        ? Colors.grey.shade300
                        : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _initData,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }

        // Usar datos del snapshot o caché
        final matches = snapshot.data ?? _cachedMatches ?? [];

        // Actualizar caché cuando llegan nuevos datos
        if (snapshot.hasData &&
            snapshot.connectionState != ConnectionState.waiting) {
          _cachedMatches = matches;
        }

        return _buildMatchesListContent(matches);
      },
    );
  }

  Widget _buildMatchesListContent(List<MatchModel> matches) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (matches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_soccer,
                size: 60,
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No hay partidos registrados',
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isConnected
                  ? 'Toca el botón + para agregar un partido'
                  : 'Conecta a internet para añadir partidos',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    // Filtrar por tipo si hay filtro seleccionado
    var filteredMatches = List<MatchModel>.from(matches);
    if (_selectedType != null) {
      filteredMatches = filteredMatches
          .where((match) => match.type == _selectedType)
          .toList();
    }

    // Filtrar por búsqueda
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredMatches = filteredMatches
          .where((match) =>
              (match.opponent?.toLowerCase().contains(query) ?? false) ||
              (match.venue?.toLowerCase().contains(query) ?? false) ||
              (match.notes?.toLowerCase().contains(query) ?? false))
          .toList();
    }

    // Ordenar por fecha, más reciente primero
    filteredMatches.sort((a, b) => b.date.compareTo(a.date));

    if (filteredMatches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 60,
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No hay resultados para tu búsqueda',
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
            if (_selectedType != null)
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedType = null;
                  });
                },
                child: const Text('Quitar filtro'),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredMatches.length,
      itemBuilder: (context, index) {
        final match = filteredMatches[index];
        return _buildMatchCard(match);
      },
    );
  }

  Widget _buildMatchCard(MatchModel match) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Formatear fecha
    final date = match.date;
    final formattedDate = DateFormat('dd/MM/yyyy').format(date);

    // Determinar icono según tipo de partido
    IconData matchIcon;
    Color matchColor;

    switch (match.type) {
      case MatchModel.TYPE_OFFICIAL:
        matchIcon = Icons.emoji_events;
        matchColor = isDarkMode ? Colors.amber.shade300 : Colors.amber;
        break;
      case MatchModel.TYPE_FRIENDLY:
        matchIcon = Icons.handshake;
        matchColor = isDarkMode ? Colors.blue.shade300 : Colors.blue;
        break;
      case MatchModel.TYPE_TRAINING:
        matchIcon = Icons.fitness_center;
        matchColor = isDarkMode ? Colors.green.shade300 : Colors.green;
        break;
      default:
        matchIcon = Icons.sports_soccer;
        matchColor = isDarkMode ? Colors.grey.shade300 : Colors.grey;
    }

    // Verificar si el partido es en el futuro
    final isUpcoming = match.date.isAfter(DateTime.now());

    // Colores para resultados
    final winColor = isDarkMode ? Colors.green.shade300 : Colors.green.shade100;
    final lossColor = isDarkMode ? Colors.red.shade300 : Colors.red.shade100;
    final drawColor =
        isDarkMode ? Colors.amber.shade300 : Colors.amber.shade100;
    final neutralColor = isDarkMode
        ? Theme.of(context).colorScheme.surfaceVariant
        : Colors.grey.shade100;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isUpcoming
              ? (isDarkMode ? Colors.blue.shade300 : Colors.blue.shade200)
              : Colors.transparent,
          width: isUpcoming ? 1 : 0,
        ),
      ),
      elevation: isDarkMode ? 1 : 2,
      child: InkWell(
        onTap: widget.isConnected ? () => _navigateToMatchDetail(match) : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        matchColor.withOpacity(isDarkMode ? 0.3 : 0.2),
                    child: Icon(matchIcon, color: matchColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          match.opponent ?? 'Sin rival',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDarkMode
                                ? Theme.of(context).colorScheme.onSurface
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${AppConstants.matchTypes[match.type]} - $formattedDate',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (match.isOfficial || match.isFriendly)
                    Chip(
                      label: Text(
                        match.result,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isDarkMode ? Colors.black87 : null,
                        ),
                      ),
                      backgroundColor: match.isWin
                          ? winColor
                          : match.isLoss
                              ? lossColor
                              : match.isDraw
                                  ? drawColor
                                  : neutralColor,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              if (match.venue != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 8.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: isDarkMode
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        match.venue!,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              if (match.notes != null && match.notes!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 8.0),
                  child: Text(
                    match.notes!,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // Mostrar indicador cuando no hay conexión
              if (!widget.isConnected)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: isDarkMode
                            ? Colors.orange.shade300
                            : Colors.orange.shade800,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Conecta a internet para ver detalles',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: isDarkMode
                              ? Colors.orange.shade300
                              : Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFreeUserMessage() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: isDarkMode
                  ? Color(0xFF423000) // Fondo premium oscuro
                  : Colors.amber.shade100,
              child: Icon(
                Icons.lock,
                size: 40,
                color: isDarkMode
                    ? Colors.amber.shade300 // Icono más brillante en oscuro
                    : Colors.amber.shade800,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Función Premium',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color:
                    isDarkMode ? Theme.of(context).colorScheme.onSurface : null,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'La gestión de partidos solo está disponible para usuarios premium. '
              'Actualiza tu suscripción para organizar tus tiros por partido y '
              'obtener estadísticas más detalladas.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Colors.black54,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
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
              icon: const Icon(Icons.star),
              label: Text(widget.isConnected
                  ? 'Actualizar a Premium'
                  : 'Requiere conexión a internet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDarkMode
                    ? Colors.amber.shade600
                    : Theme.of(context).colorScheme.primary,
                foregroundColor: isDarkMode ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                disabledBackgroundColor: Colors.grey.shade400,
                disabledForegroundColor: Colors.grey.shade700,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filtrar Partidos'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  'Todos',
                  style: TextStyle(
                    color: isDarkMode
                        ? Theme.of(context).colorScheme.onSurface
                        : null,
                  ),
                ),
                leading: Radio<String?>(
                  value: null,
                  groupValue: _selectedType,
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value;
                      Navigator.pop(context);
                    });
                  },
                ),
              ),
              ListTile(
                title: Text(
                  'Partidos Oficiales',
                  style: TextStyle(
                    color: isDarkMode
                        ? Theme.of(context).colorScheme.onSurface
                        : null,
                  ),
                ),
                leading: Radio<String?>(
                  value: MatchModel.TYPE_OFFICIAL,
                  groupValue: _selectedType,
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value;
                      Navigator.pop(context);
                    });
                  },
                ),
              ),
              ListTile(
                title: Text(
                  'Partidos Amistosos',
                  style: TextStyle(
                    color: isDarkMode
                        ? Theme.of(context).colorScheme.onSurface
                        : null,
                  ),
                ),
                leading: Radio<String?>(
                  value: MatchModel.TYPE_FRIENDLY,
                  groupValue: _selectedType,
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value;
                      Navigator.pop(context);
                    });
                  },
                ),
              ),
              ListTile(
                title: Text(
                  'Entrenamientos',
                  style: TextStyle(
                    color: isDarkMode
                        ? Theme.of(context).colorScheme.onSurface
                        : null,
                  ),
                ),
                leading: Radio<String?>(
                  value: MatchModel.TYPE_TRAINING,
                  groupValue: _selectedType,
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value;
                      Navigator.pop(context);
                    });
                  },
                ),
              ),
            ],
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
          ],
        );
      },
    );
  }

  Future<bool?> _navigateToAddMatch() async {
    if (!widget.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pueden añadir partidos sin conexión'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    return await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => MatchFormPage(
          userId: widget.user.id,
          matchesRepository: widget.matchesRepository,
        ),
      ),
    );
  }

  void _navigateToMatchDetail(MatchModel match) {
    if (!widget.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pueden ver detalles sin conexión'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MatchDetailPage(
          match: match,
          matchesRepository: widget.matchesRepository,
          isConnected: widget.isConnected,
        ),
      ),
    ).then((result) {
      // Refrescar datos si se actualiza o elimina el partido
      if (result == true) {
        _initData();
      }
    });
  }
}
