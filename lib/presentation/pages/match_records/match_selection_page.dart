import 'package:flutter/material.dart';
import 'package:goalkeeper_stats/data/models/match_model.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/domain/repositories/matches_repository.dart';
import 'package:goalkeeper_stats/core/constants/app_constants.dart';
import 'package:goalkeeper_stats/services/firebase_crashlytics_service.dart';
import 'package:goalkeeper_stats/services/connectivity_service.dart';
import 'package:goalkeeper_stats/services/cache_manager.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // <-- Añadir esta línea

class MatchSelectionPage extends StatefulWidget {
  final UserModel user;
  final MatchesRepository matchesRepository;
  final Function()? onMatchCreated;

  const MatchSelectionPage({
    super.key,
    required this.user,
    required this.matchesRepository,
    this.onMatchCreated,
  });

  @override
  State<MatchSelectionPage> createState() => _MatchSelectionPageState();
}

class _MatchSelectionPageState extends State<MatchSelectionPage> {
  late Future<List<MatchModel>> _matchesFuture;
  bool _isLoading = false;
  String _searchQuery = '';
  String? _selectedType;
  
  // Servicios
  final _cacheManager = CacheManager();
  final _crashlytics = FirebaseCrashlyticsService();
  final _connectivityService = ConnectivityService();
  
  // Clave para caché
  late String _cacheKey;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _cacheKey = 'matches_${widget.user.id}';
    _checkConnectivity();
    _loadMatches();
  }
  
  @override
  void dispose() {
    super.dispose();
  }
  
  Future<void> _checkConnectivity() async {
    bool connected = await _connectivityService.checkConnectivity();
    setState(() {
      _isOffline = !connected;
    });
    
    // Suscribirse a cambios de conectividad
    _connectivityService.onConnectivityChanged.listen((result) {
      final wasOffline = _isOffline;
      setState(() {
        _isOffline = result != ConnectivityResult.wifi && 
                    result != ConnectivityResult.mobile &&
                    result != ConnectivityResult.ethernet;
      });
      
      // Si recuperamos conexión, recargar datos
      if (wasOffline && !_isOffline) {
        _loadMatches(forceRefresh: true);
        _connectivityService.showConnectivitySnackBar(context);
      } else if (!wasOffline && _isOffline) {
        _connectivityService.showConnectivitySnackBar(context);
      }
    });
  }

  Future<void> _loadMatches({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Cargar desde caché primero si no se fuerza actualización
      List<MatchModel>? cachedMatches;
      if (!forceRefresh) {
        cachedMatches = await _cacheManager.get<List<MatchModel>>(_cacheKey);
      }
      
      if (cachedMatches != null && !forceRefresh) {
        // Usar datos de caché
        _matchesFuture = Future.value(cachedMatches);
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Si estamos offline y no hay caché, mostrar error
      if (_isOffline && cachedMatches == null) {
        setState(() {
          _isLoading = false;
          _matchesFuture = Future.error('Sin conexión a internet');
        });
        return;
      }

      // Cargar partidos recientes y futuros
      final now = DateTime.now();
      final twoWeeksAgo = now.subtract(const Duration(days: 365));
      final twoWeeksLater = now.add(const Duration(days: 365));

      _matchesFuture = widget.matchesRepository
          .getMatchesByDateRange(
        widget.user.id,
        twoWeeksAgo,
        twoWeeksLater,
      ).then((matches) async {
        // Guardar en caché
        await _cacheManager.set<List<MatchModel>>(_cacheKey, matches, duration: 3600); // 1 hora
        return matches;
      }).catchError((error) {
        // Registrar error en Crashlytics
        _crashlytics.recordError(
          error, 
          StackTrace.current,
          reason: 'Error al cargar partidos',
          information: ['userId: ${widget.user.id}'],
        );
        
        // Si hay datos en caché, usarlos como fallback
        if (cachedMatches != null) {
          return cachedMatches;
        }
        throw error;
      });
    } catch (e) {
      _crashlytics.recordError(e, StackTrace.current, 
          reason: 'Error inesperado al cargar partidos');
      _matchesFuture = Future.error(e);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar Partido'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadMatches(forceRefresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // Indicador de modo sin conexión
          if (_isOffline)
            Container(
              width: double.infinity,
              color: Colors.amber.shade700,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: const Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sin conexión. Mostrando datos guardados.',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          
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
                fillColor: Colors.grey.shade100,
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
                  const Text(
                    'Filtro: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Chip(
                    label: Text(
                      AppConstants.matchTypes[_selectedType] ?? _selectedType!,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onDeleted: () {
                      setState(() {
                        _selectedType = null;
                      });
                    },
                    backgroundColor: Colors.blue.shade100,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

          // Lista de partidos
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildMatchesList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isOffline ? () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No es posible crear partidos sin conexión a internet'),
              backgroundColor: Colors.red,
            ),
          );
        } : () async {
          // Navegar para crear un nuevo partido
          if (widget.onMatchCreated != null) {
            widget.onMatchCreated!();
          }
          // Recargar la lista después de crear
          _loadMatches(forceRefresh: true);
        },
        child: const Icon(Icons.add),
        backgroundColor: _isOffline ? Colors.grey : null,
      ),
    );
  }

  Widget _buildMatchesList() {
    return FutureBuilder<List<MatchModel>>(
      future: _matchesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error al cargar partidos:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _loadMatches(forceRefresh: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sports_soccer, size: 60, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No hay partidos registrados',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Toca el botón + para agregar un partido',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        // Filtrar por tipo si hay filtro seleccionado
        var filteredMatches = snapshot.data!;
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
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No hay resultados para tu búsqueda',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: filteredMatches.length,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          itemBuilder: (context, index) {
            final match = filteredMatches[index];
            return _buildMatchCard(match);
          },
        );
      },
    );
  }

  Widget _buildMatchCard(MatchModel match) {
    // Formatear fecha
    final date = match.date;
    final formattedDate = '${date.day}/${date.month}/${date.year}';

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

    // Verificar si el partido es en el futuro
    final isUpcoming = match.date.isAfter(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isUpcoming ? Colors.blue.shade200 : Colors.transparent,
          width: isUpcoming ? 1 : 0,
        ),
      ),
      child: InkWell(
        onTap: () {
          // Devolver el partido seleccionado
          Navigator.pop(context, match);
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: matchColor.withOpacity(0.2),
                    child: Icon(matchIcon, color: matchColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          match.opponent ?? 'Sin rival',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${AppConstants.matchTypes[match.type] ?? match.type} - $formattedDate',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (match.isOfficial || match.isFriendly)
                    Chip(
                      label: Text(
                        match.result,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: match.isWin
                          ? Colors.green.shade100
                          : match.isLoss
                              ? Colors.red.shade100
                              : match.isDraw
                                  ? Colors.amber.shade100
                                  : Colors.grey.shade100,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              if (match.venue != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 8.0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        match.venue!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
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

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filtrar Partidos'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Todos'),
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
                title: const Text('Partidos Oficiales'),
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
                title: const Text('Partidos Amistosos'),
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
                title: const Text('Entrenamientos'),
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
        );
      },
    );
  }
}