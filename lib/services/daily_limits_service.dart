// lib/services/daily_limits_service.dart
// SOLUCIÓN FINAL: Servicio centralizado corregido con la lógica correcta

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/services/cache_manager.dart';
import 'package:goalkeeper_stats/services/firebase_crashlytics_service.dart';
import 'package:goalkeeper_stats/core/constants/app_constants.dart';
import 'package:flutter/foundation.dart';

class DailyLimitsService {
  final FirebaseFirestore _firestore;
  final CacheManager _cacheManager;
  final FirebaseCrashlyticsService _crashlyticsService;

  static const String _dailyCountCachePrefix = 'daily_shots_count_';
  static const String _dailyPassesCountCachePrefix = 'daily_passes_count_';
  static const int _cacheDuration = 300; // 5 minutos

  DailyLimitsService({
    FirebaseFirestore? firestore,
    CacheManager? cacheManager,
    FirebaseCrashlyticsService? crashlyticsService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _cacheManager = cacheManager ?? CacheManager(),
        _crashlyticsService =
            crashlyticsService ?? FirebaseCrashlyticsService();

  /// Verifica si un usuario puede crear un nuevo tiro
  Future<bool> canCreateShot(UserModel user) async {
    try {
      // Si es premium, siempre puede crear tiros
      if (user.subscription.isPremium) {
        debugPrint('✅ Usuario premium - sin límites de tiros');
        return true;
      }

      // Para usuarios gratuitos, verificar límite diario TOTAL (tiros + saques)
      final limitInfo = await getLimitInfo(user);
      final canCreate = !limitInfo.hasReachedLimit;

      debugPrint('🔍 Verificando límite de tiros:');
      debugPrint('   Usuario: ${user.id}');
      debugPrint('   Total registros hoy: ${limitInfo.todayCount}');
      debugPrint('   Límite: ${limitInfo.dailyLimit}');
      debugPrint('   Puede crear: $canCreate');

      return canCreate;
    } catch (e) {
      _crashlyticsService.recordError(
        e,
        StackTrace.current,
        reason: 'Error verificando límite de tiros para usuario ${user.id}',
      );

      debugPrint('❌ Error verificando límite: $e');
      // En caso de error, permitir crear (UX friendly)
      return true;
    }
  }

  /// Verifica si un usuario puede crear un nuevo saque
  Future<bool> canCreatePass(UserModel user) async {
    try {
      // Si es premium, siempre puede crear saques
      if (user.subscription.isPremium) {
        debugPrint('✅ Usuario premium - sin límites de saques');
        return true;
      }

      // Para usuarios gratuitos, verificar límite diario TOTAL (tiros + saques)
      final limitInfo = await getLimitInfo(user);
      final canCreate = !limitInfo.hasReachedLimit;

      debugPrint('🔍 Verificando límite de saques:');
      debugPrint('   Usuario: ${user.id}');
      debugPrint('   Total registros hoy: ${limitInfo.todayCount}');
      debugPrint('   Límite: ${limitInfo.dailyLimit}');
      debugPrint('   Puede crear: $canCreate');

      return canCreate;
    } catch (e) {
      _crashlyticsService.recordError(
        e,
        StackTrace.current,
        reason: 'Error verificando límite de saques para usuario ${user.id}',
      );

      debugPrint('❌ Error verificando límite de saques: $e');
      return true;
    }
  }

  /// Obtiene el conteo de tiros de hoy para un usuario
  Future<int> getTodayShotsCount(String userId) async {
    try {
      // Generar clave de caché única para el día actual
      final today = DateTime.now();
      final dateKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final cacheKey = '$_dailyCountCachePrefix${userId}_$dateKey';

      debugPrint('🔍 Buscando tiros del día:');
      debugPrint('   Cache key: $cacheKey');
      debugPrint('   Fecha: $dateKey');

      // Intentar obtener del caché primero
      final cachedCount = await _cacheManager.get<int>(cacheKey);
      if (cachedCount != null) {
        debugPrint('✅ Encontrado en caché: $cachedCount tiros');
        return cachedCount;
      }

      debugPrint('⚠️ No encontrado en caché, consultando Firestore...');

      // Si no está en caché, consultar Firestore
      final count = await _queryTodayShotsFromFirestore(userId);

      debugPrint('📊 Resultado de Firestore: $count tiros');

      // Guardar en caché
      await _cacheManager.set(cacheKey, count, duration: _cacheDuration);
      debugPrint('💾 Guardado en caché por $_cacheDuration segundos');

      return count;
    } catch (e) {
      _crashlyticsService.recordError(
        e,
        StackTrace.current,
        reason: 'Error obteniendo conteo diario de tiros para usuario $userId',
      );

      debugPrint('❌ Error obteniendo conteo diario: $e');
      // En caso de error, retornar 0 (UX friendly)
      return 0;
    }
  }

  /// Obtiene el conteo de saques de hoy para un usuario
  Future<int> getTodayPassesCount(String userId) async {
    try {
      // Generar clave de caché única para el día actual
      final today = DateTime.now();
      final dateKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final cacheKey = '$_dailyPassesCountCachePrefix${userId}_$dateKey';

      debugPrint('🔍 Buscando saques del día:');
      debugPrint('   Cache key: $cacheKey');
      debugPrint('   Fecha: $dateKey');

      // Intentar obtener del caché primero
      final cachedCount = await _cacheManager.get<int>(cacheKey);
      if (cachedCount != null) {
        debugPrint('✅ Encontrado en caché: $cachedCount saques');
        return cachedCount;
      }

      debugPrint('⚠️ No encontrado en caché, consultando Firestore...');

      // Si no está en caché, consultar Firestore
      final count = await _queryTodayPassesFromFirestore(userId);

      debugPrint('📊 Resultado de Firestore: $count saques');

      // Guardar en caché
      await _cacheManager.set(cacheKey, count, duration: _cacheDuration);
      debugPrint('💾 Guardado en caché por $_cacheDuration segundos');

      return count;
    } catch (e) {
      _crashlyticsService.recordError(
        e,
        StackTrace.current,
        reason: 'Error obteniendo conteo diario de saques para usuario $userId',
      );

      debugPrint('❌ Error obteniendo conteo diario de saques: $e');
      return 0;
    }
  }

  /// CORREGIDO: Consulta directa a Firestore para obtener el conteo de tiros de hoy
  Future<int> _queryTodayShotsFromFirestore(String userId) async {
    try {
      // CORRECCIÓN PRINCIPAL: Usar timezone local y format correcto
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

      // Convertir a milliseconds since epoch (como almacenan los modelos)
      final startMs = startOfDay.millisecondsSinceEpoch;
      final endMs = endOfDay.millisecondsSinceEpoch;

      debugPrint('🔍 Consultando Firestore para tiros:');
      debugPrint('   Usuario: $userId');
      debugPrint('   Inicio del día: $startOfDay ($startMs ms)');
      debugPrint('   Fin del día: $endOfDay ($endMs ms)');
      debugPrint('   Colección: ${AppConstants.shotsCollection}');

      // CORRECCIÓN: Solo usar millisecondsSinceEpoch ya que es el formato del modelo
      final snapshot = await _firestore
          .collection(AppConstants.shotsCollection)
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: startMs)
          .where('timestamp', isLessThanOrEqualTo: endMs)
          .get(const GetOptions(source: Source.server));

      final count = snapshot.docs.length;
      debugPrint('📊 Tiros encontrados: $count documentos');

      // Debug: mostrar algunos documentos encontrados
      if (snapshot.docs.isNotEmpty && kDebugMode) {
        debugPrint('📋 Documentos de tiros encontrados:');
        for (int i = 0; i < snapshot.docs.length && i < 5; i++) {
          final doc = snapshot.docs[i];
          final data = doc.data();
          final timestamp = data['timestamp'];
          final dateTime = timestamp is int
              ? DateTime.fromMillisecondsSinceEpoch(timestamp)
              : DateTime.now();

          debugPrint('   Tiro ${i + 1}: ${doc.id}');
          debugPrint('     timestamp: $timestamp (${timestamp.runtimeType})');
          debugPrint('     fecha: $dateTime');
          debugPrint('     resultado: ${data['result']}');
        }
      }

      return count;
    } catch (e) {
      debugPrint('❌ Error en consulta Firestore para tiros: $e');
      _crashlyticsService.recordError(
        e,
        StackTrace.current,
        reason: 'Error en consulta directa de tiros a Firestore',
      );
      return 0;
    }
  }

  /// CORREGIDO: Consulta directa a Firestore para obtener el conteo de saques de hoy
  Future<int> _queryTodayPassesFromFirestore(String userId) async {
    try {
      // CORRECCIÓN PRINCIPAL: Usar timezone local y format correcto
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

      // Convertir a milliseconds since epoch (como almacenan los modelos)
      final startMs = startOfDay.millisecondsSinceEpoch;
      final endMs = endOfDay.millisecondsSinceEpoch;

      debugPrint('🔍 Consultando Firestore para saques:');
      debugPrint('   Usuario: $userId');
      debugPrint('   Inicio del día: $startOfDay ($startMs ms)');
      debugPrint('   Fin del día: $endOfDay ($endMs ms)');
      debugPrint('   Colección: ${AppConstants.passesCollection}');

      // CORRECCIÓN: Solo usar millisecondsSinceEpoch ya que es el formato del modelo
      final snapshot = await _firestore
          .collection(AppConstants.passesCollection)
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: startMs)
          .where('timestamp', isLessThanOrEqualTo: endMs)
          .get(const GetOptions(source: Source.server));

      final count = snapshot.docs.length;
      debugPrint('📊 Saques encontrados: $count documentos');

      // Debug: mostrar algunos documentos encontrados
      if (snapshot.docs.isNotEmpty && kDebugMode) {
        debugPrint('📋 Documentos de saques encontrados:');
        for (int i = 0; i < snapshot.docs.length && i < 5; i++) {
          final doc = snapshot.docs[i];
          final data = doc.data();
          final timestamp = data['timestamp'];
          final dateTime = timestamp is int
              ? DateTime.fromMillisecondsSinceEpoch(timestamp)
              : DateTime.now();

          debugPrint('   Saque ${i + 1}: ${doc.id}');
          debugPrint('     timestamp: $timestamp (${timestamp.runtimeType})');
          debugPrint('     fecha: $dateTime');
          debugPrint('     resultado: ${data['result']}');
        }
      }

      return count;
    } catch (e) {
      debugPrint('❌ Error en consulta Firestore para saques: $e');
      _crashlyticsService.recordError(
        e,
        StackTrace.current,
        reason: 'Error en consulta directa de saques a Firestore',
      );
      return 0;
    }
  }

