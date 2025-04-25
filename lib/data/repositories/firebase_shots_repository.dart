// lib/data/repositories/firebase_shots_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:goalkeeper_stats/domain/repositories/shots_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/auth_repository.dart';
import 'package:goalkeeper_stats/data/models/shot_model.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/services/cache_manager.dart';

class FirebaseShotsRepository implements ShotsRepository {
  final FirebaseFirestore _firestore;
  final AuthRepository _authRepository;
  final CacheManager _cacheManager;

  // Colección donde se almacenan los tiros
  static const String _shotsCollection = 'shots';
  
  // Claves para caché
  static const String _userShotsCachePrefix = 'user_shots_';
  static const String _matchShotsCachePrefix = 'match_shots_';
  static const String _zoneStatsCachePrefix = 'zone_stats_';
  static const String _resultCountCachePrefix = 'result_count_';
  
  // Duración de caché (en segundos)
  static const int _cacheDuration = 300; // 5 minutos
  
  /// Constructor con posibilidad de inyección para pruebas
  /// Constructor correcto con authRepository requerido
FirebaseShotsRepository({
  FirebaseFirestore? firestore,
  required AuthRepository authRepository,
  CacheManager? cacheManager,
}) : 
  _firestore = firestore ?? FirebaseFirestore.instance,
  _authRepository = authRepository,
  _cacheManager = cacheManager ?? CacheManager();

/// Método correcto que usa el parámetro userId
@override
Future<List<ShotModel>> getShotsByUser(String userId) async {
  try {
    // Verificar autenticación
    final currentUser = await _authRepository.getCurrentUser();
    if (currentUser == null) throw Exception('Usuario no autenticado');
    
    // Intentar obtener desde caché primero
    final cacheKey = '$_userShotsCachePrefix$userId';
    final cachedShots = await _cacheManager.get<List<ShotModel>>(cacheKey);
    
    if (cachedShots != null) {
      return cachedShots;
    }
    
    // Si no hay caché, consultar a Firestore
    final snapshot = await _firestore
        .collection(_shotsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .get();
    
    final shots = snapshot.docs
        .map((doc) => ShotModel.fromFirestore(doc))
        .toList();
    
    // Guardar en caché
    await _cacheManager.set(cacheKey, shots, duration: _cacheDuration);
    
    return shots;
  } catch (e) {
    FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
        reason: 'Error al obtener tiros por usuario');
    throw Exception('Error al obtener la lista de tiros');
  }
}
  
  @override
  Future<List<ShotModel>> getShotsByMatch(String matchId) async {
    try {
      // Intentar obtener desde caché primero
      final cacheKey = '$_matchShotsCachePrefix$matchId';
      final cachedShots = await _cacheManager.get<List<ShotModel>>(cacheKey);
      
      if (cachedShots != null) {
        return cachedShots;
      }
      
      // Si no hay caché, consultar a Firestore
      final snapshot = await _firestore
          .collection(_shotsCollection)
          .where('matchId', isEqualTo: matchId)
          .orderBy('minute', descending: false)
          .get();
      
      final shots = snapshot.docs
          .map((doc) => ShotModel.fromFirestore(doc))
          .toList();
      
      // Guardar en caché
      await _cacheManager.set(cacheKey, shots, duration: _cacheDuration);
      
      return shots;
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al obtener tiros por partido');
      throw Exception('Error al obtener los tiros del partido');
    }
  }
  
  @override
  Future<ShotModel?> getShotById(String id) async {
    try {
      // No cacheamos tiros individuales para asegurar datos frescos
      final doc = await _firestore
          .collection(_shotsCollection)
          .doc(id)
          .get();
      
      if (!doc.exists) {
        return null;
      }
      
      return ShotModel.fromFirestore(doc);
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al obtener tiro por ID');
      throw Exception('Error al obtener el tiro');
    }
  }
  
