/// Modelo para representar una posición en coordenadas 2D
library;

import 'dart:math' as math;

class Position {
  final double x;
  final double y;

  const Position({required this.x, required this.y});

  factory Position.center() {
    return const Position(x: 0.5, y: 0.5);
  }

  factory Position.fromMap(Map<String, dynamic> map) {
    return Position(
      x: (map['x'] ?? 0.5).toDouble(),
      y: (map['y'] ?? 0.5).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'x': x, 'y': y};
  }

  double distanceTo(Position other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}
