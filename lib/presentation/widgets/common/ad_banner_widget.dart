// lib/presentation/widgets/common/ad_banner_widget.dart

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:goalkeeper_stats/services/ad_service.dart';
import 'package:goalkeeper_stats/core/constants/ad_constants.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';

/// Widget que muestra un banner de anuncio en la interfaz
///
/// Automáticamente gestiona la carga y visualización del anuncio,
/// respetando el estado de suscripción del usuario.
class AdBannerWidget extends StatefulWidget {
  final AdPlacement placement;
  final EdgeInsets? margin;
  final Color? backgroundColor;
  final bool showLoadingIndicator;
  final String? customErrorMessage;
  final VoidCallback? onAdLoaded;
  final VoidCallback? onAdFailed;

  const AdBannerWidget({
    super.key,
    required this.placement,
    this.margin,
    this.backgroundColor,
    this.showLoadingIndicator = true,
    this.customErrorMessage,
    this.onAdLoaded,
    this.onAdFailed,
  });

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  late AdService _adService;

  @override
  void initState() {
    super.initState();
    _adService = context.read<AdService>();
    _loadAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  /// Carga el anuncio banner
  Future<void> _loadAd() async {
    try {
      // Verificar si debe mostrar anuncios
      if (!_adService.shouldShowAds) {
        setState(() {
          _isLoading = false;
          _hasError = false;
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // Crear banner ad
      final bannerAd = await _adService.createBannerAd(widget.placement);

      if (bannerAd != null && mounted) {
        setState(() {
          _bannerAd = bannerAd;
          _isLoading = false;
          _hasError = false;
        });

        widget.onAdLoaded?.call();
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage =
              widget.customErrorMessage ?? AdConstants.bannerLoadErrorMessage;
        });

        widget.onAdFailed?.call();
      }
    } catch (e) {
      debugPrint('❌ Error cargando banner ad: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage =
              widget.customErrorMessage ?? AdConstants.bannerLoadErrorMessage;
        });

        widget.onAdFailed?.call();
      }
    }
  }

  /// Reintenta cargar el anuncio
  void _retryLoad() {
    _loadAd();
  }

  @override
  Widget build(BuildContext context) {
    // Si no debe mostrar anuncios, no renderizar nada
    if (!_adService.shouldShowAds) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: widget.margin ?? const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: _buildContent(),
    );
  }

  /// Construye el contenido del widget según el estado
  Widget _buildContent() {
    if (_isLoading && widget.showLoadingIndicator) {
      return _buildLoadingState();
    }

    if (_hasError) {
      return _buildErrorState();
    }

    if (_bannerAd != null) {
      return _buildAdContent();
    }

    // Estado por defecto: no mostrar nada
    return const SizedBox.shrink();
  }

  /// Construye el estado de carga
  Widget _buildLoadingState() {
    return Container(
      height: 60,
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor.withOpacity(0.6),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Cargando anuncio...',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
          ),
        ],
      ),
    );
  }

  /// Construye el estado de error
  Widget _buildErrorState() {
    return Container(
      height: 60,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: Theme.of(context).hintColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage ?? 'Error cargando anuncio',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _retryLoad,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Reintentar',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  /// Construye el contenido del anuncio
  Widget _buildAdContent() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}

/// Widget específico para banner en la parte superior de pantallas
class TopAdBannerWidget extends StatelessWidget {
  final AdPlacement placement;
  final bool showWhenPremium;

  const TopAdBannerWidget({
    super.key,
    required this.placement,
    this.showWhenPremium = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<UserModel>(
      builder: (context, user, child) {
        // No mostrar si es premium y no está permitido
        if (user.subscription.isPremium && !showWhenPremium) {
          return const SizedBox.shrink();
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdBannerWidget(
              placement: placement,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              backgroundColor: Theme.of(context).cardColor,
            ),
            // Divisor sutil
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              height: 1,
              color: Theme.of(context).dividerColor.withOpacity(0.1),
            ),
          ],
        );
      },
    );
  }
}

/// Widget específico para banner en la parte inferior de pantallas
class BottomAdBannerWidget extends StatelessWidget {
  final AdPlacement placement;
  final bool showWhenPremium;
  final bool floatingStyle;

  const BottomAdBannerWidget({
    super.key,
    required this.placement,
    this.showWhenPremium = false,
    this.floatingStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<UserModel>(
      builder: (context, user, child) {
        // No mostrar si es premium y no está permitido
        if (user.subscription.isPremium && !showWhenPremium) {
          return const SizedBox.shrink();
        }

        final banner = AdBannerWidget(
          placement: placement,
          margin: floatingStyle
              ? const EdgeInsets.all(16)
              : const EdgeInsets.fromLTRB(16, 0, 16, 8),
          backgroundColor: Theme.of(context).cardColor,
        );

        if (floatingStyle) {
          return Positioned(
            left: 0,
            right: 0,
            bottom: 80, // Espacio para el BottomNavigationBar
            child: banner,
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Divisor sutil
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              height: 1,
              color: Theme.of(context).dividerColor.withOpacity(0.1),
            ),
            banner,
          ],
        );
      },
    );
  }
}

/// Widget que muestra información sobre los beneficios premium (sin anuncios)
class PremiumNoBannerWidget extends StatelessWidget {
  final VoidCallback? onUpgradePressed;

  const PremiumNoBannerWidget({
    super.key,
    this.onUpgradePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.1),
            Theme.of(context).primaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.star,
            color: Theme.of(context).primaryColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AdConstants.premiumNoAdsMessage,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          if (onUpgradePressed != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onUpgradePressed,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Mejorar',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Helper para crear banners adaptativos según el placement
class AdBannerHelper {
  /// Crea un banner adaptativo para cualquier ubicación
  static Widget createForPlacement(
    BuildContext context,
    AdPlacement placement, {
    EdgeInsets? margin,
    VoidCallback? onUpgradePressed,
  }) {
    switch (placement) {
      case AdPlacement.homeTop:
      case AdPlacement.statisticsTop:
        return TopAdBannerWidget(placement: placement);

      case AdPlacement.homeBottom:
        return BottomAdBannerWidget(
          placement: placement,
          floatingStyle: false,
        );

      default:
        return AdBannerWidget(
          placement: placement,
          margin: margin,
        );
    }
  }

  /// Verifica si se debe mostrar el banner en la ubicación especificada
  static bool shouldShowBanner(
    BuildContext context,
    AdPlacement placement,
  ) {
    try {
      final adService = context.read<AdService>();
      return adService.shouldShowAds && adService.isInitialized;
    } catch (e) {
      debugPrint('❌ Error verificando si mostrar banner: $e');
      return false;
    }
  }
}