  @override
  Future<ShotModel> createShot(ShotModel shot) async {
    try {
      // Verificar si el usuario es premium o no ha alcanzado el límite
      if (!await _canCreateShot(shot.userId)) {
        throw Exception('Has alcanzado el límite diario de tiros para la versión gratuita');
      }
      
      // Crear referencia para el nuevo documento
      final docRef = _firestore.collection(_shotsCollection).doc();
      
      // Preparar datos para guardar
      final data = {
        ...shot.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      // Guardar en Firestore
      await docRef.set(data);
      
      // Obtener el documento recién creado
      final newDoc = await docRef.get();
      
      // Invalidar caché relevante
      await _invalidateUserCache(shot.userId);
      if (shot.matchId != null) {
        await _cacheManager.remove('$_matchShotsCachePrefix${shot.matchId}');
      }
      
      // Retornar modelo con el ID asignado
      return ShotModel.fromFirestore(newDoc);
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al crear tiro');
      
      if (e is Exception) {
        throw e;
      }
      throw Exception('Error al registrar el tiro');
    }
  }
  
  @override
  Future<ShotModel> updateShot(ShotModel shot) async {
    try {
      // Verificar que el ID sea válido
      if (shot.id.isEmpty) {
        throw Exception('ID de tiro inválido');
      }
      
      // Actualizar en Firestore
      await _firestore
          .collection(_shotsCollection)
          .doc(shot.id)
          .update({
        ...shot.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Obtener el documento actualizado
      final updatedDoc = await _firestore
          .collection(_shotsCollection)
          .doc(shot.id)
          .get();
      
      // Invalidar caché relevante
      await _invalidateUserCache(shot.userId);
      if (shot.matchId != null) {
        await _cacheManager.remove('$_matchShotsCachePrefix${shot.matchId}');
      }
      
      return ShotModel.fromFirestore(updatedDoc);
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al actualizar tiro');
      throw Exception('Error al actualizar el tiro');
    }
  }
  
  @override
  Future<void> deleteShot(String id) async {
    try {
      // Obtener el tiro primero para saber qué caché invalidar
      final shot = await getShotById(id);
      
      if (shot != null) {
        await _firestore
            .collection(_shotsCollection)
            .doc(id)
            .delete();
            
        // Invalidar caché relevante
        await _invalidateUserCache(shot.userId);
        if (shot.matchId != null) {
          await _cacheManager.remove('$_matchShotsCachePrefix${shot.matchId}');
        }
      }
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al eliminar tiro');
      throw Exception('Error al eliminar el tiro');
    }
  }
  
  @override
  Future<List<ShotModel>> getShotsByResult(String userId, String result) async {
    try {
      // Esta consulta específica no la cacheamos ya que no es de uso frecuente
      final snapshot = await _firestore
          .collection(_shotsCollection)
          .where('userId', isEqualTo: userId)
          .where('result', isEqualTo: result)
          .orderBy('timestamp', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => ShotModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al obtener tiros por resultado');
      throw Exception('Error al obtener tiros por resultado');
    }
  }
  
  @override
  Future<List<ShotModel>> getShotsByDateRange(
    String userId, 
    DateTime startDate, 
    DateTime endDate
  ) async {
    try {
      // Clave de caché única para este rango de fechas
      final cacheKey = '${_userShotsCachePrefix}${userId}_${startDate.millisecondsSinceEpoch}_${endDate.millisecondsSinceEpoch}';
      final cachedShots = await _cacheManager.get<List<ShotModel>>(cacheKey);
      
      if (cachedShots != null) {
        return cachedShots;
      }
      
      final snapshot = await _firestore
          .collection(_shotsCollection)
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate)
          .orderBy('timestamp', descending: true)
          .get();
      
      final shots = snapshot.docs
          .map((doc) => ShotModel.fromFirestore(doc))
          .toList();
      
      // Cachear por menos tiempo ya que es una consulta específica
      await _cacheManager.set(cacheKey, shots, duration: 60); // 1 minuto
      
      return shots;
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al obtener tiros por rango de fechas');
      throw Exception('Error al obtener tiros por rango de fechas');
    }
  }
  
  @override
  Stream<List<ShotModel>> watchUserShots(String userId) {
    return _firestore
        .collection(_shotsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          final shots = snapshot.docs
              .map((doc) => ShotModel.fromFirestore(doc))
              .toList();
          
          // Actualizar caché cada vez que hay cambios
          _cacheManager.set('$_userShotsCachePrefix$userId', shots, duration: _cacheDuration);
          
          return shots;
        })
        .handleError((e) {
          FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
              reason: 'Error en stream de tiros de usuario');
          // No lanzamos excepción ya que los streams deberían manejar errores internamente
          return <ShotModel>[];
        });
  }
  
  @override
  Stream<List<ShotModel>> watchMatchShots(String matchId) {
    return _firestore
        .collection(_shotsCollection)
        .where('matchId', isEqualTo: matchId)
        .orderBy('minute', descending: false)
        .snapshots()
        .map((snapshot) {
          final shots = snapshot.docs
              .map((doc) => ShotModel.fromFirestore(doc))
              .toList();
          
          // Actualizar caché cada vez que hay cambios
          _cacheManager.set('$_matchShotsCachePrefix$matchId', shots, duration: _cacheDuration);
          
          return shots;
        })
        .handleError((e) {
          FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
              reason: 'Error en stream de tiros de partido');
          return <ShotModel>[];
        });
  }
  
