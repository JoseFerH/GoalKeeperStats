import 'package:goalkeeper_stats/data/models/shot_model.dart';

/// Interfaz que define las operaciones para gestionar tiros
abstract class ShotsRepository {
  /// Obtiene todos los tiros de un usuario
  Future<List<ShotModel>> getShotsByUser(String userId);

  /// Obtiene los tiros asociados a un partido específico
  Future<List<ShotModel>> getShotsByMatch(String matchId);

  /// Obtiene un tiro específico por su ID
  Future<ShotModel?> getShotById(String id);

  /// Crea un nuevo registro de tiro
  Future<ShotModel> createShot(ShotModel shot);

  /// Actualiza un registro de tiro existente
  Future<ShotModel> updateShot(ShotModel shot);

  /// Elimina un registro de tiro
  Future<void> deleteShot(String id);

  /// Obtiene los tiros filtrados por resultado (gol o atajada)
  Future<List<ShotModel>> getShotsByResult(String userId, String result);

  /// Obtiene los tiros realizados entre dos fechas
  Future<List<ShotModel>> getShotsByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  );

  /// Escucha los cambios en tiempo real de los tiros de un usuario
  Stream<List<ShotModel>> watchUserShots(String userId);

  /// Escucha los cambios en tiempo real de los tiros de un partido específico
  Stream<List<ShotModel>> watchMatchShots(String matchId);

  /// Obtiene estadísticas agrupadas por zona de la portería
  Future<Map<String, Map<String, int>>> getGoalZoneStatistics(String userId);

  /// Cuenta el número de tiros por resultado (gol o atajada)
  Future<Map<String, int>> countShotsByResult(String userId);
}
