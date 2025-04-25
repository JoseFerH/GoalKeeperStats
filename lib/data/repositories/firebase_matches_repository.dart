// lib/data/repositories/firebase_matches_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:goalkeeper_stats/domain/repositories/matches_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/auth_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/shots_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/goalkeeper_passes_repository.dart';
import 'package:goalkeeper_stats/data/models/match_model.dart';
import 'package:goalkeeper_stats/services/cache_manager.dart';

class FirebaseMatchesRepository implements MatchesRepository {
  // Campos finales (no-nulos y nullables)
  final FirebaseFirestore _firestore;
  final AuthRepository _authRepository; // No-nulo
  final ShotsRepository? _shotsRepository;
  final GoalkeeperPassesRepository? _passesRepository;
  final CacheManager _cacheManager; // No-nulo
  
  // Colección donde se almacenan los partidos
  static const String _matchesCollection = 'matches';
  
  // Claves para caché
  static const String _userMatchesCachePrefix = 'user_matches_';
  static const String _matchDetailCachePrefix = 'match_detail_';
  static const String _matchTypesCachePrefix = 'match_types_';
  static const String _dateRangeCachePrefix = 'date_range_matches_';
  
  // Duración de caché (en segundos)
  static const int _cacheDuration = 600; // 10 minutos
  
  /// Constructor con posibilidad de inyección para pruebas
  // Constructor correcto
FirebaseMatchesRepository({
  FirebaseFirestore? firestore,
  required AuthRepository authRepository,
  ShotsRepository? shotsRepository,
  GoalkeeperPassesRepository? passesRepository,
  CacheManager? cacheManager,
}) : 
  _firestore = firestore ?? FirebaseFirestore.instance,
  _authRepository = authRepository,
  _shotsRepository = shotsRepository,
  _passesRepository = passesRepository,
  _cacheManager = cacheManager ?? CacheManager();

// Método corregido que usa el userId correctamente
@override
Future<List<MatchModel>> getMatchesByUser(String userId) async {
  try {
    // Verificar autenticación
    final currentUser = await _authRepository.getCurrentUser();
    if (currentUser == null) throw Exception('Usuario no autenticado');
    
    // Intentar obtener desde caché primero
    final cacheKey = '$_userMatchesCachePrefix$userId';
    final cachedMatches = await _cacheManager.get<List<MatchModel>>(cacheKey);
    
    if (cachedMatches != null) {
      return cachedMatches;
    }
    
    // Si no hay caché, consultar a Firestore
    final snapshot = await _firestore
        .collection(_matchesCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .get();
    
    final matches = snapshot.docs
        .map((doc) => MatchModel.fromFirestore(doc))
        .toList();
    
    // Guardar en caché
    await _cacheManager.set(cacheKey, matches, duration: _cacheDuration);
    
    return matches;
  } catch (e) {
    FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
        reason: 'Error al obtener partidos por usuario');
    throw Exception('Error al obtener la lista de partidos');
  }
}
  
  @override
  Future<MatchModel?> getMatchById(String id) async {
    try {
      // Intentar obtener desde caché primero
      final cacheKey = '$_matchDetailCachePrefix$id';
      final cachedMatch = await _cacheManager.get<MatchModel>(cacheKey);
      
      if (cachedMatch != null) {
        return cachedMatch;
      }
      
      // Si no hay caché, consultar a Firestore
      final doc = await _firestore
          .collection(_matchesCollection)
          .doc(id)
          .get();
      
      if (!doc.exists) {
        return null;
      }
      
      final match = MatchModel.fromFirestore(doc);
      
      // Guardar en caché
      await _cacheManager.set(cacheKey, match, duration: _cacheDuration);
      
      return match;
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al obtener partido por ID');
      throw Exception('Error al obtener el partido');
    }
  }
  
