import 'package:flutter/material.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/services/purchase_service.dart';
import 'package:goalkeeper_stats/core/constants/app_constants.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class SubscriptionPage extends StatefulWidget {
  final UserModel user;

  const SubscriptionPage({
    super.key,
    required this.user,
  });

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final PurchaseService _purchaseService = PurchaseService();
  bool _isLoading = true;
  bool _isProcessingPurchase = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePurchases();
    _listenToPurchases();
  }

  Future<void> _initializePurchases() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final success = await _purchaseService.initialize();

      if (!success) {
        setState(() {
          _errorMessage =
              'Las compras no están disponibles en este dispositivo';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error inicializando compras: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _listenToPurchases() {
    _purchaseService.purchaseStream.listen((purchaseInfo) {
      switch (purchaseInfo.status) {
        case PurchaseStatus.error:
          setState(() {
            _isProcessingPurchase = false;
          });
          _showMessage(purchaseInfo.message ?? 'Error en la compra',
              isError: true);
          break;

        case PurchaseStatus.canceled:
          setState(() {
            _isProcessingPurchase = false;
          });
          _showMessage('Compra cancelada', isError: false);
          break;
        case PurchaseStatus.pending:
          // TODO: Handle this case.
          throw UnimplementedError();
        case PurchaseStatus.purchased:
          // TODO: Handle this case.
          throw UnimplementedError();
        case PurchaseStatus.restored:
          // TODO: Handle this case.
          throw UnimplementedError();
      }
    });
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
  }

  void _navigateBackWithSuccess() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop(true); // Indicar que hubo cambios
      }
    });
  }

  Future<void> _purchaseProduct(String productId) async {
    if (_isProcessingPurchase) return;

    try {
      setState(() {
        _isProcessingPurchase = true;
      });

      await _purchaseService.purchaseSubscription(productId);
    } catch (e) {
      setState(() {
        _isProcessingPurchase = false;
      });
      _showMessage('Error iniciando compra: $e', isError: true);
    }
  }

  Future<void> _restorePurchases() async {
    try {
      setState(() {
        _isProcessingPurchase = true;
      });

      await _purchaseService.restorePurchases();
      _showMessage('Buscando compras anteriores...', isError: false);
    } catch (e) {
      setState(() {
        _isProcessingPurchase = false;
      });
      _showMessage('Error restaurando compras: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suscripción Premium'),
        elevation: 0,
      ),
      body: _isLoading ? _buildLoadingView() : _buildContent(),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Cargando opciones de suscripción...'),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_errorMessage != null) {
      return _buildErrorView();
    }

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCurrentStatusCard(),
              const SizedBox(height: 24),
              _buildPremiumFeaturesCard(),
              const SizedBox(height: 24),
              _buildSubscriptionPlans(),
              const SizedBox(height: 24),
              _buildRestorePurchasesButton(),
              const SizedBox(height: 24),
              _buildFooterInfo(),
            ],
          ),
        ),
        if (_isProcessingPurchase)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Procesando compra...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializePurchases,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStatusCard() {
    final isCurrentlyPremium = widget.user.subscription.isPremium;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCurrentlyPremium ? Icons.verified : Icons.info_outline,
                  color: isCurrentlyPremium ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Estado Actual',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isCurrentlyPremium ? 'Premium Activo' : 'Versión Gratuita',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isCurrentlyPremium ? Colors.green : Colors.grey,
              ),
            ),
            if (isCurrentlyPremium &&
                widget.user.subscription.expirationDate != null)
              Text(
                'Expira: ${_formatDate(widget.user.subscription.expirationDate!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumFeaturesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🏆 Funciones Premium',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const _FeatureItem(
              icon: Icons.sports_soccer,
              title: 'Tiros ilimitados',
              description: 'Registra todos los tiros que necesites',
            ),
            const _FeatureItem(
              icon: Icons.event,
              title: 'Gestión de partidos',
              description: 'Organiza tus entrenamientos y partidos',
            ),
            const _FeatureItem(
              icon: Icons.analytics,
              title: 'Estadísticas avanzadas',
              description: 'Análisis detallado de tu rendimiento',
            ),
            const _FeatureItem(
              icon: Icons.file_download,
              title: 'Exportación de datos',
              description: 'Exporta tus estadísticas a Google Sheets',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionPlans() {
    final products = _purchaseService.products;

    if (products.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No hay planes disponibles en este momento'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Planes de Suscripción',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ...products.map((product) => _buildSubscriptionPlanCard(product)),
      ],
    );
  }

  Widget _buildSubscriptionPlanCard(ProductDetails product) {
    final planInfo = _getPlanDisplayInfo(product.id);
    final isCurrentPlan = widget.user.subscription.plan == planInfo['planType'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        planInfo['title'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (planInfo['discount'] != null)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            planInfo['discount'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  product.price,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              planInfo['description'],
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    isCurrentPlan ? null : () => _purchaseProduct(product.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCurrentPlan ? Colors.grey : Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  isCurrentPlan ? 'Plan Actual' : 'Suscribirse',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestorePurchasesButton() {
    return Center(
      child: TextButton(
        onPressed: _isProcessingPurchase ? null : _restorePurchases,
        child: const Text('Restaurar Compras'),
      ),
    );
  }

  Widget _buildFooterInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Información Importante',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              '• Las suscripciones se renuevan automáticamente\n'
              '• Puedes cancelar en cualquier momento desde tu cuenta de Google Play\n'
              '• La cancelación será efectiva al final del período actual\n'
              '• No hay reembolsos por períodos no utilizados',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _purchaseService.openSubscriptionSettings(),
              child: const Text('Gestionar Suscripción'),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getPlanDisplayInfo(String productId) {
    switch (productId) {
      case AppConstants.monthlySubscriptionId:
        return {
          'title': 'Plan Mensual',
          'description': 'Acceso completo por 1 mes',
          'planType': 'monthly',
        };
      case AppConstants.quarterlySubscriptionId:
        return {
          'title': 'Plan Trimestral',
          'description': 'Acceso completo por 3 meses',
          'discount': 'AHORRA 15%',
          'planType': 'quarterly',
        };
      case AppConstants.biannualSubscriptionId:
        return {
          'title': 'Plan Semestral',
          'description': 'Acceso completo por 6 meses',
          'discount': 'AHORRA 25%',
          'planType': 'biannual',
        };
      case AppConstants.annualSubscriptionId:
        return {
          'title': 'Plan Anual',
          'description': 'Acceso completo por 1 año completo',
          'discount': 'AHORRA 40%',
          'planType': 'annual',
        };
      default:
        return {
          'title': 'Plan Premium',
          'description': 'Acceso completo',
          'planType': 'unknown',
        };
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}  
// }pending:
//           setState(() {
//             _isProcessingPurchase = true;
//           });
//           _showMessage('Procesando compra...', isError: false);
//           break;
          
//         case PurchaseStatus.purchased:
//         case PurchaseStatus.restored:
//           setState(() {
//             _isProcessingPurchase = false;
//           });
//           _showMessage('¡Suscripción activada exitosamente!', isError: false);
//           _navigateBackWithSuccess();
//           break;
          
//         case PurchaseStatus.