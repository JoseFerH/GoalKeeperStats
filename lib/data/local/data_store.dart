import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/data/models/match_model.dart';
import 'package:goalkeeper_stats/data/models/shot_model.dart';
import 'package:goalkeeper_stats/data/models/goalkeeper_pass_model.dart';
import 'package:goalkeeper_stats/data/models/position.dart';

/// Almacenamiento de datos en memoria para desarrollo local
///
/// Este es un singleton que almacena todos los datos de la aplicación
/// en listas en memoria durante el tiempo de ejecución.
class LocalDataStore {
  // Instancia singleton
  static final LocalDataStore _instance = LocalDataStore._internal();

  factory LocalDataStore() {
    return _instance;
  }

  LocalDataStore._internal();

  // Datos almacenados en memoria
  final List<UserModel> users = [];
  final List<MatchModel> matches = [];
  final List<ShotModel> shots = [];
  final List<GoalkeeperPassModel> passes = [];

  // Usuario actualmente autenticado
  UserModel? currentUser;

  // Método para resetear todos los datos (útil para pruebas)
  void reset() {
    users.clear();
    matches.clear();
    shots.clear();
    passes.clear();
    currentUser = null;
  }

  // Método para agregar datos de prueba
  void addTestData() {
    // Crear usuario de prueba
    final user = UserModel.newUser(
      id: '123',
      name: 'Usuario de Prueba',
      email: 'test@example.com',
      photoUrl: null,
    );

    users.add(user);
    currentUser = user;

    // Agregar algunos partidos
    final match1 = MatchModel.create(
      userId: user.id,
      date: DateTime.now().subtract(const Duration(days: 2)),
      type: MatchModel.TYPE_OFFICIAL,
      opponent: 'FC Barcelona',
      venue: 'Camp Nou',
      goalsScored: 2,
      goalsConceded: 1,
    );

    final match2 = MatchModel.create(
      userId: user.id,
      date: DateTime.now().subtract(const Duration(days: 7)),
      type: MatchModel.TYPE_FRIENDLY,
      opponent: 'Real Madrid',
      venue: 'Santiago Bernabéu',
      goalsScored: 1,
      goalsConceded: 3,
    );

    final match3 = MatchModel.create(
      userId: user.id,
      date: DateTime.now().add(const Duration(days: 5)),
      type: MatchModel.TYPE_TRAINING,
      opponent: 'Equipo B',
      venue: 'Ciudad Deportiva',
    );

    matches.addAll([match1, match2, match3]);

    // Agregar algunos tiros
    shots.addAll([
      ShotModel.create(
        userId: user.id,
        matchId: match1.id,
        minute: 15,
        goalPosition: const Position(x: 0.2, y: 0.8),
        shooterPosition: const Position(x: 0.3, y: 0.4),
        goalkeeperPosition: const Position(x: 0.5, y: 0.1),
        result: ShotModel.RESULT_SAVED,
      ),
      ShotModel.create(
        userId: user.id,
        matchId: match1.id,
        minute: 36,
        goalPosition: const Position(x: 0.8, y: 0.9),
        shooterPosition: const Position(x: 0.7, y: 0.3),
        goalkeeperPosition: const Position(x: 0.6, y: 0.1),
        result: ShotModel.RESULT_GOAL,
        goalType: ShotModel.GOAL_TYPE_VOLLEY,
      ),
      ShotModel.create(
        userId: user.id,
        matchId: match2.id,
        minute: 25,
        goalPosition: const Position(x: 0.5, y: 0.5),
        shooterPosition: const Position(x: 0.4, y: 0.6),
        goalkeeperPosition: const Position(x: 0.5, y: 0.1),
        result: ShotModel.RESULT_SAVED,
      ),
    ]);

    // Agregar algunos saques
    passes.addAll([
      GoalkeeperPassModel.create(
        userId: user.id,
        matchId: match1.id,
        minute: 12,
        type: GoalkeeperPassModel.TYPE_HAND,
        result: GoalkeeperPassModel.RESULT_SUCCESSFUL,
        startPosition: const Position(x: 0.1, y: 0.1),
        endPosition: const Position(x: 0.5, y: 0.6),
      ),
      GoalkeeperPassModel.create(
        userId: user.id,
        matchId: match2.id,
        minute: 30,
        type: GoalkeeperPassModel.TYPE_VOLLEY,
        result: GoalkeeperPassModel.RESULT_FAILED,
        startPosition: const Position(x: 0.1, y: 0.1),
        endPosition: const Position(x: 0.3, y: 0.8),
      ),
    ]);
  }
}
