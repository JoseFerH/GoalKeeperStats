import 'dart:math';
import 'package:goalkeeper_stats/data/models/shot_model.dart';
import 'package:goalkeeper_stats/data/models/position.dart';
import 'package:goalkeeper_stats/domain/repositories/shots_repository.dart';

/// Utilidad para generar tiros de muestra para todas las zonas de la portería
class ShotGenerator {
  /// Genera 5 tiros para cada una de las 12 zonas de la portería (60 tiros en total)
  static Future<void> generateSampleShots({
    required ShotsRepository repository,
    required String userId,
    required List<String> matchIds,
  }) async {
    final Random random = Random();

    // Definir las 12 zonas de la portería (4 filas x 3 columnas)
    final List<Map<String, double>> goalZones = [
      // Fila Superior
      {
        'xMin': 0.0,
        'xMax': 0.33,
        'yMin': 0.0,
        'yMax': 0.25
      }, // Superior Izquierda
      {
        'xMin': 0.33,
        'xMax': 0.66,
        'yMin': 0.0,
        'yMax': 0.25
      }, // Superior Centro
      {
        'xMin': 0.66,
        'xMax': 1.0,
        'yMin': 0.0,
        'yMax': 0.25
      }, // Superior Derecha

      // Fila Media-Alta
      {
        'xMin': 0.0,
        'xMax': 0.33,
        'yMin': 0.25,
        'yMax': 0.5
      }, // Media-Alta Izquierda
      {
        'xMin': 0.33,
        'xMax': 0.66,
        'yMin': 0.25,
        'yMax': 0.5
      }, // Media-Alta Centro
      {
        'xMin': 0.66,
        'xMax': 1.0,
        'yMin': 0.25,
        'yMax': 0.5
      }, // Media-Alta Derecha

      // Fila Media-Baja
      {
        'xMin': 0.0,
        'xMax': 0.33,
        'yMin': 0.5,
        'yMax': 0.75
      }, // Media-Baja Izquierda
      {
        'xMin': 0.33,
        'xMax': 0.66,
        'yMin': 0.5,
        'yMax': 0.75
      }, // Media-Baja Centro
      {
        'xMin': 0.66,
        'xMax': 1.0,
        'yMin': 0.5,
        'yMax': 0.75
      }, // Media-Baja Derecha

      // Fila Raso
      {'xMin': 0.0, 'xMax': 0.33, 'yMin': 0.75, 'yMax': 1.0}, // Raso Izquierda
      {'xMin': 0.33, 'xMax': 0.66, 'yMin': 0.75, 'yMax': 1.0}, // Raso Centro
      {'xMin': 0.66, 'xMax': 1.0, 'yMin': 0.75, 'yMax': 1.0}, // Raso Derecha
    ];

    // Tipos de tiro para variedad
    final List<String> shotTypes = [
      ShotModel.SHOT_TYPE_OPEN_PLAY,
      ShotModel.SHOT_TYPE_THROW_IN,
      ShotModel.SHOT_TYPE_FREE_KICK,
      ShotModel.SHOT_TYPE_SIXTH_FOUL,
      ShotModel.SHOT_TYPE_PENALTY,
      ShotModel.SHOT_TYPE_CORNER
    ];

    // Tipos de gol
    final List<String> goalTypes = [
      ShotModel.GOAL_TYPE_HEADER,
      ShotModel.GOAL_TYPE_VOLLEY,
      ShotModel.GOAL_TYPE_ONE_ON_ONE,
      ShotModel.GOAL_TYPE_FAR_POST,
      ShotModel.GOAL_TYPE_NUTMEG,
      ShotModel.GOAL_TYPE_REBOUND,
      ShotModel.GOAL_TYPE_OWN_GOAL,
      ShotModel.GOAL_TYPE_DEFLECTION
    ];

    // Tipos de bloqueo
    final List<String> blockTypes = [
      ShotModel.BLOCK_TYPE_BLOCK,
      ShotModel.BLOCK_TYPE_DEFLECTION,
      ShotModel.BLOCK_TYPE_BARRIER,
      ShotModel.BLOCK_TYPE_FOOT_SAVE,
      ShotModel.BLOCK_TYPE_SIDE_FALL_BLOCK,
      ShotModel.BLOCK_TYPE_SIDE_FALL_DEFLECTION,
      ShotModel.BLOCK_TYPE_CROSS,
      ShotModel.BLOCK_TYPE_CLEARANCE,
      ShotModel.BLOCK_TYPE_NARROW_ANGLE
    ];

    // Para cada zona de la portería
    for (int zoneIndex = 0; zoneIndex < goalZones.length; zoneIndex++) {
      final zone = goalZones[zoneIndex];
      final zoneName = _getZoneName(zoneIndex);

      // Generar 5 tiros para cada zona
      for (int i = 0; i < 5; i++) {
        // Seleccionar un partido aleatorio (o ninguno)
        final String? matchId =
            matchIds.isEmpty ? null : matchIds[random.nextInt(matchIds.length)];

        // Posición aleatoria dentro de la zona
        final goalX = zone['xMin']! +
            random.nextDouble() * (zone['xMax']! - zone['xMin']!);
        final goalY = zone['yMin']! +
            random.nextDouble() * (zone['yMax']! - zone['yMin']!);

        // Posición aleatoria del tirador en el campo
        final shooterX = random.nextDouble();
        final shooterY = random.nextDouble();

        // Posición aleatoria del portero
        final goalkeeperX =
            0.3 + random.nextDouble() * 0.4; // Más probable en el centro
        final goalkeeperY = 0.6 +
            random.nextDouble() * 0.3; // Más probable cerca de la portería

        // Determinar el resultado (60% de probabilidad de ser atajada)
        final bool isSaved = random.nextDouble() < 0.6;
        final String result =
            isSaved ? ShotModel.RESULT_SAVED : ShotModel.RESULT_GOAL;

        // Seleccionar tipo de tiro, gol o bloqueo según corresponda
        final String shotType = shotTypes[random.nextInt(shotTypes.length)];
        final String? goalType =
            isSaved ? null : goalTypes[random.nextInt(goalTypes.length)];
        final String? blockType =
            isSaved ? blockTypes[random.nextInt(blockTypes.length)] : null;

        // Crear el modelo de tiro
        final shot = ShotModel.create(
          userId: userId,
          matchId: matchId,
          minute: matchId != null ? random.nextInt(90) + 1 : null,
          goalPosition: Position(x: goalX, y: goalY),
          shooterPosition: Position(x: shooterX, y: shooterY),
          goalkeeperPosition: Position(x: goalkeeperX, y: goalkeeperY),
          result: result,
          goalType: goalType,
          blockType: blockType,
          shotType: shotType,
          notes: 'Tiro de prueba en zona $zoneName (${i + 1}/5)',
        );

        // Modificar la fecha para distribuir los tiros en el tiempo
        final newShot = _adjustShotDate(shot, random);

        // Guardar en el repositorio
        await repository.createShot(newShot);

        // Pequeña pausa para asegurar timestamps diferentes
        await Future.delayed(Duration(milliseconds: 50));
      }
    }

    print('✅ Generados 60 tiros de prueba (5 por cada zona de la portería)');
  }

