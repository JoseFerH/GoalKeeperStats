// lib/data/repositories/firebase_goalkeeper_passes_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:goalkeeper_stats/domain/repositories/goalkeeper_passes_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/auth_repository.dart';
import 'package:goalkeeper_stats/data/models/goalkeeper_pass_model.dart';
import 'package:goalkeeper_stats/services/cache_manager.dart';

class FirebaseGoalkeeperPassesRepository implements GoalkeeperPassesRepository {
  // Campos finales (no-nulos y nullables)
  final FirebaseFirestore _firestore;
  final AuthRepository _authRepository; // No-nulo
  final CacheManager _cacheManager; // No-nulo
  
  // Colección donde se almacenan los saques
  static const String _passesCollection = 'goalkeeper_passes';
  
  // Claves para caché
  static const String _userPassesCachePrefix = 'user_passes_';
  static const String _matchPassesCachePrefix = 'match_passes_';
  static const String _passDetailCachePrefix = 'pass_detail_';
  static const String _typeStatsCachePrefix = 'pass_type_stats_';
  static const String _resultCountCachePrefix = 'pass_result_count_';
  
  // Duración de caché (en segundos)
  static const int _cacheDuration = 300; // 5 minutos
  
  /// Constructor con posibilidad de inyección para pruebas
  /// Constructor correcto
FirebaseGoalkeeperPassesRepository({
  FirebaseFirestore? firestore,
  required AuthRepository authRepository,
  CacheManager? cacheManager,
}) : 
  _firestore = firestore ?? FirebaseFirestore.instance,
  _authRepository = authRepository,
  _cacheManager = cacheManager ?? CacheManager();

/// Método correcto que usa el parámetro userId
@override
Future<List<GoalkeeperPassModel>> getPassesByUser(String userId) async {
  try {
    // Verificar autenticación
    final currentUser = await _authRepository.getCurrentUser();
    if (currentUser == null) throw Exception('Usuario no autenticado');
    
    // Intentar obtener desde caché primero
    final cacheKey = '$_userPassesCachePrefix$userId';
    final cachedPasses = await _cacheManager.get<List<GoalkeeperPassModel>>(cacheKey);
    
    if (cachedPasses != null) {
      return cachedPasses;
    }
    
    // Si no hay caché, consultar a Firestore - USAR LA COLECCIÓN CORRECTA
    final snapshot = await _firestore
        .collection(_passesCollection)  // Usar la constante correcta
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .get();
    
    final passes = snapshot.docs
        .map((doc) => GoalkeeperPassModel.fromFirestore(doc))
        .toList();
    
    // Guardar en caché
    await _cacheManager.set(cacheKey, passes, duration: _cacheDuration);
    
    return passes;
  } catch (e) {
    FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
        reason: 'Error al obtener saques por usuario');
    throw Exception('Error al obtener la lista de saques');
  }
}
  
  @override
  Future<List<GoalkeeperPassModel>> getPassesByMatch(String matchId) async {
    try {
      // Intentar obtener desde caché primero
      final cacheKey = '$_matchPassesCachePrefix$matchId';
      final cachedPasses = await _cacheManager.get<List<GoalkeeperPassModel>>(cacheKey);
      
      if (cachedPasses != null) {
        return cachedPasses;
      }
      
      // Si no hay caché, consultar a Firestore
      final snapshot = await _firestore
          .collection(_passesCollection)
          .where('matchId', isEqualTo: matchId)
          .orderBy('minute', descending: false)
          .get();
      
      final passes = snapshot.docs
          .map((doc) => GoalkeeperPassModel.fromFirestore(doc))
          .toList();
      
      // Guardar en caché
      await _cacheManager.set(cacheKey, passes, duration: _cacheDuration);
      
      return passes;
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al obtener saques por partido');
      throw Exception('Error al obtener los saques del partido');
    }
  }
  
  @override
  Future<GoalkeeperPassModel?> getPassById(String id) async {
    try {
      // Intentar obtener desde caché primero
      final cacheKey = '$_passDetailCachePrefix$id';
      final cachedPass = await _cacheManager.get<GoalkeeperPassModel>(cacheKey);
      
      if (cachedPass != null) {
        return cachedPass;
      }
      
      // Si no hay caché, consultar a Firestore
      final doc = await _firestore
          .collection(_passesCollection)
          .doc(id)
          .get();
      
      if (!doc.exists) {
        return null;
      }
      
      final pass = GoalkeeperPassModel.fromFirestore(doc);
      
      // Guardar en caché
      await _cacheManager.set(cacheKey, pass, duration: _cacheDuration);
      
      return pass;
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al obtener saque por ID');
      throw Exception('Error al obtener el saque');
    }
  }
  
  @override
  Future<GoalkeeperPassModel> createPass(GoalkeeperPassModel pass) async {
    try {
      // Si tiene matchId, verificar que el usuario tenga acceso premium
      if (pass.matchId != null && !await _verifyPremiumForMatch(pass.userId)) {
        throw Exception('Solo los usuarios premium pueden asociar saques a partidos');
      }
      
      // Crear referencia para el nuevo documento
      final docRef = _firestore.collection(_passesCollection).doc();
      
      // Preparar datos para guardar
      final data = {
        ...pass.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      // Guardar en Firestore
      await docRef.set(data);
      
      // Obtener el documento recién creado
      final newDoc = await docRef.get();
      
      // Invalidar caché relevante
      await _invalidateUserCache(pass.userId);
      if (pass.matchId != null) {
        await _cacheManager.remove('$_matchPassesCachePrefix${pass.matchId}');
      }
      
      // Retornar modelo con el ID asignado
      return GoalkeeperPassModel.fromFirestore(newDoc);
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al crear saque');
      
      if (e is Exception) {
        throw e;
      }
      throw Exception('Error al registrar el saque');
    }
  }
  
  @override
  Future<GoalkeeperPassModel> updatePass(GoalkeeperPassModel pass) async {
    try {
      // Verificar que el ID sea válido
      if (pass.id.isEmpty) {
        throw Exception('ID de saque inválido');
      }
      
      // Obtener el saque actual para verificaciones
      final currentPass = await getPassById(pass.id);
      if (currentPass == null) {
        throw Exception('Saque no encontrado');
      }
      
      // Verificar propiedad del saque
      if (currentPass.userId != pass.userId) {
        throw Exception('No tienes permisos para modificar este saque');
      }
      
      // Si está cambiando matchId o si ya tiene uno, verificar premium
      if ((pass.matchId != null && currentPass.matchId == null) || 
          (pass.matchId != null && pass.matchId != currentPass.matchId)) {
        if (!await _verifyPremiumForMatch(pass.userId)) {
          throw Exception('Solo los usuarios premium pueden asociar saques a partidos');
        }
      }
      
      // Actualizar en Firestore
      await _firestore
          .collection(_passesCollection)
          .doc(pass.id)
          .update({
        ...pass.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Obtener el documento actualizado
      final updatedDoc = await _firestore
          .collection(_passesCollection)
          .doc(pass.id)
          .get();
      
      // Invalidar caché relevante
      await _invalidateUserCache(pass.userId);
      if (currentPass.matchId != null) {
        await _cacheManager.remove('$_matchPassesCachePrefix${currentPass.matchId}');
      }
      if (pass.matchId != null && pass.matchId != currentPass.matchId) {
        await _cacheManager.remove('$_matchPassesCachePrefix${pass.matchId}');
      }
      await _cacheManager.remove('$_passDetailCachePrefix${pass.id}');
      
      return GoalkeeperPassModel.fromFirestore(updatedDoc);
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al actualizar saque');
      
      if (e is Exception) {
        throw e;
      }
      throw Exception('Error al actualizar el saque');
    }
  }
  
  @override
  Future<void> deletePass(String id) async {
    try {
      // Obtener el saque para saber qué caché invalidar
      final pass = await getPassById(id);
      
      if (pass != null) {
        await _firestore
            .collection(_passesCollection)
            .doc(id)
            .delete();
            
        // Invalidar caché relevante
        await _invalidateUserCache(pass.userId);
        if (pass.matchId != null) {
          await _cacheManager.remove('$_matchPassesCachePrefix${pass.matchId}');
        }
        await _cacheManager.remove('$_passDetailCachePrefix$id');
      }
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al eliminar saque');
      throw Exception('Error al eliminar el saque');
    }
  }
  
  @override
  Future<List<GoalkeeperPassModel>> getPassesByType(String userId, String type) async {
    try {
      // Intentar obtener desde caché
      final cacheKey = '${_userPassesCachePrefix}${userId}_type_$type';
      final cachedPasses = await _cacheManager.get<List<GoalkeeperPassModel>>(cacheKey);
      
      if (cachedPasses != null) {
        return cachedPasses;
      }
      
      // Si no hay caché, consultar a Firestore
      final snapshot = await _firestore
          .collection(_passesCollection)
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: type)
          .orderBy('timestamp', descending: true)
          .get();
      
      final passes = snapshot.docs
          .map((doc) => GoalkeeperPassModel.fromFirestore(doc))
          .toList();
      
      // Guardar en caché
      await _cacheManager.set(cacheKey, passes, duration: _cacheDuration);
      
      return passes;
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al obtener saques por tipo');
      throw Exception('Error al obtener saques por tipo');
    }
  }
  
  @override
  Future<List<GoalkeeperPassModel>> getPassesByResult(String userId, String result) async {
    try {
      // Intentar obtener desde caché
      final cacheKey = '${_userPassesCachePrefix}${userId}_result_$result';
      final cachedPasses = await _cacheManager.get<List<GoalkeeperPassModel>>(cacheKey);
      
      if (cachedPasses != null) {
        return cachedPasses;
      }
      
      // Si no hay caché, consultar a Firestore
      final snapshot = await _firestore
          .collection(_passesCollection)
          .where('userId', isEqualTo: userId)
          .where('result', isEqualTo: result)
          .orderBy('timestamp', descending: true)
          .get();
      
      final passes = snapshot.docs
          .map((doc) => GoalkeeperPassModel.fromFirestore(doc))
          .toList();
      
      // Guardar en caché
      await _cacheManager.set(cacheKey, passes, duration: _cacheDuration);
      
      return passes;
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al obtener saques por resultado');
      throw Exception('Error al obtener saques por resultado');
    }
  }
  
  @override
  Future<List<GoalkeeperPassModel>> getPassesByDateRange(
    String userId, 
    DateTime startDate, 
    DateTime endDate
  ) async {
    try {
      // Clave de caché única para este rango de fechas
      final cacheKey = '${_userPassesCachePrefix}${userId}_${startDate.millisecondsSinceEpoch}_${endDate.millisecondsSinceEpoch}';
      final cachedPasses = await _cacheManager.get<List<GoalkeeperPassModel>>(cacheKey);
      
      if (cachedPasses != null) {
        return cachedPasses;
      }
      
      final snapshot = await _firestore
          .collection(_passesCollection)
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate)
          .orderBy('timestamp', descending: true)
          .get();
      
      final passes = snapshot.docs
          .map((doc) => GoalkeeperPassModel.fromFirestore(doc))
          .toList();
      
      // Cachear por menos tiempo ya que es una consulta específica
      await _cacheManager.set(cacheKey, passes, duration: 60); // 1 minuto
      
      return passes;
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al obtener saques por rango de fechas');
      throw Exception('Error al obtener saques por rango de fechas');
    }
  }
  
  @override
  Stream<List<GoalkeeperPassModel>> watchUserPasses(String userId) {
    return _firestore
        .collection(_passesCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          final passes = snapshot.docs
              .map((doc) => GoalkeeperPassModel.fromFirestore(doc))
              .toList();
          
          // Actualizar caché cada vez que hay cambios
          _cacheManager.set('$_userPassesCachePrefix$userId', passes, duration: _cacheDuration);
          
          return passes;
        })
        .handleError((e) {
          FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
              reason: 'Error en stream de saques de usuario');
          return <GoalkeeperPassModel>[];
        });
  }
  
  @override
  Stream<List<GoalkeeperPassModel>> watchMatchPasses(String matchId) {
    return _firestore
        .collection(_passesCollection)
        .where('matchId', isEqualTo: matchId)
        .orderBy('minute', descending: false)
        .snapshots()
        .map((snapshot) {
          final passes = snapshot.docs
              .map((doc) => GoalkeeperPassModel.fromFirestore(doc))
              .toList();
          
          // Actualizar caché cada vez que hay cambios
          _cacheManager.set('$_matchPassesCachePrefix$matchId', passes, duration: _cacheDuration);
          
          return passes;
        })
        .handleError((e) {
          FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
              reason: 'Error en stream de saques de partido');
          return <GoalkeeperPassModel>[];
        });
  }
  
  @override
  Future<Map<String, Map<String, int>>> getPassTypeStatistics(String userId) async {
    try {
      // Intentar obtener desde caché primero
      final cacheKey = '$_typeStatsCachePrefix$userId';
      final cachedStats = await _cacheManager.get<Map<String, Map<String, int>>>(cacheKey);
      
      if (cachedStats != null) {
        return cachedStats;
      }
      
      // Si no hay caché, obtener todos los saques y calcular
      final passes = await getPassesByUser(userId);
      
      // Inicializar el mapa de resultados con los tipos de saque
      final Map<String, Map<String, int>> typeStats = {
        GoalkeeperPassModel.TYPE_HAND: {'total': 0, 'successful': 0, 'failed': 0},
        GoalkeeperPassModel.TYPE_GROUND: {'total': 0, 'successful': 0, 'failed': 0},
        GoalkeeperPassModel.TYPE_VOLLEY: {'total': 0, 'successful': 0, 'failed': 0},
        GoalkeeperPassModel.TYPE_GOAL_KICK: {'total': 0, 'successful': 0, 'failed': 0},
      };
      
      // Analizar cada saque
      for (final pass in passes) {
        final type = pass.type;
        
        // Asegurarse de que el tipo existe en el mapa
        if (!typeStats.containsKey(type)) {
          typeStats[type] = {'total': 0, 'successful': 0, 'failed': 0};
        }
        
        // Incrementar contador total
        typeStats[type]!['total'] = (typeStats[type]!['total'] ?? 0) + 1;
        
        // Incrementar contador específico (exitoso o fallido)
        if (pass.isSuccessful) {
          typeStats[type]!['successful'] = (typeStats[type]!['successful'] ?? 0) + 1;
        } else {
          typeStats[type]!['failed'] = (typeStats[type]!['failed'] ?? 0) + 1;
        }
      }
      
      // Guardar en caché
      await _cacheManager.set(cacheKey, typeStats, duration: _cacheDuration);
      
      return typeStats;
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al obtener estadísticas por tipo de saque');
      throw Exception('Error al calcular estadísticas por tipo de saque');
    }
  }
  
  @override
  Future<Map<String, int>> countPassesByResult(String userId) async {
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
        GoalkeeperPassModel.RESULT_SUCCESSFUL: 0,
        GoalkeeperPassModel.RESULT_FAILED: 0,
      };
      
      // Consultar saques del usuario
      final passes = await getPassesByUser(userId);
      
      // Contar resultados
      counts['total'] = passes.length;
      counts[GoalkeeperPassModel.RESULT_SUCCESSFUL] = 
          passes.where((pass) => pass.isSuccessful).length;
      counts[GoalkeeperPassModel.RESULT_FAILED] = 
          passes.where((pass) => pass.isFailed).length;
      
      // Guardar en caché
      await _cacheManager.set(cacheKey, counts, duration: _cacheDuration);
      
      return counts;
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al contar saques por resultado');
      throw Exception('Error al contar saques por resultado');
    }
  }
  
  // Métodos privados de utilidad
  
  /// Verifica si un usuario es premium para permitir asociación a partidos
  Future<bool> _verifyPremiumForMatch(String userId) async {
    try {
      // Obtener usuario actual para verificar si es premium
      final currentUser = await _authRepository.getCurrentUser();
      
      // Verificar que sea el mismo usuario y que tenga suscripción premium
      if (currentUser != null && 
          currentUser.id == userId && 
          currentUser.subscription.isPremium) {
        return true;
      }
      
      return false;
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al verificar estado premium para asociar saque');
      return false;
    }
  }
  
  /// Invalida todas las cachés relacionadas con los saques de un usuario
  Future<void> _invalidateUserCache(String userId) async {
    // Caché principal de saques del usuario
    await _cacheManager.remove('$_userPassesCachePrefix$userId');
    
    // Estadísticas
    await _cacheManager.remove('$_typeStatsCachePrefix$userId');
    await _cacheManager.remove('$_resultCountCachePrefix$userId');
    
    // Tipos de saques
    for (final type in [
      GoalkeeperPassModel.TYPE_HAND,
      GoalkeeperPassModel.TYPE_GROUND,
      GoalkeeperPassModel.TYPE_VOLLEY,
      GoalkeeperPassModel.TYPE_GOAL_KICK,
    ]) {
      await _cacheManager.remove('${_userPassesCachePrefix}${userId}_type_$type');
    }
    
    // Resultados
    await _cacheManager.remove('${_userPassesCachePrefix}${userId}_result_${GoalkeeperPassModel.RESULT_SUCCESSFUL}');
    await _cacheManager.remove('${_userPassesCachePrefix}${userId}_result_${GoalkeeperPassModel.RESULT_FAILED}');
  }
}