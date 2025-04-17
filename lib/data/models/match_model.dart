import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo que representa un partido o evento de entrenamiento
class MatchModel {
  final String id;
  final String userId;
  final DateTime date;
  final String type;
  final String? opponent;
  final String? venue;
  final String? notes;
  final int? goalsScored;
  final int? goalsConceded;

  static const String TYPE_OFFICIAL = 'official';
  static const String TYPE_FRIENDLY = 'friendly';
  static const String TYPE_TRAINING = 'training';

  MatchModel({
    required this.id,
    required this.userId,
    required this.date,
    required this.type,
    this.opponent,
    this.venue,
    this.notes,
    this.goalsScored,
    this.goalsConceded,
  });

  // Método para crear desde un DocumentSnapshot de Firestore
  factory MatchModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return MatchModel.fromMap(data, doc.id);
  }

  factory MatchModel.create({
    required String userId,
    required DateTime date,
    required String type,
    String? opponent,
    String? venue,
    String? notes,
    int? goalsScored,
    int? goalsConceded,
  }) {
    return MatchModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      date: date,
      type: type,
      opponent: opponent,
      venue: venue,
      notes: notes,
      goalsScored: goalsScored,
      goalsConceded: goalsConceded,
    );
  }

  factory MatchModel.fromMap(Map<String, dynamic> map, String id) {
    return MatchModel(
      id: id,
      userId: map['userId'] ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] ?? 0),
      type: map['type'] ?? TYPE_FRIENDLY,
      opponent: map['opponent'],
      venue: map['venue'],
      notes: map['notes'],
      goalsScored: map['goalsScored'],
      goalsConceded: map['goalsConceded'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'date': date.millisecondsSinceEpoch,
      'type': type,
      'opponent': opponent,
      'venue': venue,
      'notes': notes,
      'goalsScored': goalsScored,
      'goalsConceded': goalsConceded,
      'updatedAt':
          FieldValue.serverTimestamp(), // Mejor usar timestamp del servidor
    };
  }

  // Resto de métodos existentes
  String get displayName {
    switch (type) {
      case TYPE_OFFICIAL:
        return 'Partido Oficial vs ${opponent ?? "Rival"}';
      case TYPE_FRIENDLY:
        return 'Amistoso vs ${opponent ?? "Rival"}';
      case TYPE_TRAINING:
        return 'Entrenamiento ${opponent != null ? "con $opponent" : ""}';
      default:
        return 'Evento de Fútbol';
    }
  }

  bool get isOfficial => type == TYPE_OFFICIAL;
  bool get isFriendly => type == TYPE_FRIENDLY;
  bool get isTraining => type == TYPE_TRAINING;

  String get result {
    if (goalsScored == null || goalsConceded == null) return 'Sin resultado';
    return '$goalsScored - $goalsConceded';
  }

  bool get isWin =>
      goalsScored != null &&
      goalsConceded != null &&
      goalsScored! > goalsConceded!;

  bool get isLoss =>
      goalsScored != null &&
      goalsConceded != null &&
      goalsScored! < goalsConceded!;

  bool get isDraw =>
      goalsScored != null &&
      goalsConceded != null &&
      goalsScored! == goalsConceded!;

  MatchModel copyWith({
    String? userId,
    DateTime? date,
    String? type,
    String? opponent,
    String? venue,
    String? notes,
    int? goalsScored,
    int? goalsConceded,
  }) {
    return MatchModel(
      id: id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      type: type ?? this.type,
      opponent: opponent ?? this.opponent,
      venue: venue ?? this.venue,
      notes: notes ?? this.notes,
      goalsScored: goalsScored ?? this.goalsScored,
      goalsConceded: goalsConceded ?? this.goalsConceded,
    );
  }
}
