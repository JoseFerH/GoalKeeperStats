import 'package:goalkeeper_stats/data/models/match_model.dart';

/// Interfaz que define las operaciones para gestionar partidos y eventos
abstract class MatchesRepository {
  /// Obtiene todos los partidos de un usuario
  Future<List<MatchModel>> getMatchesByUser(String userId);

  /// Obtiene un partido específico por su ID
  Future<MatchModel?> getMatchById(String id);

  /// Crea un nuevo partido
  Future<MatchModel> createMatch(MatchModel match);

  /// Actualiza un partido existente
  Future<MatchModel> updateMatch(MatchModel match);

  /// Elimina un partido
  Future<void> deleteMatch(String id);

  /// Obtiene los partidos filtrados por tipo
  Future<List<MatchModel>> getMatchesByType(String userId, String type);

  /// Obtiene los partidos entre dos fechas
  Future<List<MatchModel>> getMatchesByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  );

  /// Escucha los cambios en tiempo real de los partidos de un usuario
  Stream<List<MatchModel>> watchUserMatches(String userId);

  /// Busca partidos que coincidan con un texto
  Future<List<MatchModel>> searchMatches(String userId, String query);
}
