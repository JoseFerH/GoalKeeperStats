// lib/data/repositories/local_matches_repository.dart

import 'package:goalkeeper_stats/domain/repositories/matches_repository.dart';
import 'package:goalkeeper_stats/data/models/match_model.dart';
import 'dart:async';

class LocalMatchesRepository implements MatchesRepository {
  // Lista de partidos de prueba
  final List<MatchModel> _matches = [
    MatchModel(
      id: 'match1',
      userId: 'local_user_123',
      date: DateTime.now().subtract(const Duration(days: 7)),
      type: MatchModel.TYPE_OFFICIAL,
      opponent: 'FC Barcelona',
      venue: 'Camp Nou',
      notes: 'Partido complicado',
      goalsScored: 3,
      goalsConceded: 2,
    ),
    MatchModel(
      id: 'match2',
      userId: 'local_user_123',
      date: DateTime.now().subtract(const Duration(days: 14)),
      type: MatchModel.TYPE_FRIENDLY,
      opponent: 'Real Madrid',
      venue: 'Santiago Bernabéu',
      notes: 'Buen partido, buena defensa',
      goalsScored: 1,
      goalsConceded: 1,
    ),
    MatchModel(
      id: 'match3',
      userId: 'local_user_123',
      date: DateTime.now().subtract(const Duration(days: 3)),
      type: MatchModel.TYPE_TRAINING,
      opponent: 'Entrenamiento del equipo',
      venue: 'Campo de entrenamiento',
      notes: 'Sesión centrada en saques',
      goalsScored: null,
      goalsConceded: null,
    ),
    MatchModel(
      id: 'match4',
      userId: 'local_user_123',
      date: DateTime.now().add(const Duration(days: 5)),
      type: MatchModel.TYPE_OFFICIAL,
      opponent: 'Atlético de Madrid',
      venue: 'Metropolitano',
      notes: 'Partido clave para el campeonato',
      goalsScored: null,
      goalsConceded: null,
    ),
  ];

  // Controlador para el stream de partidos
  final _matchesController = StreamController<List<MatchModel>>.broadcast();

  LocalMatchesRepository() {
    // Inicializar el stream con los partidos de prueba
    _matchesController.add(_matches);
  }

  @override
  Future<List<MatchModel>> getMatchesByUser(String userId) async {
    print("LocalMatchesRepository.getMatchesByUser llamado para $userId");
    // Simular un pequeño retraso para emular una operación de red
    await Future.delayed(const Duration(milliseconds: 300));
    return _matches.where((match) => match.userId == userId).toList();
  }

  @override
  Future<MatchModel?> getMatchById(String id) async {
    print("LocalMatchesRepository.getMatchById llamado para $id");
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      return _matches.firstWhere((match) => match.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<MatchModel> createMatch(MatchModel match) async {
    print("LocalMatchesRepository.createMatch llamado");
    await Future.delayed(const Duration(milliseconds: 300));

    // Crear un ID único para el nuevo partido
    final newId = 'match${_matches.length + 1}';

    // Crear una copia del partido con el nuevo ID
    final newMatch = MatchModel(
      id: newId,
      userId: match.userId,
      date: match.date,
      type: match.type,
      opponent: match.opponent,
      venue: match.venue,
      notes: match.notes,
      goalsScored: match.goalsScored,
      goalsConceded: match.goalsConceded,
    );

    // Agregar a la lista local
    _matches.add(newMatch);

    // Emitir la lista actualizada
    _matchesController.add(_matches);

    return newMatch;
  }

  @override
  Future<MatchModel> updateMatch(MatchModel match) async {
    print("LocalMatchesRepository.updateMatch llamado para ${match.id}");
    await Future.delayed(const Duration(milliseconds: 300));

    // Buscar el índice del partido a actualizar
    final index = _matches.indexWhere((m) => m.id == match.id);
    if (index >= 0) {
      _matches[index] = match;

      // Emitir la lista actualizada
      _matchesController.add(_matches);

      return match;
    } else {
      throw Exception('Partido no encontrado');
    }
  }

  @override
  Future<void> deleteMatch(String id) async {
    print("LocalMatchesRepository.deleteMatch llamado para $id");
    await Future.delayed(const Duration(milliseconds: 300));

    // Eliminar el partido
    _matches.removeWhere((match) => match.id == id);

    // Emitir la lista actualizada
    _matchesController.add(_matches);
  }

  @override
  Future<List<MatchModel>> getMatchesByType(String userId, String type) async {
    print(
        "LocalMatchesRepository.getMatchesByType llamado para $userId, tipo: $type");
    await Future.delayed(const Duration(milliseconds: 300));
    return _matches
        .where((match) => match.userId == userId && match.type == type)
        .toList();
  }

  @override
  Future<List<MatchModel>> getMatchesByDateRange(
      String userId, DateTime startDate, DateTime endDate) async {
    print("LocalMatchesRepository.getMatchesByDateRange llamado");
    await Future.delayed(const Duration(milliseconds: 300));
    return _matches
        .where((match) =>
            match.userId == userId &&
            match.date.isAfter(startDate) &&
            match.date.isBefore(endDate))
        .toList();
  }

  @override
  Stream<List<MatchModel>> watchUserMatches(String userId) {
    print("LocalMatchesRepository.watchUserMatches llamado para $userId");
    // Filtramos el stream para que solo entregue los partidos del usuario
    return _matchesController.stream.map(
        (matches) => matches.where((match) => match.userId == userId).toList());
  }

  @override
  Future<List<MatchModel>> searchMatches(String userId, String query) async {
    print(
        "LocalMatchesRepository.searchMatches llamado para $userId, query: $query");
    await Future.delayed(const Duration(milliseconds: 300));
    final queryLower = query.toLowerCase();
    return _matches
        .where((match) =>
            match.userId == userId &&
            ((match.opponent?.toLowerCase().contains(queryLower) ?? false) ||
                (match.venue?.toLowerCase().contains(queryLower) ?? false) ||
                (match.notes?.toLowerCase().contains(queryLower) ?? false)))
        .toList();
  }

  // Método para cerrar el stream cuando ya no se necesita
  void dispose() {
    _matchesController.close();
  }
}
