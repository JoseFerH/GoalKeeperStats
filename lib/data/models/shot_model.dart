import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:goalkeeper_stats/data/models/position.dart';
import 'dart:math' as math;

class ShotModel {
  final String id;
  final String userId;
  final String? matchId;
  final int? minute;
  final Position goalPosition;
  final Position shooterPosition;
  final Position goalkeeperPosition;
  final String result;
  final String? shotType;
  final String? goalType;
  final String? blockType;
  final DateTime timestamp;
  final String? notes;

  static const String RESULT_GOAL = 'goal';
  static const String RESULT_SAVED = 'saved';
  static const String SHOT_TYPE_OPEN_PLAY = 'open_play';
  static const String SHOT_TYPE_THROW_IN = 'throw_in';
  static const String SHOT_TYPE_FREE_KICK = 'free_kick';
  static const String SHOT_TYPE_SIXTH_FOUL = 'sixth_foul';
  static const String SHOT_TYPE_PENALTY = 'penalty';
  static const String SHOT_TYPE_CORNER = 'corner';
  static const String GOAL_TYPE_HEADER = 'header';
  static const String GOAL_TYPE_VOLLEY = 'volley';
  static const String GOAL_TYPE_ONE_ON_ONE = 'one_on_one';
  static const String GOAL_TYPE_FAR_POST = 'far_post';
  static const String GOAL_TYPE_NUTMEG = 'nutmeg';
  static const String GOAL_TYPE_REBOUND = 'rebound';
  static const String GOAL_TYPE_OWN_GOAL = 'own_goal';
  static const String GOAL_TYPE_DEFLECTION = 'deflection';
  static const String BLOCK_TYPE_BLOCK = 'block';
  static const String BLOCK_TYPE_DEFLECTION = 'deflection';
  static const String BLOCK_TYPE_BARRIER = 'barrier';
  static const String BLOCK_TYPE_FOOT_SAVE = 'foot_save';
  static const String BLOCK_TYPE_SIDE_FALL_BLOCK = 'side_fall_block';
  static const String BLOCK_TYPE_SIDE_FALL_DEFLECTION = 'side_fall_deflection';
  static const String BLOCK_TYPE_CROSS = 'cross';
  static const String BLOCK_TYPE_CLEARANCE = 'clearance';
  static const String BLOCK_TYPE_NARROW_ANGLE = 'narrow_angle';

  ShotModel({
    required this.id,
    required this.userId,
    this.matchId,
    this.minute,
    required this.goalPosition,
    required this.shooterPosition,
    required this.goalkeeperPosition,
    required this.result,
    this.shotType,
    this.goalType,
    this.blockType,
    required this.timestamp,
    this.notes,
  });

  // Método para crear desde un DocumentSnapshot de Firestore
  factory ShotModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ShotModel.fromMap(data, doc.id);
  }

  factory ShotModel.create({
    required String userId,
    String? matchId,
    int? minute,
    required Position goalPosition,
    required Position shooterPosition,
    required Position goalkeeperPosition,
    required String result,
    String? shotType,
    String? goalType,
    String? blockType,
    String? notes,
  }) {
    return ShotModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      matchId: matchId,
      minute: minute,
      goalPosition: goalPosition,
      shooterPosition: shooterPosition,
      goalkeeperPosition: goalkeeperPosition,
      result: result,
      shotType: shotType,
      goalType: result == RESULT_GOAL ? goalType : null,
      blockType: result == RESULT_SAVED ? blockType : null,
      timestamp: DateTime.now(),
      notes: notes,
    );
  }

  factory ShotModel.fromMap(Map<String, dynamic> map, String id) {
    return ShotModel(
      id: id,
      userId: map['userId'] ?? '',
      matchId: map['matchId'],
      minute: map['minute'],
      goalPosition: Position.fromMap(map['goalPosition'] ?? {}),
      shooterPosition: Position.fromMap(map['shooterPosition'] ?? {}),
      goalkeeperPosition: Position.fromMap(map['goalkeeperPosition'] ?? {}),
      result: map['result'] ?? RESULT_SAVED,
      shotType: map['shotType'],
      goalType: map['goalType'],
      blockType: map['blockType'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'matchId': matchId,
      'minute': minute,
      'goalPosition': goalPosition.toMap(),
      'shooterPosition': shooterPosition.toMap(),
      'goalkeeperPosition': goalkeeperPosition.toMap(),
      'result': result,
      'shotType': shotType,
      'goalType': goalType,
      'blockType': blockType,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(), // Añadido para tracking
    };
  }

  // Resto de métodos existentes
  bool get isGoal => result == RESULT_GOAL;
  bool get isSaved => result == RESULT_SAVED;

  double get shotDistance {
    final dx = shooterPosition.x - goalkeeperPosition.x;
    final dy = shooterPosition.y - goalkeeperPosition.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  String get goalZone {
    final x = goalPosition.x;
    final y = goalPosition.y;

    String horizontal = _getHorizontalZone(x);
    String vertical = _getVerticalZone(y);

    return '$vertical-$horizontal';
  }

  String _getHorizontalZone(double x) {
    if (x < 0.33) return 'left';
    if (x < 0.66) return 'center';
    return 'right';
  }

  String _getVerticalZone(double y) {
    if (y < 0.33) return 'bottom';
    if (y < 0.66) return 'middle';
    return 'top';
  }

  ShotModel copyWith({
    String? userId,
    String? matchId,
    int? minute,
    Position? goalPosition,
    Position? shooterPosition,
    Position? goalkeeperPosition,
    String? result,
    String? shotType,
    String? goalType,
    String? blockType,
    DateTime? timestamp,
    String? notes,
  }) {
    final updatedResult = result ?? this.result;

    return ShotModel(
      id: id,
      userId: userId ?? this.userId,
      matchId: matchId ?? this.matchId,
      minute: minute ?? this.minute,
      goalPosition: goalPosition ?? this.goalPosition,
      shooterPosition: shooterPosition ?? this.shooterPosition,
      goalkeeperPosition: goalkeeperPosition ?? this.goalkeeperPosition,
      result: updatedResult,
      shotType: shotType ?? this.shotType,
      goalType:
          updatedResult == RESULT_GOAL ? (goalType ?? this.goalType) : null,
      blockType:
          updatedResult == RESULT_SAVED ? (blockType ?? this.blockType) : null,
      timestamp: timestamp ?? this.timestamp,
      notes: notes ?? this.notes,
    );
  }
}
