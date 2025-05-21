import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';

/// Servicio para análisis y seguimiento de eventos en la aplicación
///
/// Proporciona métodos para registrar eventos personalizados y estadísticas
/// de uso para mejorar la aplicación basándose en el comportamiento real.
class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Singleton
  static final AnalyticsService _instance = AnalyticsService._internal();

  /// Obtener la instancia única del servicio
  factory AnalyticsService() {
    return _instance;
  }

  AnalyticsService._internal() {
    _initializeAnalytics();
  }

  /// Inicializar y configurar Firebase Analytics
  void _initializeAnalytics() {
    // Desactivar Analytics en modo debug si es necesario
    if (kDebugMode) {
      _analytics.setAnalyticsCollectionEnabled(false);
      debugPrint('Analytics desactivado en modo debug');
      return;
    }

    // Configuración adicional
    _analytics.setAnalyticsCollectionEnabled(true);
  }

  // En AnalyticsService
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    await _analytics.logEvent(
      name: name,
      parameters: parameters,
    );
  }

  /// Registrar inicio de sesión de usuario
  Future<void> logLogin(String method) async {
    await _analytics.logLogin(loginMethod: method);
  }

  /// Registrar cierre de sesión
  Future<void> logLogout() async {
    await _analytics.logEvent(name: 'logout');
  }

  /// Registrar visualización de una pantalla
  Future<void> logScreenView(String screenName, String screenClass) async {
    await _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
    );
  }

  /// Registrar creación de nuevo registro de tiro
  Future<void> logShotRegistered(bool isGoal, String? matchId) async {
    await _analytics.logEvent(
      name: 'shot_registered',
      parameters: {
        'result': isGoal ? 'goal' : 'saved',
        'has_match': matchId != null,
      },
    );
  }

  /// Registrar creación de nuevo registro de saque
  Future<void> logPassRegistered(bool isSuccessful, String? matchId) async {
    await _analytics.logEvent(
      name: 'pass_registered',
      parameters: {
        'result': isSuccessful ? 'successful' : 'failed',
        'has_match': matchId != null,
      },
    );
  }

  /// Registrar creación de nuevo partido
  Future<void> logMatchCreated(String matchType) async {
    await _analytics.logEvent(
      name: 'match_created',
      parameters: {
        'match_type': matchType,
      },
    );
  }

  /// Registrar compra de suscripción
  Future<void> logSubscriptionPurchased(
      String plan, double price, String currency) async {
    await _analytics.logPurchase(
      currency: currency,
      value: price,
      items: [
        AnalyticsEventItem(
          itemName: 'Premium Subscription',
          itemId: plan,
          itemCategory: 'subscription',
        ),
      ],
    );
  }

  /// Registrar visualización de página de suscripción
  Future<void> logSubscriptionViewed() async {
    await _analytics.logViewPromotion(
      promotionName: 'premium_subscription',
      promotionId: 'subscription_page',
    );
  }

  /// Registrar exportación de datos
  Future<void> logDataExported(String exportType) async {
    await _analytics.logEvent(
      name: 'data_exported',
      parameters: {
        'export_type': exportType,
      },
    );
  }

  /// Registrar un error del usuario
  Future<void> logError(String errorType, String message) async {
    await _analytics.logEvent(
      name: 'app_error',
      parameters: {
        'error_type': errorType,
        'error_message': message,
      },
    );
  }

  /// Registrar búsqueda dentro de la aplicación
  Future<void> logSearch(String searchTerm) async {
    await _analytics.logSearch(searchTerm: searchTerm);
  }

  /// Registrar cambio de idioma
  Future<void> logLanguageChanged(String language) async {
    await _analytics.logEvent(
      name: 'language_changed',
      parameters: {
        'language': language,
      },
    );
  }

  /// Registrar cambio de tema
  Future<void> logThemeChanged(bool isDarkMode) async {
    await _analytics.logEvent(
      name: 'theme_changed',
      parameters: {
        'dark_mode': isDarkMode,
      },
    );
  }

  /// Registrar evento de visualización de estadísticas
  Future<void> logStatsViewed(String statType, String timePeriod) async {
    await _analytics.logEvent(
      name: 'stats_viewed',
      parameters: {
        'stat_type': statType,
        'time_period': timePeriod,
      },
    );
  }

  /// Establecer ID de usuario para Analytics
  Future<void> setUserId(String userId) async {
    await _analytics.setUserId(id: userId);
  }

  /// Establecer propiedades del usuario
  Future<void> setUserProperties({
    required String userId,
    required bool isPremium,
    String? subscriptionPlan,
  }) async {
    await _analytics.setUserId(id: userId);
    await _analytics.setUserProperty(
        name: 'is_premium', value: isPremium.toString());

    if (isPremium && subscriptionPlan != null) {
      await _analytics.setUserProperty(
          name: 'subscription_plan', value: subscriptionPlan);
    }
  }

  /// Actualizar propiedades basadas en el modelo de usuario
  Future<void> updateUserFromModel(UserModel user) async {
    await setUserProperties(
      userId: user.id,
      isPremium: user.subscription.isPremium,
      subscriptionPlan: user.subscription.plan,
    );
  }

  /// Limpiar datos de usuario al cerrar sesión
  Future<void> clearUserData() async {
    await _analytics.setUserId(id: null);
  }
}
