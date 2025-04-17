import 'package:goalkeeper_stats/data/models/goalkeeper_pass_model.dart';

/// Interfaz que define las operaciones para gestionar saques del portero
abstract class GoalkeeperPassesRepository {
  /// Obtiene todos los saques de un usuario
  Future<List<GoalkeeperPassModel>> getPassesByUser(String userId);

  /// Obtiene los saques asociados a un partido específico
  Future<List<GoalkeeperPassModel>> getPassesByMatch(String matchId);

  /// Obtiene un saque específico por su ID
  Future<GoalkeeperPassModel?> getPassById(String id);

  /// Crea un nuevo registro de saque
  Future<GoalkeeperPassModel> createPass(GoalkeeperPassModel pass);

  /// Actualiza un registro de saque existente
  Future<GoalkeeperPassModel> updatePass(GoalkeeperPassModel pass);

  /// Elimina un registro de saque
  Future<void> deletePass(String id);

  /// Obtiene los saques filtrados por tipo
  Future<List<GoalkeeperPassModel>> getPassesByType(String userId, String type);

  /// Obtiene los saques filtrados por resultado (exitoso o fallido)
  Future<List<GoalkeeperPassModel>> getPassesByResult(
    String userId,
    String result,
  );

  /// Obtiene los saques realizados entre dos fechas
  Future<List<GoalkeeperPassModel>> getPassesByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  );

  /// Escucha los cambios en tiempo real de los saques de un usuario
  Stream<List<GoalkeeperPassModel>> watchUserPasses(String userId);

  /// Escucha los cambios en tiempo real de los saques de un partido específico
  Stream<List<GoalkeeperPassModel>> watchMatchPasses(String matchId);

  /// Obtiene estadísticas de saques por tipo y resultado
  Future<Map<String, Map<String, int>>> getPassTypeStatistics(String userId);

  /// Cuenta el número de saques por resultado (exitoso o fallido)
  Future<Map<String, int>> countPassesByResult(String userId);
}