  /// Modifica la fecha del tiro para distribuirlos en el tiempo
  static ShotModel _adjustShotDate(ShotModel shot, Random random) {
    // Distribuir los tiros en los últimos 30 días
    final daysAgo = random.nextInt(30);
    final hoursAgo = random.nextInt(24);
    final minutesAgo = random.nextInt(60);

    final newTimestamp = DateTime.now().subtract(Duration(
      days: daysAgo,
      hours: hoursAgo,
      minutes: minutesAgo,
    ));

    // Crear una copia del tiro con la nueva fecha
    return ShotModel(
      id: shot.id,
      userId: shot.userId,
      matchId: shot.matchId,
      minute: shot.minute,
      goalPosition: shot.goalPosition,
      shooterPosition: shot.shooterPosition,
      goalkeeperPosition: shot.goalkeeperPosition,
      result: shot.result,
      shotType: shot.shotType,
      goalType: shot.goalType,
      blockType: shot.blockType,
      timestamp: newTimestamp,
      notes: shot.notes,
    );
  }

  /// Obtiene un nombre descriptivo para la zona
  static String _getZoneName(int zoneIndex) {
    final List<String> zoneNames = [
      'Superior Izquierda',
      'Superior Centro',
      'Superior Derecha',
      'Media-Alta Izquierda',
      'Media-Alta Centro',
      'Media-Alta Derecha',
      'Media-Baja Izquierda',
      'Media-Baja Centro',
      'Media-Baja Derecha',
      'Raso Izquierda',
      'Raso Centro',
      'Raso Derecha',
    ];

    return zoneNames[zoneIndex];
  }
}
