// lib/core/constants/ad_constants.dart

/// Constantes para configuración de anuncios
class AdConstants {
  // Prevenir instanciación
  AdConstants._();

  // ==================== IDs DE ANUNCIOS PARA ANDROID ====================

  // TESTING - Usar durante desarrollo
  static const String androidTestBannerId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String androidTestInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String androidTestRewardedId =
      'ca-app-pub-3940256099942544/5224354917';

  // PRODUCTION - Reemplazar con tus IDs reales de AdMob
  static const String androidProdBannerId =
      'ca-app-pub-5362666186946504/7956809194';
  static const String androidProdInterstitialId =
      'ca-app-pub-5362666186946504/2719367332';
  static const String androidProdRewardedId =
      'ca-app-pub-5362666186946504/6444416974';

  // ==================== IDs DE ANUNCIOS PARA iOS ====================

  // TESTING - Usar durante desarrollo
  static const String iosTestBannerId =
      'ca-app-pub-3940256099942544/2934735716';
  static const String iosTestInterstitialId =
      'ca-app-pub-3940256099942544/4411468910';
  static const String iosTestRewardedId =
      'ca-app-pub-3940256099942544/1712485313';

  // PRODUCTION - Reemplazar con tus IDs reales de AdMob
  static const String iosProdBannerId =
      'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String iosProdInterstitialId =
      'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String iosProdRewardedId =
      'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';

  // ==================== CONFIGURACIÓN DE FRECUENCIA ====================

  /// Tiempo mínimo entre anuncios intersticiales (en segundos)
  static const int interstitialCooldown = 30; // 3 minutos

  /// Número mínimo de acciones antes de mostrar un intersticial
  static const int actionsBeforeInterstitial = 5;

  /// Tiempo mínimo entre anuncios de recompensa (en segundos)
  static const int rewardedCooldown = 300; // 5 minutos

  // ==================== CONFIGURACIÓN DE UBICACIONES ====================

  /// Pantallas donde se muestran banners
  static const List<String> bannerScreens = [
    'home',
    'statistics',
    'matches',
    'shots_list',
  ];

  /// Acciones que pueden disparar anuncios intersticiales
  static const List<String> interstitialTriggers = [
    'shot_created',
    'match_created',
    'stats_viewed',
    'export_requested',
  ];

  // ==================== CONFIGURACIÓN DE REWARDS ====================

  /// Beneficios por ver anuncios de recompensa
  static const Map<String, int> rewardBenefits = {
    'extra_shots': 5, // 5 tiros adicionales por anuncio
    'premium_preview': 60, // 1 hora de funciones premium
  };

  // ==================== MENSAJES DE USUARIO ====================

  static const String bannerLoadErrorMessage =
      'No se pudo cargar el anuncio. La funcionalidad no se ve afectada.';

  static const String interstitialNotReadyMessage =
      'El anuncio no está listo. Inténtalo de nuevo en unos segundos.';

  static const String rewardAdOfferTitle = '¡Obtén tiros adicionales!';
  static const String rewardAdOfferMessage =
      'Ve un anuncio corto y obtén 5 tiros adicionales para hoy.';

  static const String premiumNoAdsMessage =
      'Como usuario Premium, no verás anuncios. ¡Disfruta de la experiencia completa!';

  // ==================== CONFIGURACIÓN AVANZADA ====================

  /// Días de gracia sin anuncios para nuevos usuarios
  static const int newUserGraceDays = 3;

  /// Máximo de anuncios intersticiales por día para usuarios gratuitos
  static const int maxInterstitialsPerDay = 10;

  /// Máximo de anuncios de recompensa por día
  static const int maxRewardedPerDay = 5;

  // ==================== ANALYTICS EVENTS ====================

  static const String adRequestedEvent = 'ad_requested';
  static const String adLoadedEvent = 'ad_loaded';
  static const String adFailedEvent = 'ad_failed';
  static const String adShownEvent = 'ad_shown';
  static const String adClickedEvent = 'ad_clicked';
  static const String adRewardEarnedEvent = 'ad_reward_earned';

  // ==================== CONFIGURACIÓN DE TESTING ====================

  /// Usar anuncios de test en modo debug
  static const bool useTestAdsInDebug = false;

  /// IDs de dispositivos de test (añadir tu device ID aquí)
  static const List<String> testDeviceIds = [
    // Añadir IDs de dispositivos de test aquí
    // Ejemplo: '33BE2250B43518CCDA7DE426D04EE231'
  ];
}

/// Enumeración para tipos de anuncios
enum AdType {
  banner,
  interstitial,
  rewarded,
}

/// Enumeración para ubicaciones de anuncios
enum AdPlacement {
  homeTop,
  homeBottom,
  statisticsTop,
  afterShotCreation,
  afterMatchCreation,
  beforeExport,
  rewardOffer,
}

/// Enumeración para resultados de anuncios
enum AdResult {
  loaded,
  failed,
  shown,
  clicked,
  dismissed,
  rewardEarned,
}

/// Configuración específica por placement
class AdPlacementConfig {
  final AdType type;
  final AdPlacement placement;
  final bool respectCooldown;
  final int? maxPerDay;
  final String? customMessage;

  const AdPlacementConfig({
    required this.type,
    required this.placement,
    this.respectCooldown = true,
    this.maxPerDay,
    this.customMessage,
  });

  // Configuraciones predefinidas
  static const Map<AdPlacement, AdPlacementConfig> configs = {
    AdPlacement.homeTop: AdPlacementConfig(
      type: AdType.banner,
      placement: AdPlacement.homeTop,
      respectCooldown: false,
    ),
    AdPlacement.homeBottom: AdPlacementConfig(
      type: AdType.banner,
      placement: AdPlacement.homeBottom,
      respectCooldown: false,
    ),
    AdPlacement.statisticsTop: AdPlacementConfig(
      type: AdType.banner,
      placement: AdPlacement.statisticsTop,
      respectCooldown: false,
    ),
    AdPlacement.afterShotCreation: AdPlacementConfig(
      type: AdType.interstitial,
      placement: AdPlacement.afterShotCreation,
      maxPerDay: 3,
    ),
    AdPlacement.afterMatchCreation: AdPlacementConfig(
      type: AdType.interstitial,
      placement: AdPlacement.afterMatchCreation,
      maxPerDay: 2,
    ),
    AdPlacement.beforeExport: AdPlacementConfig(
      type: AdType.interstitial,
      placement: AdPlacement.beforeExport,
      maxPerDay: 2,
    ),
    AdPlacement.rewardOffer: AdPlacementConfig(
      type: AdType.rewarded,
      placement: AdPlacement.rewardOffer,
      respectCooldown: true,
      maxPerDay: AdConstants.maxRewardedPerDay,
      customMessage: AdConstants.rewardAdOfferMessage,
    ),
  };
}
