import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:goalkeeper_stats/data/models/position.dart';

class GoalkeeperPassModel {
  final String id;
  final String userId;
  final String? matchId;
  final int? minute;
  final String type;
  final String result;
  final Position? startPosition;
  final Position? endPosition;
  final DateTime timestamp;
  final String? notes;

  static const String TYPE_HAND = 'hand';
  static const String TYPE_GROUND = 'ground';
  static const String TYPE_VOLLEY = 'volley';
  static const String TYPE_GOAL_KICK = 'goal_kick';
  static const String RESULT_SUCCESSFUL = 'successful';
  static const String RESULT_FAILED = 'failed';

  GoalkeeperPassModel({
    required this.id,
    required this.userId,
    this.matchId,
    this.minute,
    required this.type,
    required this.result,
    this.startPosition,
    this.endPosition,
    required this.timestamp,
    this.notes,
  });

  // Método para crear desde un DocumentSnapshot de Firestore
  factory GoalkeeperPassModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return GoalkeeperPassModel.fromMap(data, doc.id);
  }

  factory GoalkeeperPassModel.create({
    required String userId,
    String? matchId,
    int? minute,
    required String type,
    required String result,
    Position? startPosition,
    Position? endPosition,
    String? notes,
  }) {
    return GoalkeeperPassModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      matchId: matchId,
      minute: minute,
      type: type,
      result: result,
      startPosition: startPosition,
      endPosition: endPosition,
      timestamp: DateTime.now(),
      notes: notes,
    );
  }

  factory GoalkeeperPassModel.fromMap(Map<String, dynamic> map, String id) {
    return GoalkeeperPassModel(
      id: id,
      userId: map['userId'] ?? '',
      matchId: map['matchId'],
      minute: map['minute'],
      type: map['type'] ?? TYPE_HAND,
      result: map['result'] ?? RESULT_SUCCESSFUL,
      startPosition: map['startPosition'] != null
          ? Position.fromMap(map['startPosition'])
          : null,
      endPosition: map['endPosition'] != null
          ? Position.fromMap(map['endPosition'])
          : null,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'matchId': matchId,
      'minute': minute,
      'type': type,
      'result': result,
      'startPosition': startPosition?.toMap(),
      'endPosition': endPosition?.toMap(),
      'timestamp': timestamp.millisecondsSinceEpoch,
      'notes': notes,
    };
  }

  // Resto de métodos existentes
  bool get isSuccessful => result == RESULT_SUCCESSFUL;
  bool get isFailed => result == RESULT_FAILED;

  double? get passDistance {
    if (startPosition == null || endPosition == null) return null;
    return startPosition!.distanceTo(endPosition!);
  }

  String get typeDisplayName {
    switch (type) {
      case TYPE_HAND:
        return 'Saque de mano';
      case TYPE_GROUND:
        return 'Saque raso';
      case TYPE_VOLLEY:
        return 'Volea';
      case TYPE_GOAL_KICK:
        return 'Saque de puerta';
      default:
        return 'Saque';
    }
  }

  GoalkeeperPassModel copyWith({
    String? userId,
    String? matchId,
    int? minute,
    String? type,
    String? result,
    Position? startPosition,
    Position? endPosition,
    DateTime? timestamp,
    String? notes,
  }) {
    return GoalkeeperPassModel(
      id: id,
      userId: userId ?? this.userId,
      matchId: matchId ?? this.matchId,
      minute: minute ?? this.minute,
      type: type ?? this.type,
      result: result ?? this.result,
      startPosition: startPosition ?? this.startPosition,
      endPosition: endPosition ?? this.endPosition,
      timestamp: timestamp ?? this.timestamp,
      notes: notes ?? this.notes,
    );
  }
}
