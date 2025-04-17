import 'dart:convert';
import 'package:goalkeeper_stats/data/models/match_model.dart';
import 'package:goalkeeper_stats/domain/repositories/matches_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

/// Implementación de MatchesRepository con persistencia local
///
/// Utiliza SharedPreferences para almacenar los partidos y mantenerlos
/// entre sesiones de la aplicación para pruebas y desarrollo.
class PersistentMatchesRepository implements MatchesRepository {
  final String _matchesKey = 'matches_data';
  List<MatchModel> _matches = [];
  final _matchesStreamController =
      StreamController<List<MatchModel>>.broadcast();

  // Singleton para evitar múltiples instancias
  static PersistentMatchesRepository? _instance;

  static Future<PersistentMatchesRepository> getInstance() async {
    if (_instance == null) {
      _instance = PersistentMatchesRepository._();
      await _instance!._loadData();
    }
    return _instance!;
  }

  PersistentMatchesRepository._();

  // Cargar datos almacenados en SharedPreferences
  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? matchesJson = prefs.getString(_matchesKey);

      if (matchesJson != null) {
        final List<dynamic> decoded = jsonDecode(matchesJson);
        _matches = decoded
            .map((item) => MatchModel.fromMap(item, item['id'] ?? ''))
            .toList();

        // Actualizar el stream con los datos cargados
        _matchesStreamController.add(_matches);

        print('Datos cargados: ${_matches.length} partidos');
      }
    } catch (e) {
      print('Error al cargar datos: $e');
    }
  }

  // Guardar datos en SharedPreferences
  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> matchesMaps = _matches.map((match) {
        final map = match.toMap();
        map['id'] = match.id; // Añadir ID al mapa
        return map;
      }).toList();

      await prefs.setString(_matchesKey, jsonEncode(matchesMaps));
      print('Datos guardados: ${_matches.length} partidos');
    } catch (e) {
      print('Error al guardar datos: $e');
    }
  }

  @override
  Future<List<MatchModel>> getMatchesByUser(String userId) async {
    // Simular retraso para mostrar carga (opcional)
    await Future.delayed(const Duration(milliseconds: 300));
    return _matches.where((match) => match.userId == userId).toList();
  }

  @override
  Future<MatchModel?> getMatchById(String id) async {
    return _matches.firstWhere((match) => match.id == id,
        orElse: () => throw Exception('Partido no encontrado'));
  }

  @override
  Future<MatchModel> createMatch(MatchModel match) async {
    // Crear un ID único si no tiene uno
    final newMatch = MatchModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: match.userId,
      date: match.date,
      type: match.type,
      opponent: match.opponent,
      venue: match.venue,
      notes: match.notes,
      goalsScored: match.goalsScored,
      goalsConceded: match.goalsConceded,
    );

    _matches.add(newMatch);

    // Guardar y notificar
    await _saveData();
    _matchesStreamController.add(_matches);

    return newMatch;
  }

  @override
  Future<MatchModel> updateMatch(MatchModel match) async {
    final index = _matches.indexWhere((m) => m.id == match.id);

    if (index >= 0) {
      _matches[index] = match;
      await _saveData();
      _matchesStreamController.add(_matches);
      return match;
    } else {
      throw Exception('Partido no encontrado para actualizar');
    }
  }

  @override
  Future<void> deleteMatch(String id) async {
    _matches.removeWhere((match) => match.id == id);
    await _saveData();
    _matchesStreamController.add(_matches);
  }

  @override
  Future<List<MatchModel>> getMatchesByType(String userId, String type) async {
    return _matches
        .where((match) => match.userId == userId && match.type == type)
        .toList();
  }

  @override
  Future<List<MatchModel>> getMatchesByDateRange(
      String userId, DateTime startDate, DateTime endDate) async {
    return _matches
        .where((match) =>
            match.userId == userId &&
            match.date.isAfter(startDate) &&
            match.date.isBefore(endDate))
        .toList();
  }

  @override
  Stream<List<MatchModel>> watchUserMatches(String userId) {
    // Filtrar por usuario cuando emite valores
    return _matchesStreamController.stream.map(
        (matches) => matches.where((match) => match.userId == userId).toList());
  }

  @override
  Future<List<MatchModel>> searchMatches(String userId, String query) async {
    final lowercaseQuery = query.toLowerCase();

    return _matches
        .where((match) =>
            match.userId == userId &&
            ((match.opponent
                        ?.toLowerCase()
                        .contains(lowercaseQuery) ??
                    false) ||
                (match.venue?.toLowerCase().contains(lowercaseQuery) ??
                    false) ||
                (match.notes?.toLowerCase().contains(lowercaseQuery) ?? false)))
        .toList();
  }

  // Limpiar recursos
  void dispose() {
    _matchesStreamController.close();
  }
}
