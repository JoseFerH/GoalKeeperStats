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

  /// 🔧 MÉTODO AUXILIAR: Convertir valores boolean a string para Firebase Analytics
  Map<String, Object>? _sanitizeParameters(Map<String, Object>? parameters) {
    if (parameters == null) return null;

    final sanitized = <String, Object>{};

    for (final entry in parameters.entries) {
      final key = entry.key;
      final value = entry.value;

      // 🔧 CORRECCIÓN: Convertir boolean a string
      if (value is bool) {
        sanitized[key] = value.toString();
      } else if (value is String || value is num) {
        sanitized[key] = value;
      } else {
        // Para otros tipos, convertir a string
        sanitized[key] = value.toString();
      }
    }

    return sanitized;
  }

  /// 🔧 CORREGIDO: Método logEvent con sanitización de parámetros
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      final sanitizedParams = _sanitizeParameters(parameters);
      await _analytics.logEvent(
        name: name,
        parameters: sanitizedParams,
      );
    } catch (e) {
      debugPrint('❌ Error en logEvent: $e');
      debugPrint('Event: $name, Parameters: $parameters');
    }
  }

  /// Registrar inicio de sesión de usuario
  Future<void> logLogin(String method) async {
    try {
      await _analytics.logLogin(loginMethod: method);
    } catch (e) {
      debugPrint('❌ Error en logLogin: $e');
    }
  }

  /// Registrar cierre de sesión
  Future<void> logLogout() async {
    try {
      await _analytics.logEvent(name: 'logout');
    } catch (e) {
      debugPrint('❌ Error en logLogout: $e');
    }
  }

  /// Registrar visualización de una pantalla
  Future<void> logScreenView(String screenName, String screenClass) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
    } catch (e) {
      debugPrint('❌ Error en logScreenView: $e');
    }
  }

  /// 🔧 CORREGIDO: Registrar creación de nuevo registro de tiro
  Future<void> logShotRegistered(bool isGoal, String? matchId) async {
    try {
      await logEvent(
        name: 'shot_registered',
        parameters: {
          'result': isGoal ? 'goal' : 'saved',
          'has_match': (matchId != null).toString(), // 🔧 Convertir a string
        },
      );
    } catch (e) {
      debugPrint('❌ Error en logShotRegistered: $e');
    }
  }

  /// 🔧 CORREGIDO: Registrar creación de nuevo registro de saque
  Future<void> logPassRegistered(bool isSuccessful, String? matchId) async {
    try {
      await logEvent(
        name: 'pass_registered',
        parameters: {
          'result': isSuccessful ? 'successful' : 'failed',
          'has_match': (matchId != null).toString(), // 🔧 Convertir a string
        },
      );
    } catch (e) {
      debugPrint('❌ Error en logPassRegistered: $e');
    }
  }

  /// Registrar creación de nuevo partido
  Future<void> logMatchCreated(String matchType) async {
    try {
      await logEvent(
        name: 'match_created',
        parameters: {
          'match_type': matchType,
        },
      );
    } catch (e) {
      debugPrint('❌ Error en logMatchCreated: $e');
    }
  }

  /// Registrar compra de suscripción
  Future<void> logSubscriptionPurchased(
      String plan, double price, String currency) async {
    try {
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
    } catch (e) {
      debugPrint('❌ Error en logSubscriptionPurchased: $e');
    }
  }

  /// Registrar visualización de página de suscripción
  Future<void> logSubscriptionViewed() async {
    try {
      await _analytics.logViewPromotion(
        promotionName: 'premium_subscription',
        promotionId: 'subscription_page',
      );
    } catch (e) {
      debugPrint('❌ Error en logSubscriptionViewed: $e');
    }
  }

  /// Registrar exportación de datos
  Future<void> logDataExported(String exportType) async {
    try {
      await logEvent(
        name: 'data_exported',
        parameters: {
          'export_type': exportType,
        },
      );
    } catch (e) {
      debugPrint('❌ Error en logDataExported: $e');
    }
  }

  /// Registrar un error del usuario
  Future<void> logError(String errorType, String message) async {
    try {
      await logEvent(
        name: 'app_error',
        parameters: {
          'error_type': errorType,
          'error_message': message,
        },
      );
    } catch (e) {
      debugPrint('❌ Error en logError: $e');
    }
  }

  /// Registrar búsqueda dentro de la aplicación
  Future<void> logSearch(String searchTerm) async {
    try {
      await _analytics.logSearch(searchTerm: searchTerm);
    } catch (e) {
      debugPrint('❌ Error en logSearch: $e');
    }
  }

  /// 🔧 CORREGIDO: Registrar cambio de idioma
  Future<void> logLanguageChanged(String language) async {
    try {
      await logEvent(
        name: 'language_changed',
        parameters: {
          'language': language,
        },
      );
    } catch (e) {
      debugPrint('❌ Error en logLanguageChanged: $e');
    }
  }

  /// 🔧 CORREGIDO: Registrar cambio de tema
  Future<void> logThemeChanged(bool isDarkMode) async {
    try {
      await logEvent(
        name: 'theme_changed',
        parameters: {
          'dark_mode': isDarkMode.toString(), // 🔧 Convertir a string
        },
      );
    } catch (e) {
      debugPrint('❌ Error en logThemeChanged: $e');
    }
  }

  /// Registrar evento de visualización de estadísticas
  Future<void> logStatsViewed(String statType, String timePeriod) async {
    try {
      await logEvent(
        name: 'stats_viewed',
        parameters: {
          'stat_type': statType,
          'time_period': timePeriod,
        },
      );
    } catch (e) {
      debugPrint('❌ Error en logStatsViewed: $e');
    }
  }

  /// 🔧 NUEVO: Registrar evento de conectividad
  Future<void> logConnectivityChanged(bool isOnline) async {
    try {
      await logEvent(
        name: 'connectivity_changed',
        parameters: {
          'online_mode':
              isOnline.toString(), // 🔧 Usar string en lugar de boolean
        },
      );
    } catch (e) {
      debugPrint('❌ Error en logConnectivityChanged: $e');
    }
  }

  /// Establecer ID de usuario para Analytics
  Future<void> setUserId(String userId) async {
    try {
      await _analytics.setUserId(id: userId);
    } catch (e) {
      debugPrint('❌ Error en setUserId: $e');
    }
  }

  /// 🔧 CORREGIDO: Establecer propiedades del usuario
  Future<void> setUserProperties({
    required String userId,
    required bool isPremium,
    String? subscriptionPlan,
  }) async {
    try {
      await _analytics.setUserId(id: userId);
      await _analytics.setUserProperty(
          name: 'is_premium',
          value: isPremium.toString()); // 🔧 Convertir a string

      if (isPremium && subscriptionPlan != null) {
        await _analytics.setUserProperty(
            name: 'subscription_plan', value: subscriptionPlan);
      }
    } catch (e) {
      debugPrint('❌ Error en setUserProperties: $e');
    }
  }

  /// Actualizar propiedades basadas en el modelo de usuario
  Future<void> updateUserFromModel(UserModel user) async {
    try {
      await setUserProperties(
        userId: user.id,
        isPremium: user.subscription.isPremium,
        subscriptionPlan: user.subscription.plan,
      );
    } catch (e) {
      debugPrint('❌ Error en updateUserFromModel: $e');
    }
  }

  /// Limpiar datos de usuario al cerrar sesión
  Future<void> clearUserData() async {
    try {
      await _analytics.setUserId(id: null);
    } catch (e) {
      debugPrint('❌ Error en clearUserData: $e');
    }
  }
}
