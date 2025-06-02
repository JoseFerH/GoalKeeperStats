// lib/presentation/widgets/common/ad_reward_offer_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:goalkeeper_stats/services/ad_service.dart';
import 'package:goalkeeper_stats/services/daily_limits_service.dart';
import 'package:goalkeeper_stats/core/constants/ad_constants.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';

/// Widget que ofrece al usuario ver un anuncio de recompensa
/// para obtener beneficios adicionales (como tiros extra)
class AdRewardOfferWidget extends StatefulWidget {
  final String rewardType;
  final String title;
  final String description;
  final IconData icon;
  final Color? accentColor;
  final Function(String rewardType, int amount)? onRewardEarned;
  final VoidCallback? onDismissed;
  final bool showCloseButton;
  final EdgeInsets? margin;

  const AdRewardOfferWidget({
    super.key,
    this.rewardType = 'extra_shots',
    this.title = '¡Obtén tiros adicionales!',
    this.description =
        'Ve un anuncio corto y obtén 5 tiros adicionales para hoy.',
    this.icon = Icons.sports_soccer,
    this.accentColor,
    this.onRewardEarned,
    this.onDismissed,
    this.showCloseButton = true,
    this.margin,
  });

  @override
  State<AdRewardOfferWidget> createState() => _AdRewardOfferWidgetState();
}

class _AdRewardOfferWidgetState extends State<AdRewardOfferWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  bool _isLoading = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();

    // Configurar animaciones
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Iniciar animación
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Maneja el tap en el botón de ver anuncio
  Future<void> _onWatchAdPressed() async {
    if (_isLoading || _dismissed) return;

    setState(() => _isLoading = true);

    try {
      final adService = context.read<AdService>();

      // Mostrar anuncio de recompensa
      final success = await adService.showRewardedAd(
        rewardType: widget.rewardType,
        onRewardEarned: (rewardType, amount) {
          widget.onRewardEarned?.call(rewardType, amount);
          _showSuccessMessage(amount);
          _dismiss();
        },
      );

      if (!success && mounted) {
        _showErrorMessage();
      }
    } catch (e) {
      debugPrint('❌ Error mostrando anuncio de recompensa: $e');
      if (mounted) {
        _showErrorMessage();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Muestra mensaje de éxito
  void _showSuccessMessage(int amount) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '¡Genial! Has obtenido $amount tiros adicionales.',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Muestra mensaje de error
  void _showErrorMessage() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'No se pudo cargar el anuncio. Inténtalo de nuevo más tarde.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Descarta el widget con animación
  Future<void> _dismiss() async {
    if (_dismissed) return;

    setState(() => _dismissed = true);

    await _animationController.reverse();

    if (mounted) {
      widget.onDismissed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    return Consumer<AdService>(
      builder: (context, adService, child) {
        // No mostrar si es premium o si el servicio no está disponible
        if (!adService.shouldShowAds || !adService.isInitialized) {
          return const SizedBox.shrink();
        }

        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: Container(
                  margin: widget.margin ?? const EdgeInsets.all(16),
                  child: _buildOfferCard(),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Construye la tarjeta de oferta
  Widget _buildOfferCard() {
    final theme = Theme.of(context);
    final accentColor = widget.accentColor ?? theme.primaryColor;

    return Card(
      elevation: 8,
      shadowColor: accentColor.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: accentColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              accentColor.withOpacity(0.1),
              accentColor.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildContent(),
              const SizedBox(height: 20),
              _buildActionButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// Construye el header con ícono y botón de cerrar
  Widget _buildHeader() {
    final accentColor = widget.accentColor ?? Theme.of(context).primaryColor;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            widget.icon,
            color: accentColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            widget.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
          ),
        ),
        if (widget.showCloseButton)
          IconButton(
            onPressed: _dismiss,
            icon: Icon(
              Icons.close,
              color: Theme.of(context).hintColor,
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
      ],
    );
  }

  /// Construye el contenido descriptivo
  Widget _buildContent() {
    final rewardAmount = AdConstants.rewardBenefits[widget.rewardType] ?? 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.4,
              ),
        ),
        const SizedBox(height: 12),
        _buildRewardInfo(rewardAmount),
      ],
    );
  }

  /// Construye la información de la recompensa
  Widget _buildRewardInfo(int amount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.card_giftcard,
            color: Theme.of(context).primaryColor,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            'Recompensa: +$amount tiros extra',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).primaryColor,
                ),
          ),
        ],
      ),
    );
  }

  /// Construye el botón de acción
  Widget _buildActionButton() {
    final accentColor = widget.accentColor ?? Theme.of(context).primaryColor;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _onWatchAdPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: accentColor.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_circle_fill, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Ver anuncio',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Widget específico para ofrecer tiros adicionales cuando se alcanza el límite
class ExtraShotsOfferWidget extends StatelessWidget {
  final VoidCallback? onRewardEarned;
  final VoidCallback? onDismissed;

  const ExtraShotsOfferWidget({
    super.key,
    this.onRewardEarned,
    this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<UserModel, DailyLimitsService>(
      builder: (context, user, limitsService, child) {
        // Solo mostrar para usuarios gratuitos que han alcanzado el límite
        if (user.subscription.isPremium) {
          return const SizedBox.shrink();
        }

        return FutureBuilder<DailyLimitInfo>(
          future: limitsService.getLimitInfo(user),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.hasReachedLimit) {
              return const SizedBox.shrink();
            }

            return AdRewardOfferWidget(
              rewardType: 'extra_shots',
              title: '¡Has alcanzado tu límite diario!',
              description:
                  'Ve un anuncio corto y obtén 5 tiros adicionales para continuar registrando.',
              icon: Icons.sports_soccer,
              accentColor: Colors.orange,
              onRewardEarned: (type, amount) {
                onRewardEarned?.call();
              },
              onDismissed: onDismissed,
            );
          },
        );
      },
    );
  }
}

/// Widget para mostrar oferta premium como alternativa a los anuncios
class PremiumAlternativeWidget extends StatelessWidget {
  final VoidCallback? onUpgradePressed;
  final VoidCallback? onWatchAdPressed;
  final bool showAdOption;

  const PremiumAlternativeWidget({
    super.key,
    this.onUpgradePressed,
    this.onWatchAdPressed,
    this.showAdOption = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star,
                color: Theme.of(context).primaryColor,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                '¡Mejora tu experiencia!',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Con Premium obtienes tiros ilimitados, '
                'sin anuncios y acceso a todas las funciones.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.4,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Botón Premium
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onUpgradePressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Actualizar a Premium',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),

              // Opción de anuncio
              if (showAdOption) ...[
                const SizedBox(height: 12),
                Text(
                  'o',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onWatchAdPressed,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Ver anuncio para continuar gratis',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
