import 'dart:async';

import 'package:goalkeeper_stats/data/local/data_store.dart';
import 'package:goalkeeper_stats/data/models/goalkeeper_pass_model.dart';
import 'package:goalkeeper_stats/domain/repositories/goalkeeper_passes_repository.dart';

/// Implementación local del repositorio de saques del portero
class LocalGoalkeeperPassesRepository implements GoalkeeperPassesRepository {
  final LocalDataStore _dataStore = LocalDataStore();
  final StreamController<List<GoalkeeperPassModel>> _passesController =
      StreamController<List<GoalkeeperPassModel>>.broadcast();

  @override
  Future<List<GoalkeeperPassModel>> getPassesByUser(String userId) async {
    return _dataStore.passes.where((pass) => pass.userId == userId).toList();
  }

  @override
  Future<List<GoalkeeperPassModel>> getPassesByMatch(String matchId) async {
    return _dataStore.passes.where((pass) => pass.matchId == matchId).toList();
  }

  @override
  Future<GoalkeeperPassModel?> getPassById(String id) async {
    try {
      return _dataStore.passes.firstWhere((pass) => pass.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<GoalkeeperPassModel> createPass(GoalkeeperPassModel pass) async {
    // Generar ID si no existe
    final newPass = pass.id.isEmpty ? pass.copyWith(userId: pass.userId) : pass;

    _dataStore.passes.add(newPass);

    // Notificar cambios
    _notifyChange(newPass.userId);
    if (newPass.matchId != null) {
      _notifyMatchChange(newPass.matchId!);
    }

    return newPass;
  }

  @override
  Future<GoalkeeperPassModel> updatePass(GoalkeeperPassModel pass) async {
    final index = _dataStore.passes.indexWhere((p) => p.id == pass.id);

    if (index < 0) {
      throw Exception('Saque no encontrado');
    }

    _dataStore.passes[index] = pass;

    // Notificar cambios
    _notifyChange(pass.userId);
    if (pass.matchId != null) {
      _notifyMatchChange(pass.matchId!);
    }

    return pass;
  }

  @override
  Future<void> deletePass(String id) async {
    final pass = await getPassById(id);
    if (pass == null) return;

    final userId = pass.userId;
    final matchId = pass.matchId;

    _dataStore.passes.removeWhere((p) => p.id == id);

    // Notificar cambios
    _notifyChange(userId);
    if (matchId != null) {
      _notifyMatchChange(matchId);
    }
  }

  @override
  Future<List<GoalkeeperPassModel>> getPassesByType(
    String userId,
    String type,
  ) async {
    return _dataStore.passes
        .where((pass) => pass.userId == userId && pass.type == type)
        .toList();
  }

  @override
  Future<List<GoalkeeperPassModel>> getPassesByResult(
    String userId,
    String result,
  ) async {
    return _dataStore.passes
        .where((pass) => pass.userId == userId && pass.result == result)
        .toList();
  }

  @override
  Future<List<GoalkeeperPassModel>> getPassesByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    return _dataStore.passes
        .where(
          (pass) =>
              pass.userId == userId &&
              pass.timestamp.isAfter(startDate) &&
              pass.timestamp.isBefore(endDate),
        )
        .toList();
  }

  @override
  Stream<List<GoalkeeperPassModel>> watchUserPasses(String userId) {
    // Emitir el estado inicial
    _notifyChange(userId);

    // Filtrar el stream para obtener solo los saques del usuario
    return _passesController.stream.map(
      (passes) => passes.where((pass) => pass.userId == userId).toList(),
    );
  }

  @override
  Stream<List<GoalkeeperPassModel>> watchMatchPasses(String matchId) {
    // Emitir el estado inicial
    _notifyMatchChange(matchId);

    // Filtrar el stream para obtener solo los saques del partido
    return _passesController.stream.map(
      (passes) => passes.where((pass) => pass.matchId == matchId).toList(),
    );
  }

  @override
  Future<Map<String, Map<String, int>>> getPassTypeStatistics(
    String userId,
  ) async {
    final passes = await getPassesByUser(userId);

    // Inicializar el mapa de resultados con los tipos de saque
    final Map<String, Map<String, int>> typeStats = {
      GoalkeeperPassModel.TYPE_HAND: {'total': 0, 'successful': 0, 'failed': 0},
      GoalkeeperPassModel.TYPE_GROUND: {
        'total': 0,
        'successful': 0,
        'failed': 0,
      },
      GoalkeeperPassModel.TYPE_VOLLEY: {
        'total': 0,
        'successful': 0,
        'failed': 0,
      },
      GoalkeeperPassModel.TYPE_GOAL_KICK: {
        'total': 0,
        'successful': 0,
        'failed': 0,
      },
    };

    // Analizar cada saque
    for (final pass in passes) {
      final type = pass.type;

      // Incrementar contador total
      typeStats[type]!['total'] = (typeStats[type]!['total'] ?? 0) + 1;

      // Incrementar contador específico (exitoso o fallido)
      if (pass.isSuccessful) {
        typeStats[type]!['successful'] =
            (typeStats[type]!['successful'] ?? 0) + 1;
      } else {
        typeStats[type]!['failed'] = (typeStats[type]!['failed'] ?? 0) + 1;
      }
    }

    return typeStats;
  }

  @override
  Future<Map<String, int>> countPassesByResult(String userId) async {
    final passes = await getPassesByUser(userId);

    return {
      'total': passes.length,
      GoalkeeperPassModel.RESULT_SUCCESSFUL:
          passes.where((pass) => pass.isSuccessful).length,
      GoalkeeperPassModel.RESULT_FAILED:
          passes.where((pass) => pass.isFailed).length,
    };
  }

  // Métodos auxiliares para notificar cambios
  void _notifyChange(String userId) {
    _passesController.add(
      _dataStore.passes.where((pass) => pass.userId == userId).toList(),
    );
  }

  void _notifyMatchChange(String matchId) {
    _passesController.add(
      _dataStore.passes.where((pass) => pass.matchId == matchId).toList(),
    );
  }
}
