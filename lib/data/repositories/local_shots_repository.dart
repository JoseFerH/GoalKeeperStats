import 'dart:async';

import 'package:goalkeeper_stats/data/local/data_store.dart';
import 'package:goalkeeper_stats/data/models/shot_model.dart';
import 'package:goalkeeper_stats/domain/repositories/shots_repository.dart';

/// Implementación local del repositorio de tiros
class LocalShotsRepository implements ShotsRepository {
  final LocalDataStore _dataStore = LocalDataStore();
  final StreamController<List<ShotModel>> _shotsController =
      StreamController<List<ShotModel>>.broadcast();

  @override
  Future<List<ShotModel>> getShotsByUser(String userId) async {
    return _dataStore.shots.where((shot) => shot.userId == userId).toList();
  }

  @override
  Future<List<ShotModel>> getShotsByMatch(String matchId) async {
    return _dataStore.shots.where((shot) => shot.matchId == matchId).toList();
  }

  @override
  Future<ShotModel?> getShotById(String id) async {
    try {
      return _dataStore.shots.firstWhere((shot) => shot.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<ShotModel> createShot(ShotModel shot) async {
    // Generar ID si no existe
    final newShot = shot.id.isEmpty ? shot.copyWith(userId: shot.userId) : shot;

    _dataStore.shots.add(newShot);

    // Notificar cambios
    _notifyChange(newShot.userId);
    if (newShot.matchId != null) {
      _notifyMatchChange(newShot.matchId!);
    }

    return newShot;
  }

  @override
  Future<ShotModel> updateShot(ShotModel shot) async {
    final index = _dataStore.shots.indexWhere((s) => s.id == shot.id);

    if (index < 0) {
      throw Exception('Tiro no encontrado');
    }

    _dataStore.shots[index] = shot;

    // Notificar cambios
    _notifyChange(shot.userId);
    if (shot.matchId != null) {
      _notifyMatchChange(shot.matchId!);
    }

    return shot;
  }

  @override
  Future<void> deleteShot(String id) async {
    final shot = await getShotById(id);
    if (shot == null) return;

    final userId = shot.userId;
    final matchId = shot.matchId;

    _dataStore.shots.removeWhere((s) => s.id == id);

    // Notificar cambios
    _notifyChange(userId);
    if (matchId != null) {
      _notifyMatchChange(matchId);
    }
  }

  @override
  Future<List<ShotModel>> getShotsByResult(String userId, String result) async {
    return _dataStore.shots
        .where((shot) => shot.userId == userId && shot.result == result)
        .toList();
  }

  @override
  Future<List<ShotModel>> getShotsByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    return _dataStore.shots
        .where(
          (shot) =>
              shot.userId == userId &&
              shot.timestamp.isAfter(startDate) &&
              shot.timestamp.isBefore(endDate),
        )
        .toList();
  }

  @override
  Stream<List<ShotModel>> watchUserShots(String userId) {
    // Emitir el estado inicial
    _notifyChange(userId);

    // Filtrar el stream para obtener solo los tiros del usuario
    return _shotsController.stream.map(
      (shots) => shots.where((shot) => shot.userId == userId).toList(),
    );
  }

  @override
  Stream<List<ShotModel>> watchMatchShots(String matchId) {
    // Emitir el estado inicial
    _notifyMatchChange(matchId);

    // Filtrar el stream para obtener solo los tiros del partido
    return _shotsController.stream.map(
      (shots) => shots.where((shot) => shot.matchId == matchId).toList(),
    );
  }

  @override
  Future<Map<String, Map<String, int>>> getGoalZoneStatistics(
    String userId,
  ) async {
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

    return {
      'total': shots.length,
      ShotModel.RESULT_GOAL: shots.where((shot) => shot.isGoal).length,
      ShotModel.RESULT_SAVED: shots.where((shot) => shot.isSaved).length,
    };
  }

  // Métodos auxiliares para notificar cambios
  void _notifyChange(String userId) {
    _shotsController.add(
      _dataStore.shots.where((shot) => shot.userId == userId).toList(),
    );
  }

  void _notifyMatchChange(String matchId) {
    _shotsController.add(
      _dataStore.shots.where((shot) => shot.matchId == matchId).toList(),
    );
  }
}
