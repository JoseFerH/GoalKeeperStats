// lib/services/daily_limits_service.dart
// NUEVO ARCHIVO: Servicio centralizado para gestionar límites diarios

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/services/cache_manager.dart';
import 'package:goalkeeper_stats/services/firebase_crashlytics_service.dart';
import 'package:goalkeeper_stats/core/constants/app_constants.dart';

class DailyLimitsService {
  final FirebaseFirestore _firestore;
  final CacheManager _cacheManager;
  final FirebaseCrashlyticsService _crashlyticsService;

  static const String _dailyCountCachePrefix = 'daily_shots_count_';
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
        return true;
      }

      // Para usuarios gratuitos, verificar límite diario
      final todayCount = await getTodayShotsCount(user.id);
      return todayCount < AppConstants.freeTierDailyShotsLimit;
    } catch (e) {
      _crashlyticsService.recordError(
        e,
        StackTrace.current,
        reason: 'Error verificando límite de tiros para usuario ${user.id}',
      );

      // En caso de error, permitir crear (UX friendly)
      return true;
    }
  }

  /// Obtiene el conteo de tiros de hoy para un usuario
  Future<int> getTodayShotsCount(String userId) async {
    try {
      // Generar clave de caché única para el día actual
      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month}-${today.day}';
      final cacheKey = '$_dailyCountCachePrefix${userId}_$dateKey';

      // Intentar obtener del caché primero
      final cachedCount = await _cacheManager.get<int>(cacheKey);
      if (cachedCount != null) {
        return cachedCount;
      }

      // Si no está en caché, consultar Firestore
      final count = await _queryTodayShotsFromFirestore(userId);

      // Guardar en caché
      await _cacheManager.set(cacheKey, count, duration: _cacheDuration);

      return count;
    } catch (e) {
      _crashlyticsService.recordError(
        e,
        StackTrace.current,
        reason: 'Error obteniendo conteo diario para usuario $userId',
      );

      // En caso de error, retornar 0 (UX friendly)
      return 0;
    }
  }

  /// Consulta directa a Firestore para obtener el conteo de hoy
  Future<int> _queryTodayShotsFromFirestore(String userId) async {
    // Usar UTC para consistencia con Firestore
    final nowUtc = DateTime.now().toUtc();
    final startOfDayUtc = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
    final endOfDayUtc =
        DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day, 23, 59, 59, 999);

    final snapshot = await _firestore
        .collection(AppConstants.shotsCollection)
        .where('userId', isEqualTo: userId)
        .where('timestamp',
            isGreaterThanOrEqualTo: startOfDayUtc.millisecondsSinceEpoch)
        .where('timestamp',
            isLessThanOrEqualTo: endOfDayUtc.millisecondsSinceEpoch)
        .get(const GetOptions(
            source: Source.server)); // Forzar consulta al servidor

    return snapshot.docs.length;
  }

  /// Invalida el caché del contador diario para un usuario
  Future<void> invalidateTodayCache(String userId) async {
    try {
      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month}-${today.day}';
      final cacheKey = '$_dailyCountCachePrefix${userId}_$dateKey';

      await _cacheManager.remove(cacheKey);
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

    final todayCount = await getTodayShotsCount(user.id);
    const dailyLimit = AppConstants.freeTierDailyShotsLimit;

    return DailyLimitInfo(
      isPremium: false,
      dailyLimit: dailyLimit,
      todayCount: todayCount,
      hasReachedLimit: todayCount >= dailyLimit,
      remainingShots: (dailyLimit - todayCount).clamp(0, dailyLimit),
    );
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
      return 'Usuario Premium - Sin límites de tiros';
    }

    if (hasReachedLimit) {
      return 'Has alcanzado el límite de $dailyLimit tiros diarios. Actualiza a Premium para eliminar esta restricción.';
    }

    return 'Tiros registrados hoy: $todayCount de $dailyLimit';
  }
}