  @override
  Future<Map<String, Map<String, int>>> getGoalZoneStatistics(String userId) async {
    try {
      // Intentar obtener desde caché primero
      final cacheKey = '$_zoneStatsCachePrefix$userId';
      final cachedStats = await _cacheManager.get<Map<String, Map<String, int>>>(cacheKey);
      
      if (cachedStats != null) {
        return cachedStats;
      }
      
      // Si no hay caché, obtener todos los tiros y calcular
      final shots = await getShotsByUser(userId);
      
      // Inicializar el mapa de resultados con las zonas
      final Map<String, Map<String, int>> zoneStats = {
        'top-left': {'total': 0, 'saved': 0, 'goal': 0},
        'top-center': {'total': 0, 'saved': 0, 'goal': 0},
        'top-right': {'total': 0, 'saved': 0, 'goal': 0},
        'middle-left': {'total': 0, 'saved': 0, 'goal': 0},
        'middle-center': {'total': 0, 'saved': 0, 'goal': 0},
        'middle-right': {'total': 0, 'saved': 0, 'goal': 0},
        'bottom-left': {'total': 0, 'saved': 0, 'goal': 0},
        'bottom-center': {'total': 0, 'saved': 0, 'goal': 0},
        'bottom-right': {'total': 0, 'saved': 0, 'goal': 0},
      };
      
      // Analizar cada tiro
      for (final shot in shots) {
        final zone = shot.goalZone;
        
        // Asegurarse de que la zona existe en el mapa
        if (!zoneStats.containsKey(zone)) {
          zoneStats[zone] = {'total': 0, 'saved': 0, 'goal': 0};
        }
        
        // Incrementar contador total
        zoneStats[zone]!['total'] = (zoneStats[zone]!['total'] ?? 0) + 1;
        
        // Incrementar contador específico (gol o atajada)
        if (shot.isGoal) {
          zoneStats[zone]!['goal'] = (zoneStats[zone]!['goal'] ?? 0) + 1;
        } else {
          zoneStats[zone]!['saved'] = (zoneStats[zone]!['saved'] ?? 0) + 1;
        }
      }
      
      // Guardar en caché
      await _cacheManager.set(cacheKey, zoneStats, duration: _cacheDuration);
      
      return zoneStats;
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al obtener estadísticas por zona');
      throw Exception('Error al calcular estadísticas por zona');
    }
  }
  
  @override
  Future<Map<String, int>> countShotsByResult(String userId) async {
    try {
      // Intentar obtener desde caché primero
      final cacheKey = '$_resultCountCachePrefix$userId';
      final cachedCounts = await _cacheManager.get<Map<String, int>>(cacheKey);
      
      if (cachedCounts != null) {
        return cachedCounts;
      }
      
      // Inicializar contadores
      final Map<String, int> counts = {
        'total': 0,
        ShotModel.RESULT_GOAL: 0,
        ShotModel.RESULT_SAVED: 0,
      };
      
      // Consultar tiros del usuario
      final shots = await getShotsByUser(userId);
      
      // Contar resultados
      counts['total'] = shots.length;
      counts[ShotModel.RESULT_GOAL] = shots.where((shot) => shot.isGoal).length;
      counts[ShotModel.RESULT_SAVED] = shots.where((shot) => shot.isSaved).length;
      
      // Guardar en caché
      await _cacheManager.set(cacheKey, counts, duration: _cacheDuration);
      
      return counts;
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al contar tiros por resultado');
      throw Exception('Error al contar tiros por resultado');
    }
  }
  
  // Métodos privados de utilidad
  
  /// Verifica si un usuario puede crear más tiros (límite diario para usuarios gratuitos)
  Future<bool> _canCreateShot(String userId) async {
    try {
      // Obtener usuario actual para verificar si es premium
      final currentUser = await _authRepository.getCurrentUser();
      
      // Si es premium, puede crear tiros sin limitación
      if (currentUser != null && currentUser.subscription.isPremium) {
        return true;
      }
      
      // Si es usuario gratuito, verificar el límite diario
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      
      final todayShots = await getShotsByDateRange(userId, startOfDay, endOfDay);
      
      // Límite de 20 tiros por día para usuarios gratuitos
      return todayShots.length < 20;
    } catch (e) {
      // En caso de error, permitir crear el tiro (enfocar en UX)
      // pero registrar el problema
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al verificar límite de tiros');
      return true;
    }
  }
  
  /// Invalida todas las cachés relacionadas con un usuario
  Future<void> _invalidateUserCache(String userId) async {
    await _cacheManager.remove('$_userShotsCachePrefix$userId');
    await _cacheManager.remove('$_zoneStatsCachePrefix$userId');
    await _cacheManager.remove('$_resultCountCachePrefix$userId');
  }
}