  /// Invalida el caché del contador diario para un usuario
  Future<void> invalidateTodayCache(String userId) async {
    try {
      final today = DateTime.now();
      final dateKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Invalidar caché de tiros
      final shotsCacheKey = '$_dailyCountCachePrefix${userId}_$dateKey';
      await _cacheManager.remove(shotsCacheKey);

      // Invalidar caché de saques
      final passesCacheKey = '$_dailyPassesCountCachePrefix${userId}_$dateKey';
      await _cacheManager.remove(passesCacheKey);

      debugPrint('🗑️ Caché invalidado para usuario $userId en fecha $dateKey');
      debugPrint('   Claves eliminadas:');
      debugPrint('     - $shotsCacheKey');
      debugPrint('     - $passesCacheKey');
    } catch (e) {
      _crashlyticsService.recordError(
        e,
        StackTrace.current,
        reason: 'Error invalidando caché para usuario $userId',
      );
    }
  }

  /// Obtiene información detallada sobre el límite del usuario
  Future<DailyLimitInfo> getLimitInfo(UserModel user) async {
    if (user.subscription.isPremium) {
      return DailyLimitInfo(
        isPremium: true,
        dailyLimit: -1, // Sin límite
        todayCount: 0,
        hasReachedLimit: false,
        remainingShots: -1, // Sin límite
      );
    }

    // Para usuarios gratuitos, contar tiros y saques juntos
    final todayShotsCount = await getTodayShotsCount(user.id);
    final todayPassesCount = await getTodayPassesCount(user.id);
    final totalTodayCount = todayShotsCount + todayPassesCount;

    const dailyLimit = AppConstants.freeTierDailyShotsLimit;

    debugPrint('📊 Información de límites:');
    debugPrint('   Usuario: ${user.id}');
    debugPrint('   Es Premium: ${user.subscription.isPremium}');
    debugPrint('   Tiros hoy: $todayShotsCount');
    debugPrint('   Saques hoy: $todayPassesCount');
    debugPrint('   Total hoy: $totalTodayCount');
    debugPrint('   Límite: $dailyLimit');
    debugPrint('   Límite alcanzado: ${totalTodayCount >= dailyLimit}');

    return DailyLimitInfo(
      isPremium: false,
      dailyLimit: dailyLimit,
      todayCount: totalTodayCount,
      hasReachedLimit: totalTodayCount >= dailyLimit,
      remainingShots: (dailyLimit - totalTodayCount).clamp(0, dailyLimit),
    );
  }

