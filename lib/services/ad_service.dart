// lib/services/ad_service.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:goalkeeper_stats/core/constants/ad_constants.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/services/analytics_service.dart';
import 'package:goalkeeper_stats/services/firebase_crashlytics_service.dart';

/// Servicio centralizado para gestionar anuncios en la aplicación
class AdService {
  // Singleton pattern
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // Servicios externos
  final AnalyticsService _analytics = AnalyticsService();
  final FirebaseCrashlyticsService _crashlytics = FirebaseCrashlyticsService();

  // Estado del servicio
  bool _isInitialized = false;
  bool _hasUserConsent = true;
  SharedPreferences? _prefs;

  // Anuncios activos
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  // Controladores de estado
  final StreamController<AdResult> _adEventController =
      StreamController<AdResult>.broadcast();

  // Contadores y cooldowns
  final Map<AdPlacement, DateTime> _lastShownTimes = {};
  final Map<AdPlacement, int> _dailyCounts = {};

  // Configuración actual
  UserModel? _currentUser;
  int _actionCount = 0;

  // ==================== GETTERS PÚBLICOS ====================

  bool get isInitialized => _isInitialized;
  Stream<AdResult> get adEvents => _adEventController.stream;
  bool get shouldShowAds => _currentUser?.subscription.isPremium != true;

  // ==================== INICIALIZACIÓN ====================

  /// Inicializa el servicio de anuncios
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      debugPrint('🎯 Inicializando AdService...');

      // Inicializar SharedPreferences
      _prefs = await SharedPreferences.getInstance();

      // Cargar configuración guardada
      await _loadSavedConfiguration();

      // Configurar dispositivos de test si es necesario
      if (kDebugMode && AdConstants.testDeviceIds.isNotEmpty) {
        final RequestConfiguration requestConfiguration = RequestConfiguration(
          testDeviceIds: AdConstants.testDeviceIds,
        );
        MobileAds.instance.updateRequestConfiguration(requestConfiguration);
      }

      // Inicializar Mobile Ads SDK
      await MobileAds.instance.initialize();

      // Verificar configuración de consentimiento
      await _checkConsentStatus();

      _isInitialized = true;
      debugPrint('✅ AdService inicializado correctamente');

      // Registrar evento de inicialización
      await _analytics.logEvent(
        name: 'ad_service_initialized',
        parameters: {
          'has_consent': _hasUserConsent,
          'debug_mode': kDebugMode,
        },
      );