  @override
  Future<MatchModel> createMatch(MatchModel match) async {
    try {
      // Verificar si el usuario es premium
      if (!await _isPremiumUser(match.userId)) {
        throw Exception('Solo los usuarios premium pueden crear partidos');
      }
      
      // Crear referencia para el nuevo documento
      final docRef = _firestore.collection(_matchesCollection).doc();
      
      // Preparar datos para guardar
      final data = {
        ...match.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      // Guardar en Firestore
      await docRef.set(data);
      
      // Obtener el documento recién creado
      final newDoc = await docRef.get();
      
      // Invalidar caché de partidos del usuario
      await _cacheManager.remove('$_userMatchesCachePrefix${match.userId}');
      
      // Retornar modelo con el ID asignado
      return MatchModel.fromFirestore(newDoc);
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al crear partido');
      
      if (e is Exception) {
        throw e;
      }
      throw Exception('Error al crear el partido');
    }
  }
  
  @override
  Future<MatchModel> updateMatch(MatchModel match) async {
    try {
      // Verificar que el ID sea válido
      if (match.id.isEmpty) {
        throw Exception('ID de partido inválido');
      }
      
      // Verificar que el usuario es premium
      if (!await _isPremiumUser(match.userId)) {
        throw Exception('Solo los usuarios premium pueden actualizar partidos');
      }
      
      // Verificar que el partido pertenece al usuario
      final existingMatch = await getMatchById(match.id);
      if (existingMatch == null || existingMatch.userId != match.userId) {
        throw Exception('No tienes permisos para actualizar este partido');
      }
      
      // Actualizar en Firestore
      await _firestore
          .collection(_matchesCollection)
          .doc(match.id)
          .update({
        ...match.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Obtener el documento actualizado
      final updatedDoc = await _firestore
          .collection(_matchesCollection)
          .doc(match.id)
          .get();
      
      // Invalidar cachés relacionadas
      await _invalidateMatchCache(match.id, match.userId);
      
      return MatchModel.fromFirestore(updatedDoc);
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al actualizar partido');
      
      if (e is Exception) {
        throw e;
      }
      throw Exception('Error al actualizar el partido');
    }
  }
  
  @override
  Future<void> deleteMatch(String id) async {
    try {
      // Obtener el partido para verificar permisos y conocer el userId
      final match = await getMatchById(id);
      
      if (match == null) {
        throw Exception('Partido no encontrado');
      }
      
      // Verificar que el usuario es premium
      if (!await _isPremiumUser(match.userId)) {
        throw Exception('Solo los usuarios premium pueden eliminar partidos');
      }
      
      // Iniciar transacción para borrado
      await _firestore.runTransaction((transaction) async {
        // Eliminar el partido
        transaction.delete(
          _firestore.collection(_matchesCollection).doc(id)
        );
        
        // Si están disponibles los repositorios, buscar tiros y saques asociados
        // para eliminarlos en cascada (usando batch para eficiencia)
        if (_shotsRepository != null || _passesRepository != null) {
          // Nota: Esto se ejecutará fuera de la transacción porque
          // las transacciones tienen limitaciones en Firestore
          _deleteDependentResources(id, match.userId);
        }
      });
      
      // Invalidar cachés relacionadas
      await _invalidateMatchCache(id, match.userId);
      
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al eliminar partido');
      
      if (e is Exception) {
        throw e;
      }
      throw Exception('Error al eliminar el partido');
    }
  }
  
  @override
  Future<List<MatchModel>> getMatchesByType(String userId, String type) async {
    try {
      // Intentar obtener desde caché primero
      final cacheKey = '$_matchTypesCachePrefix${userId}_$type';
      final cachedMatches = await _cacheManager.get<List<MatchModel>>(cacheKey);
      
      if (cachedMatches != null) {
        return cachedMatches;
      }
      
      // Si no hay caché, consultar a Firestore
      final snapshot = await _firestore
          .collection(_matchesCollection)
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: type)
          .orderBy('date', descending: true)
          .get();
      
      final matches = snapshot.docs
          .map((doc) => MatchModel.fromFirestore(doc))
          .toList();
      
      // Guardar en caché
      await _cacheManager.set(cacheKey, matches, duration: _cacheDuration);
      
      return matches;
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al obtener partidos por tipo');
      throw Exception('Error al obtener partidos por tipo');
    }
  }
  
  @override
  Future<List<MatchModel>> getMatchesByDateRange(
    String userId, 
    DateTime startDate, 
    DateTime endDate
  ) async {
    try {
      // Clave de caché única para este rango de fechas
      final cacheKey = '$_dateRangeCachePrefix${userId}_${startDate.millisecondsSinceEpoch}_${endDate.millisecondsSinceEpoch}';
      final cachedMatches = await _cacheManager.get<List<MatchModel>>(cacheKey);
      
      if (cachedMatches != null) {
        return cachedMatches;
      }
      
      final snapshot = await _firestore
          .collection(_matchesCollection)
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate)
          .orderBy('date', descending: true)
          .get();
      
      final matches = snapshot.docs
          .map((doc) => MatchModel.fromFirestore(doc))
          .toList();
      
      // Cachear por menos tiempo ya que es una consulta específica
      await _cacheManager.set(cacheKey, matches, duration: 300); // 5 minutos
      
      return matches;
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al obtener partidos por rango de fechas');
      throw Exception('Error al obtener partidos por rango de fechas');
    }
  }
  
  @override
  Stream<List<MatchModel>> watchUserMatches(String userId) {
    return _firestore
        .collection(_matchesCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          final matches = snapshot.docs
              .map((doc) => MatchModel.fromFirestore(doc))
              .toList();
          
          // Actualizar caché cada vez que hay cambios
          _cacheManager.set('$_userMatchesCachePrefix$userId', matches, duration: _cacheDuration);
          
          return matches;
        })
        .handleError((e) {
          FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
              reason: 'Error en stream de partidos de usuario');
          return <MatchModel>[];
        });
  }
  
  @override
  Future<List<MatchModel>> searchMatches(String userId, String query) async {
    try {
      // No cacheamos búsquedas para asegurar resultados actualizados
      final lowercaseQuery = query.toLowerCase();
      
      // Obtener todos los partidos del usuario primero
      final matches = await getMatchesByUser(userId);
      
      // Filtrar en el cliente (Firestore no soporta búsqueda de texto directamente)
      return matches.where((match) {
        // Buscar en varios campos
        final opponent = match.opponent?.toLowerCase() ?? '';
        final venue = match.venue?.toLowerCase() ?? '';
        final notes = match.notes?.toLowerCase() ?? '';
        
        return opponent.contains(lowercaseQuery) ||
               venue.contains(lowercaseQuery) ||
               notes.contains(lowercaseQuery);
      }).toList();
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al buscar partidos');
      throw Exception('Error al buscar partidos');
    }
  }
  
  // Métodos privados de utilidad
  
  /// Verifica si un usuario es premium para permitir operaciones en partidos
  Future<bool> _isPremiumUser(String userId) async {
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
          reason: 'Error al verificar estado premium');
      return false;
    }
  }
  
  /// Invalida todas las cachés relacionadas con un partido
  Future<void> _invalidateMatchCache(String matchId, String userId) async {
    await _cacheManager.remove('$_matchDetailCachePrefix$matchId');
    await _cacheManager.remove('$_userMatchesCachePrefix$userId');
    
    // Invalidar cachés de tipos (no sabemos qué tipo era el partido)
    for (final type in [
      MatchModel.TYPE_OFFICIAL,
      MatchModel.TYPE_FRIENDLY,
      MatchModel.TYPE_TRAINING
    ]) {
      await _cacheManager.remove('$_matchTypesCachePrefix${userId}_$type');
    }
  }
  
  /// Elimina recursos dependientes de un partido (tiros y saques)
  Future<void> _deleteDependentResources(String matchId, String userId) async {
    try {
      // Eliminar tiros asociados al partido
      if (_shotsRepository != null) {
        final shots = await _firestore
            .collection('shots')
            .where('matchId', isEqualTo: matchId)
            .get();
            
        final batch = _firestore.batch();
        for (final shot in shots.docs) {
          batch.delete(shot.reference);
        }
        
        if (shots.docs.isNotEmpty) {
          await batch.commit();
        }
      }
      
      // Eliminar saques asociados al partido
      if (_passesRepository != null) {
        final passes = await _firestore
            .collection('goalkeeper_passes')
            .where('matchId', isEqualTo: matchId)
            .get();
            
        final batch = _firestore.batch();
        for (final pass in passes.docs) {
          batch.delete(pass.reference);
        }
        
        if (passes.docs.isNotEmpty) {
          await batch.commit();
        }
      }
    } catch (e) {
      // Registrar error pero no fallar la operación principal
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al eliminar recursos dependientes de partido');
    }
  }
}