  /// MEJORADO: Método de debug para verificar datos en Firestore
  Future<Map<String, dynamic>> debugFirestoreData(String userId) async {
    try {
      debugPrint(
          '🔍 INICIANDO DEBUG COMPLETO DE FIRESTORE PARA USUARIO: $userId');

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      final startMs = startOfDay.millisecondsSinceEpoch;
      final endMs = endOfDay.millisecondsSinceEpoch;

      debugPrint('📅 Fechas de consulta:');
      debugPrint('   Hoy: $now');
      debugPrint('   Inicio día: $startOfDay ($startMs ms)');
      debugPrint('   Fin día: $endOfDay ($endMs ms)');

      // Obtener TODOS los documentos del usuario (sin filtro de fecha)
      final allShotsSnapshot = await _firestore
          .collection(AppConstants.shotsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      final allPassesSnapshot = await _firestore
          .collection(AppConstants.passesCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      debugPrint('📊 Documentos totales encontrados:');
      debugPrint('   Tiros: ${allShotsSnapshot.docs.length}');
      debugPrint('   Saques: ${allPassesSnapshot.docs.length}');

      // Analizar tiros de hoy
      int shotsToday = 0;
      List<Map<String, dynamic>> shotsData = [];

      for (var doc in allShotsSnapshot.docs) {
        final data = doc.data();
        final timestamp = data['timestamp'];
        DateTime? dateTime;
        bool isToday = false;

        if (timestamp is int) {
          dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
          isToday = timestamp >= startMs && timestamp <= endMs;
          if (isToday) shotsToday++;
        }

        shotsData.add({
          'id': doc.id,
          'timestamp': timestamp,
          'timestamp_type': timestamp.runtimeType.toString(),
          'parsed_date': dateTime?.toString(),
          'is_today': isToday,
          'result': data['result'],
        });
      }

      // Analizar saques de hoy
      int passesToday = 0;
      List<Map<String, dynamic>> passesData = [];

      for (var doc in allPassesSnapshot.docs) {
        final data = doc.data();
        final timestamp = data['timestamp'];
        DateTime? dateTime;
        bool isToday = false;

        if (timestamp is int) {
          dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
          isToday = timestamp >= startMs && timestamp <= endMs;
          if (isToday) passesToday++;
        }

        passesData.add({
          'id': doc.id,
          'timestamp': timestamp,
          'timestamp_type': timestamp.runtimeType.toString(),
          'parsed_date': dateTime?.toString(),
          'is_today': isToday,
          'result': data['result'],
        });
      }

      final debugInfo = {
        'user_id': userId,
        'current_date': now.toString(),
        'start_of_day': startOfDay.toString(),
        'end_of_day': endOfDay.toString(),
        'start_ms': startMs,
        'end_ms': endMs,
        'collections': {
          'shots': AppConstants.shotsCollection,
          'passes': AppConstants.passesCollection,
        },
        'totals': {
          'total_shots': allShotsSnapshot.docs.length,
          'total_passes': allPassesSnapshot.docs.length,
          'shots_today': shotsToday,
          'passes_today': passesToday,
          'total_today': shotsToday + passesToday,
        },
        'limit_info': {
          'daily_limit': AppConstants.freeTierDailyShotsLimit,
          'remaining': (AppConstants.freeTierDailyShotsLimit -
                  (shotsToday + passesToday))
              .clamp(0, AppConstants.freeTierDailyShotsLimit),
          'has_reached_limit': (shotsToday + passesToday) >=
              AppConstants.freeTierDailyShotsLimit,
        },
        'shots_data': shotsData,
        'passes_data': passesData,
      };

      // debugPrint('📋 RESUMEN DEBUG:');
      // debugPrint('   Total tiros: ${debugInfo['totals']['total_shots']}');
      // debugPrint('   Total saques: ${debugInfo['totals']['total_passes']}');
      // debugPrint('   Tiros hoy: ${debugInfo['totals']['shots_today']}');
      // debugPrint('   Saques hoy: ${debugInfo['totals']['passes_today']}');
      // debugPrint('   TOTAL HOY: ${debugInfo['totals']['total_today']}');
      // debugPrint('   Límite: ${debugInfo['limit_info']['daily_limit']}');
      // debugPrint('   Límite alcanzado: ${debugInfo['limit_info']['has_reached_limit']}');

      return debugInfo;
    } catch (e) {
      debugPrint('❌ Error en debug de Firestore: $e');
      return {'error': e.toString()};
    }
  }
}

/// Información sobre los límites diarios del usuario
class DailyLimitInfo {
  final bool isPremium;
  final int dailyLimit;
  final int todayCount;
  final bool hasReachedLimit;
  final int remainingShots;

  const DailyLimitInfo({
    required this.isPremium,
    required this.dailyLimit,
    required this.todayCount,
    required this.hasReachedLimit,
    required this.remainingShots,
  });

  String get displayMessage {
    if (isPremium) {
      return 'Usuario Premium - Sin límites de registros';
    }

    if (hasReachedLimit) {
      return 'Has alcanzado el límite de $dailyLimit registros diarios (tiros + saques). Actualiza a Premium para eliminar esta restricción.';
    }

    return 'Registros hoy: $todayCount de $dailyLimit (tiros + saques)';
  }

  @override
  String toString() {
    return 'DailyLimitInfo(isPremium: $isPremium, dailyLimit: $dailyLimit, '
        'todayCount: $todayCount, hasReachedLimit: $hasReachedLimit, '
        'remainingShots: $remainingShots)';
  }
}
