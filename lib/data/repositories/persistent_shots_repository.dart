import 'dart:convert';
import 'package:goalkeeper_stats/data/models/shot_model.dart';
import 'package:goalkeeper_stats/domain/repositories/shots_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

/// Implementación de ShotsRepository con persistencia local
///
/// Utiliza SharedPreferences para almacenar los tiros entre sesiones
/// de la aplicación para pruebas y desarrollo.
class PersistentShotsRepository implements ShotsRepository {
  final String _shotsKey = 'shots_data';
  List<ShotModel> _shots = [];
  final _shotsStreamController = StreamController<List<ShotModel>>.broadcast();

  // Singleton para evitar múltiples instancias
  static PersistentShotsRepository? _instance;

  static Future<PersistentShotsRepository> getInstance() async {
    if (_instance == null) {
      _instance = PersistentShotsRepository._();
      await _instance!._loadData();
    }
    return _instance!;
  }

  PersistentShotsRepository._();

  // Cargar datos almacenados en SharedPreferences
  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? shotsJson = prefs.getString(_shotsKey);

      if (shotsJson != null) {
        final List<dynamic> decoded = jsonDecode(shotsJson);
        _shots = decoded.map((item) {
          // Convertir las posiciones correctamente
          final Map<String, dynamic> shotData = Map<String, dynamic>.from(item);

          // Asegurar que tenemos un ID válido
          final String id = shotData['id'] ?? '';

          return ShotModel.fromMap(shotData, id);
        }).toList();

        // Actualizar el stream con los datos cargados
        _shotsStreamController.add(_shots);

        print('Datos cargados: ${_shots.length} tiros');
      }
    } catch (e) {
      print('Error al cargar datos de tiros: $e');
    }
  }

  // Guardar datos en SharedPreferences
  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> shotsMaps = _shots.map((shot) {
        final map = shot.toMap();
        map['id'] = shot.id; // Añadir ID al mapa
        return map;
      }).toList();

      await prefs.setString(_shotsKey, jsonEncode(shotsMaps));
      print('Datos guardados: ${_shots.length} tiros');
    } catch (e) {
      print('Error al guardar datos de tiros: $e');
    }
  }

  @override
  Future<List<ShotModel>> getShotsByUser(String userId) async {
    // Simular retraso para mostrar carga (opcional)
    await Future.delayed(const Duration(milliseconds: 300));
    return _shots.where((shot) => shot.userId == userId).toList();
  }

  @override
  Future<List<ShotModel>> getShotsByMatch(String matchId) async {
    return _shots.where((shot) => shot.matchId == matchId).toList();
  }

  @override
  Future<ShotModel?> getShotById(String id) async {
    try {
      return _shots.firstWhere((shot) => shot.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<ShotModel> createShot(ShotModel shot) async {
    // Crear un ID único si no tiene uno
    final newShot = ShotModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: shot.userId,
      matchId: shot.matchId,
      minute: shot.minute,
      goalPosition: shot.goalPosition,
      shooterPosition: shot.shooterPosition,
      goalkeeperPosition: shot.goalkeeperPosition,
      result: shot.result,
      goalType: shot.goalType,
      timestamp: shot.timestamp,
      notes: shot.notes,
    );

    _shots.add(newShot);

    // Guardar y notificar
    await _saveData();
    _shotsStreamController.add(_shots);

    return newShot;
  }

  @override
  Future<ShotModel> updateShot(ShotModel shot) async {
    final index = _shots.indexWhere((s) => s.id == shot.id);

    if (index >= 0) {
      _shots[index] = shot;
      await _saveData();
      _shotsStreamController.add(_shots);
      return shot;
    } else {
      throw Exception('Tiro no encontrado para actualizar');
    }
  }

  @override
  Future<void> deleteShot(String id) async {
    _shots.removeWhere((shot) => shot.id == id);
    await _saveData();
    _shotsStreamController.add(_shots);
  }

  @override
  Future<List<ShotModel>> getShotsByResult(String userId, String result) async {
    return _shots
        .where((shot) => shot.userId == userId && shot.result == result)
        .toList();
  }

  @override
  Future<List<ShotModel>> getShotsByDateRange(
      String userId, DateTime startDate, DateTime endDate) async {
    return _shots
        .where((shot) =>
            shot.userId == userId &&
            shot.timestamp.isAfter(startDate) &&
            shot.timestamp.isBefore(endDate))
        .toList();
  }

  @override
  Stream<List<ShotModel>> watchUserShots(String userId) {
    // Filtrar por usuario cuando emite valores
    return _shotsStreamController.stream
        .map((shots) => shots.where((shot) => shot.userId == userId).toList());
  }

  @override
  Stream<List<ShotModel>> watchMatchShots(String matchId) {
    // Filtrar por partido cuando emite valores
    return _shotsStreamController.stream.map(
        (shots) => shots.where((shot) => shot.matchId == matchId).toList());
  }

  @override
  Future<Map<String, Map<String, int>>> getGoalZoneStatistics(
      String userId) async {
    final shots = await getShotsByUser(userId);

    // Inicializar el mapa de resultados con las 9 zonas
    final Map<String, Map<String, int>> zoneStats = {
      'top-left': {'total': 0, 'saved': 0, 'goal': 0},
      'top-center': {'total': 0, 'saved': 0, 'goal': 0},
      'top-right': {'total': 0, 'saved': 0, 'goal': 0},
      'middle-left': {'total': 0, 'saved': 0, 'goal': 0},
      'middle-center': {'total': 0, 'saved': 0, 'goal': 0},
      'middle-right': {'total': 0, 'saved': 0, 'goal': 0},
      'bottom-left': {'total': 0, 'saved': 0, 'goal': 0},
      'bottom-center': {'total': 0, 'saved': 0, 'goal': 0},
      'bottom-right': {'total': 0, 'saved': 0, 'goal': 0},
    };

    // Analizar cada tiro
    for (final shot in shots) {
      final zone = shot.goalZone;

      // Incrementar contador total
      zoneStats[zone]!['total'] = (zoneStats[zone]!['total'] ?? 0) + 1;

      // Incrementar contador específico (gol o atajada)
      if (shot.isGoal) {
        zoneStats[zone]!['goal'] = (zoneStats[zone]!['goal'] ?? 0) + 1;
      } else {
        zoneStats[zone]!['saved'] = (zoneStats[zone]!['saved'] ?? 0) + 1;
      }
    }

    return zoneStats;
  }

  @override
  Future<Map<String, int>> countShotsByResult(String userId) async {
    final shots = await getShotsByUser(userId);

    // Inicializar contadores
    final Map<String, int> counts = {
      'total': 0,
      ShotModel.RESULT_GOAL: 0,
      ShotModel.RESULT_SAVED: 0,
    };

    // Contar resultados
    counts['total'] = shots.length;
    counts[ShotModel.RESULT_GOAL] = shots.where((shot) => shot.isGoal).length;
    counts[ShotModel.RESULT_SAVED] = shots.where((shot) => shot.isSaved).length;

    return counts;
  }

  // Limpiar recursos
  void dispose() {
    _shotsStreamController.close();
  }
}