      return true;
    } catch (e, stack) {
      _crashlytics.recordError(
        e,
        stack,
        reason: 'Error inicializando AdService',
      );
      debugPrint('❌ Error inicializando AdService: $e');
      return false;
    }
  }

  /// Actualiza la información del usuario actual
  void updateUser(UserModel user) {
    _currentUser = user;

    // Si el usuario es premium, limpiar anuncios
    if (user.subscription.isPremium) {
      _clearAllAds();
      debugPrint('🌟 Usuario premium detectado - anuncios deshabilitados');
    }

    // Resetear contadores si es un nuevo día
    _resetDailyCountersIfNeeded();
  }

  // ==================== ANUNCIOS BANNER ====================

  /// Crea un anuncio banner para la ubicación especificada
  Future<BannerAd?> createBannerAd(AdPlacement placement) async {
    if (!shouldShowAds || !_isInitialized) return null;

    try {
      debugPrint('📱 Creando banner ad para: $placement');

      final adUnitId = _getBannerAdUnitId();

      final banner = BannerAd(
        size: AdSize.banner,
        adUnitId: adUnitId,
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            debugPrint('✅ Banner cargado: $placement');
            _analytics.logEvent(name: AdConstants.adLoadedEvent, parameters: {
              'ad_type': 'banner',
              'placement': placement.toString(),
            });
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('❌ Error cargando banner: $error');
            _analytics.logEvent(name: AdConstants.adFailedEvent, parameters: {
              'ad_type': 'banner',
              'placement': placement.toString(),
              'error_code': error.code,
            });
            ad.dispose();
          },
          onAdOpened: (ad) {
            _analytics.logEvent(name: AdConstants.adClickedEvent, parameters: {
              'ad_type': 'banner',
              'placement': placement.toString(),
            });
          },
        ),
        request: _buildAdRequest(),
      );

      await banner.load();
      return banner;
    } catch (e, stack) {
      _crashlytics.recordError(e, stack, reason: 'Error creando banner ad');
      debugPrint('❌ Error creando banner: $e');
      return null;
    }
  }

  // ==================== ANUNCIOS INTERSTICIALES ====================

  /// Carga un anuncio intersticial
  Future<void> loadInterstitialAd() async {
    if (!shouldShowAds || !_isInitialized) return;

    try {
      debugPrint('🎬 Cargando anuncio intersticial...');

      await InterstitialAd.load(
        adUnitId: _getInterstitialAdUnitId(),
        request: _buildAdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            debugPrint('✅ Intersticial cargado');

            _analytics.logEvent(name: AdConstants.adLoadedEvent, parameters: {
              'ad_type': 'interstitial',
            });
          },
          onAdFailedToLoad: (error) {
            debugPrint('❌ Error cargando intersticial: $error');
            _interstitialAd = null;

            _analytics.logEvent(name: AdConstants.adFailedEvent, parameters: {
              'ad_type': 'interstitial',
              'error_code': error.code,
            });
          },
        ),
      );
    } catch (e, stack) {
      _crashlytics.recordError(e, stack, reason: 'Error cargando intersticial');
      debugPrint('❌ Error cargando intersticial: $e');
    }
  }

  /// Muestra un anuncio intersticial si las condiciones se cumplen
  Future<bool> showInterstitialAd(AdPlacement placement) async {
    if (!shouldShowAds || !_isInitialized) return false;

    try {
      // Verificar cooldown y límites
      if (!_canShowAd(placement)) {
        debugPrint('⏳ No se puede mostrar intersticial: cooldown o límite');
        return false;
      }

      // Verificar si hay anuncio cargado
      if (_interstitialAd == null) {
        debugPrint('❌ No hay intersticial cargado');
        await loadInterstitialAd(); // Cargar para la próxima vez
        return false;
      }

      debugPrint('🎬 Mostrando anuncio intersticial: $placement');

      // Configurar listeners
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          debugPrint('🎬 Intersticial mostrado');
          _recordAdShown(placement);

          _analytics.logEvent(name: AdConstants.adShownEvent, parameters: {
            'ad_type': 'interstitial',
            'placement': placement.toString(),
          });
        },
        onAdDismissedFullScreenContent: (ad) {
          debugPrint('✅ Intersticial cerrado');
          ad.dispose();
          _interstitialAd = null;

          // Cargar siguiente anuncio
          loadInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint('❌ Error mostrando intersticial: $error');
          ad.dispose();
          _interstitialAd = null;

          _analytics.logEvent(name: AdConstants.adFailedEvent, parameters: {
            'ad_type': 'interstitial',
            'error_code': error.code,
            'stage': 'show',
          });
        },
      );

      // Mostrar anuncio
      await _interstitialAd!.show();
      return true;
    } catch (e, stack) {
      _crashlytics.recordError(e, stack,
          reason: 'Error mostrando intersticial');
      debugPrint('❌ Error mostrando intersticial: $e');
      return false;
    }
  }

  // ==================== ANUNCIOS DE RECOMPENSA ====================

  /// Carga un anuncio de recompensa
  Future<void> loadRewardedAd() async {
    if (!shouldShowAds || !_isInitialized) return;

    try {
      debugPrint('🏆 Cargando anuncio de recompensa...');

      await RewardedAd.load(
        adUnitId: _getRewardedAdUnitId(),
        request: _buildAdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            debugPrint('✅ Anuncio de recompensa cargado');

            _analytics.logEvent(name: AdConstants.adLoadedEvent, parameters: {
              'ad_type': 'rewarded',
            });
          },
          onAdFailedToLoad: (error) {
            debugPrint('❌ Error cargando recompensa: $error');
            _rewardedAd = null;

            _analytics.logEvent(name: AdConstants.adFailedEvent, parameters: {
              'ad_type': 'rewarded',
              'error_code': error.code,
            });
          },
        ),
      );
    } catch (e, stack) {
      _crashlytics.recordError(e, stack, reason: 'Error cargando rewarded ad');
      debugPrint('❌ Error cargando rewarded ad: $e');
    }
  }

  /// Muestra un anuncio de recompensa
  Future<bool> showRewardedAd({
    required Function(String rewardType, int amount) onRewardEarned,
    String rewardType = 'extra_shots',
  }) async {
    if (!shouldShowAds || !_isInitialized) return false;

    try {
      // Verificar límites
      if (!_canShowAd(AdPlacement.rewardOffer)) {
        debugPrint('⏳ No se puede mostrar recompensa: límite alcanzado');
        return false;
      }

      // Verificar si hay anuncio cargado
      if (_rewardedAd == null) {
        debugPrint('❌ No hay anuncio de recompensa cargado');
        await loadRewardedAd(); // Cargar para la próxima vez
        return false;
      }

      debugPrint('🏆 Mostrando anuncio de recompensa');

      bool rewardEarned = false;

      // Configurar listeners
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          debugPrint('🏆 Recompensa mostrada');
          _recordAdShown(AdPlacement.rewardOffer);

          _analytics.logEvent(name: AdConstants.adShownEvent, parameters: {
            'ad_type': 'rewarded',
            'reward_type': rewardType,
          });
        },
        onAdDismissedFullScreenContent: (ad) {
          debugPrint('✅ Recompensa cerrada');
          ad.dispose();
          _rewardedAd = null;

          // Cargar siguiente anuncio
          loadRewardedAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint('❌ Error mostrando recompensa: $error');
          ad.dispose();
          _rewardedAd = null;

          _analytics.logEvent(name: AdConstants.adFailedEvent, parameters: {
            'ad_type': 'rewarded',
            'error_code': error.code,
            'stage': 'show',
          });
        },
      );

      // Mostrar anuncio con callback de recompensa
      await _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          rewardEarned = true;
          final amount = AdConstants.rewardBenefits[rewardType] ?? 1;

          debugPrint('🎉 Recompensa ganada: $rewardType x$amount');

          _analytics
              .logEvent(name: AdConstants.adRewardEarnedEvent, parameters: {
            'reward_type': rewardType,
            'amount': amount,
          });

          onRewardEarned(rewardType, amount);
        },
      );

      return rewardEarned;
    } catch (e, stack) {
      _crashlytics.recordError(e, stack, reason: 'Error mostrando rewarded ad');
      debugPrint('❌ Error mostrando rewarded ad: $e');
      return false;
    }
  }

  // ==================== CONTROL DE FRECUENCIA ====================

  /// Verifica si se puede mostrar un anuncio en la ubicación especificada
  bool _canShowAd(AdPlacement placement) {
    final config = AdPlacementConfig.configs[placement];
    if (config == null) return false;

    final now = DateTime.now();

    // Verificar cooldown
    if (config.respectCooldown && _lastShownTimes.containsKey(placement)) {
      final lastShown = _lastShownTimes[placement]!;
      final cooldown = config.type == AdType.rewarded
          ? AdConstants.rewardedCooldown
          : AdConstants.interstitialCooldown;

      if (now.difference(lastShown).inSeconds < cooldown) {
        return false;
      }
    }

    // Verificar límite diario
    if (config.maxPerDay != null) {
      final count = _dailyCounts[placement] ?? 0;

      if (count >= config.maxPerDay!) {
        return false;
      }
    }

    // Verificar acciones mínimas para intersticiales
    if (config.type == AdType.interstitial) {
      if (_actionCount < AdConstants.actionsBeforeInterstitial) {
        return false;
      }
    }

    return true;
  }

  /// Registra que se mostró un anuncio
  void _recordAdShown(AdPlacement placement) {
    final now = DateTime.now();

    // Actualizar último tiempo mostrado
    _lastShownTimes[placement] = now;

    // Actualizar contador diario
    _dailyCounts[placement] = (_dailyCounts[placement] ?? 0) + 1;

    // Resetear contador de acciones si es intersticial
    final config = AdPlacementConfig.configs[placement];
    if (config?.type == AdType.interstitial) {
      _actionCount = 0;
    }

    // Guardar en persistencia
    _saveDailyCounts();
  }

  /// Incrementa el contador de acciones
  void incrementActionCount() {
    _actionCount++;
  }

  /// Resetea contadores diarios si es necesario
  void _resetDailyCountersIfNeeded() {
    final today = _getTodayKey();
    final lastResetDay = _prefs?.getString('last_reset_day');

    if (lastResetDay != today) {
      _dailyCounts.clear();
      _prefs?.setString('last_reset_day', today);
      debugPrint('🔄 Contadores diarios reseteados');
    }
  }

  // ==================== MÉTODOS DE UTILIDAD ====================

  /// Construye la configuración de la petición de anuncio
  AdRequest _buildAdRequest() {
    return AdRequest(
      nonPersonalizedAds: !_hasUserConsent,
    );
  }

  /// Obtiene el ID de unidad de anuncio para banners
  String _getBannerAdUnitId() {
    if (kDebugMode && AdConstants.useTestAdsInDebug) {
      return Platform.isAndroid
          ? AdConstants.androidTestBannerId
          : AdConstants.iosTestBannerId;
    }

    return Platform.isAndroid
        ? AdConstants.androidProdBannerId
        : AdConstants.iosProdBannerId;
  }

  /// Obtiene el ID de unidad de anuncio para intersticiales
  String _getInterstitialAdUnitId() {
    if (kDebugMode && AdConstants.useTestAdsInDebug) {
      return Platform.isAndroid
          ? AdConstants.androidTestInterstitialId
          : AdConstants.iosTestInterstitialId;
    }

    return Platform.isAndroid
        ? AdConstants.androidProdInterstitialId
        : AdConstants.iosProdInterstitialId;
  }

  /// Obtiene el ID de unidad de anuncio para recompensas
  String _getRewardedAdUnitId() {
    if (kDebugMode && AdConstants.useTestAdsInDebug) {
      return Platform.isAndroid
          ? AdConstants.androidTestRewardedId
          : AdConstants.iosTestRewardedId;
    }

    return Platform.isAndroid
        ? AdConstants.androidProdRewardedId
        : AdConstants.iosProdRewardedId;
  }

  /// Obtiene la clave del día actual
  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  // ==================== PERSISTENCIA ====================

  /// Carga la configuración guardada
  Future<void> _loadSavedConfiguration() async {
    try {
      // Cargar consentimiento
      _hasUserConsent = _prefs?.getBool('ad_user_consent') ?? true;

      // Cargar contadores diarios
      _resetDailyCountersIfNeeded();

      // Cargar contador de acciones
      _actionCount = _prefs?.getInt('action_count') ?? 0;

      debugPrint('📁 Configuración de anuncios cargada');
    } catch (e) {
      debugPrint('❌ Error cargando configuración: $e');
    }
  }

  /// Guarda los contadores diarios
  Future<void> _saveDailyCounts() async {
    try {
      await _prefs?.setInt('action_count', _actionCount);
      debugPrint('💾 Contadores guardados');
    } catch (e) {
      debugPrint('❌ Error guardando contadores: $e');
    }
  }

  /// Verifica el estado de consentimiento
  Future<void> _checkConsentStatus() async {
    debugPrint('✅ Estado de consentimiento verificado: $_hasUserConsent');
  }

  // ==================== MÉTODOS PÚBLICOS ADICIONALES ====================

  /// Solicita consentimiento del usuario para anuncios personalizados
  Future<void> requestUserConsent(bool consent) async {
    _hasUserConsent = consent;
    await _prefs?.setBool('ad_user_consent', consent);

    debugPrint('📝 Consentimiento actualizado: $consent');

    _analytics.logEvent(name: 'ad_consent_updated', parameters: {
      'consent_given': consent,
    });
  }

  /// Limpia todos los anuncios cargados
  void _clearAllAds() {
    _bannerAd?.dispose();
    _bannerAd = null;

    _interstitialAd?.dispose();
    _interstitialAd = null;

    _rewardedAd?.dispose();
    _rewardedAd = null;

    debugPrint('🧹 Todos los anuncios limpiados');
  }

  /// Libera recursos del servicio
  void dispose() {
    _clearAllAds();
    _adEventController.close();
    debugPrint('🗑️ AdService disposed');
  }

  // ==================== MÉTODOS DE DEBUGGING ====================

  /// Obtiene información de debug sobre el estado del servicio
  Map<String, dynamic> getDebugInfo() {
    return {
      'isInitialized': _isInitialized,
      'shouldShowAds': shouldShowAds,
      'hasUserConsent': _hasUserConsent,
      'actionCount': _actionCount,
      'dailyCounts': _dailyCounts,
      'lastShownTimes': _lastShownTimes.map(
        (key, value) => MapEntry(key.toString(), value.toIso8601String()),
      ),
      'adsLoaded': {
        'banner': _bannerAd != null,
        'interstitial': _interstitialAd != null,
        'rewarded': _rewardedAd != null,
      },
      'currentUser': _currentUser?.subscription.isPremium ?? 'unknown',
    };
  }

  /// Fuerza la carga de todos los tipos de anuncios (solo para testing)
  Future<void> preloadAllAds() async {
    if (!shouldShowAds || !_isInitialized) return;

    debugPrint('🔄 Precargando todos los anuncios...');

    await Future.wait([
      loadInterstitialAd(),
      loadRewardedAd(),
    ]);

    debugPrint('✅ Anuncios precargados');
  }
}
