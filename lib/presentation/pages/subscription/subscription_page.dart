import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/data/models/subscription_info.dart';
import 'package:goalkeeper_stats/presentation/blocs/auth/auth_bloc.dart';
import 'package:goalkeeper_stats/presentation/blocs/auth/auth_event.dart';
import 'package:goalkeeper_stats/presentation/blocs/auth/auth_state.dart';
import 'package:goalkeeper_stats/services/purchase_service.dart';
import 'package:goalkeeper_stats/services/connectivity_service.dart';
import 'package:goalkeeper_stats/services/firebase_crashlytics_service.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // <-- Añadir esta línea

/// Página para gestionar suscripciones premium
/// Integrada con in_app_purchase para procesar transacciones reales
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
  bool _isLoading = false;
  int _selectedPlan = 2; // 0: Mensual, 1: Trimestral, 2: Anual
  
  // Servicios
  late final PurchaseService _purchaseService;
  final _connectivityService = ConnectivityService();
  final _crashlytics = FirebaseCrashlyticsService();
  
  // Estado de conectividad
  bool _isOffline = false;
  
  // Estado de los productos
  bool _productsReady = false;
  String? _errorMessage;

  // Definición de los planes de suscripción
  final List<Map<String, dynamic>> _plans = [
    {
      'id': 'goalkeeper_stats_monthly',
      'storeId': 'goalkeeper_stats_monthly',
      'name': 'Mensual',
      'price': 4.99,
      'period': '/ mes',
      'discount': 0,
      'billingText': 'Facturación mensual',
      'durationDays': 30,
    },
    {
      'id': 'goalkeeper_stats_quarterly',
      'storeId': 'goalkeeper_stats_quarterly',
      'name': 'Trimestral',
      'price': 12.99,
      'period': '/ 3 meses',
      'discount': 15,
      'billingText': 'Facturación trimestral',
      'durationDays': 90,
    },
    {
      'id': 'goalkeeper_stats_annual',
      'storeId': 'goalkeeper_stats_annual',
      'name': 'Anual',
      'price': 39.99,
      'period': '/ año',
      'discount': 35,
      'billingText': 'Facturación anual',
      'durationDays': 365,
    },
  ];

  late UserModel _currentUser;
  StreamSubscription? _purchaseSubscription;
  StreamSubscription? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _initServices();
  }
  
  Future<void> _initServices() async {
    // Inicializar servicio de compras
    _purchaseService = PurchaseService();
    
    // Registrar datos del usuario en Crashlytics para seguimiento
    _crashlytics.setUserData(
      userId: _currentUser.id,
      email: _currentUser.email,
      isPremium: _currentUser.subscription.isPremium,
      subscriptionPlan: _currentUser.subscription.plan,
    );
    
    // Comprobar conectividad inicial
    _checkConnectivity();
    
    // Inicializar productos disponibles
    _loadProducts();
    
    // Escuchar cambios de compras completadas
    _purchaseSubscription = _purchaseService.purchaseStream.listen(
      _handlePurchaseUpdate,
      onError: _handlePurchaseError,
    );
    
    // Escuchar cambios de conectividad
    _connectivitySubscription = _connectivityService.onConnectivityChanged.listen((result) {
      setState(() {
        _isOffline = result != ConnectivityResult.wifi && 
                    result != ConnectivityResult.mobile &&
                    result != ConnectivityResult.ethernet;
      });
      
      // Mostrar snackbar en cambios de conectividad
      if (mounted) {
        _connectivityService.showConnectivitySnackBar(context);
      }
    });
  }
  
  Future<void> _checkConnectivity() async {
    bool connected = await _connectivityService.checkConnectivity();
    setState(() {
      _isOffline = !connected;
    });
  }
  
  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Obtener IDs de productos
      final productIds = _plans.map((plan) => plan['storeId'] as String).toList();
      
      // Inicializar servicio de compras
      final success = await _purchaseService.initialize(productIds);
      
      if (!success) {
        setState(() {
          _errorMessage = 'No se pudieron cargar los planes de suscripción';
          _productsReady = false;
        });
      } else {
        // Actualizar precios reales desde las tiendas
        _updatePricesFromStore();
        setState(() {
          _productsReady = true;
        });
      }
    } catch (e) {
      _crashlytics.recordError(
        e, 
        StackTrace.current,
        reason: 'Error al cargar productos',
        information: ['userId: ${_currentUser.id}'],
      );
      
      setState(() {
        _errorMessage = 'Error al cargar planes: ${e.toString()}';
        _productsReady = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _updatePricesFromStore() {
    // Actualizar precios con la información real de las tiendas
    for (var i = 0; i < _plans.length; i++) {
      final storeProduct = _purchaseService.getProductById(_plans[i]['storeId']);
      if (storeProduct != null) {
        _plans[i]['price'] = storeProduct.price;
        // También podríamos actualizar el nombre si deseamos usar el de la tienda
      }
    }
  }
  
  void _handlePurchaseUpdate(PurchaseInfo purchaseInfo) {
    // Solo procesar si la compra fue exitosa y verificada
    if (purchaseInfo.status == PurchaseStatus.purchased || 
        purchaseInfo.status == PurchaseStatus.restored) {
      
      // Buscar el plan correspondiente
      final planIndex = _plans.indexWhere((plan) => plan['storeId'] == purchaseInfo.productId);
      
      if (planIndex >= 0) {
        final selectedPlan = _plans[planIndex];
        final planId = selectedPlan['id'];
        final durationDays = selectedPlan['durationDays'];
        
        // Calcular fecha de expiración
        final expirationDate = DateTime.now().add(Duration(days: durationDays));
        
        // Crear nueva suscripción
        final newSubscription = SubscriptionInfo.premium(
          expirationDate: expirationDate,
          plan: planId,
        );
        
        // Actualizar estado local
        setState(() {
          _currentUser = _currentUser.copyWith(
            subscription: newSubscription,
          );
          _isLoading = false;
        });
        
        // Actualizar en Firebase a través del BLoC
        try {
          context.read<AuthBloc>().add(UpdateSubscriptionEvent(newSubscription));
        } catch (e) {
          _crashlytics.recordError(
            e, 
            StackTrace.current,
            reason: 'Error al actualizar suscripción en BLoC',
          );
        }
        
        // Mostrar confirmación
        _showSuccessDialog(_currentUser.subscription.isPremium);
      }
    } else if (purchaseInfo.status == PurchaseStatus.error) {
      setState(() {
        _isLoading = false;
      });
      
      // Mostrar error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error en la compra: ${purchaseInfo.message}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _handlePurchaseError(dynamic error) {
    setState(() {
      _isLoading = false;
    });
    
    _crashlytics.recordError(
      error, 
      StackTrace.current,
      reason: 'Error en proceso de compra',
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: ${error.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _purchaseService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planes Premium'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProducts,
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildContent(),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      "Procesando suscripción...",
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      // Botón flotante para suscripción
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        width: double.infinity,
        child: FloatingActionButton.extended(
          onPressed: (_isLoading || _isOffline || !_productsReady)
              ? null // Deshabilitar en estas condiciones
              : (_currentUser.subscription.isPremium
                  ? _updateSubscription
                  : _startSubscription),
          backgroundColor: (_isLoading || _isOffline || !_productsReady) 
              ? Colors.grey 
              : Colors.green,
          elevation: 4,
          label: Text(
            _currentUser.subscription.isPremium
                ? 'Actualizar Suscripción'
                : 'Suscribirse Ahora',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          icon: const Icon(Icons.star),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final isPremium = _currentUser.subscription.isPremium;

    if (_isOffline) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Sin conexión a internet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Se requiere conexión para gestionar suscripciones',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _checkConnectivity,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadProducts,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding:
          const EdgeInsets.only(bottom: 80.0), // Espacio para el botón flotante
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado
          _buildHeader(isPremium),

          // Estado actual de suscripción
          if (isPremium) _buildCurrentSubscription(),

          // Planes disponibles
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              isPremium ? 'Cambiar Plan' : 'Planes Disponibles',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Selección de planes
          _buildPlanSelector(),

          // Beneficios
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Beneficios Premium',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildBenefitItem(
                  'Sin límites de registros diarios',
                  'Registra todos los tiros que quieras, sin restricciones',
                ),
                _buildBenefitItem(
                  'Organización por partidos',
                  'Agrupa tus registros por partidos y entrenamientos',
                ),
                _buildBenefitItem(
                  'Exportación a Google Sheets',
                  'Exporta tus estadísticas para análisis avanzados',
                ),
                _buildBenefitItem(
                  'Análisis detallado',
                  'Accede a estadísticas y visualizaciones avanzadas',
                ),
                _buildBenefitItem(
                  'Soporte prioritario',
                  'Atención personalizada para cualquier consulta',
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Términos y condiciones
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Al suscribirte, aceptas nuestros Términos de Servicio y Política de Privacidad. '
              'La suscripción se renovará automáticamente al final del período. '
              'Puedes cancelar en cualquier momento desde tu cuenta o la configuración de la tienda.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 100), // Espacio para el botón flotante
        ],
      ),
    );
  }

  Widget _buildHeader(bool isPremium) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.green.shade800,
            Colors.green.shade600,
          ],
        ),
      ),
      child: Column(
        children: [
          Icon(
            isPremium ? Icons.workspace_premium : Icons.star,
            size: 64,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          Text(
            isPremium ? 'Usuario Premium' : 'Mejora tu Experiencia',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isPremium
                ? 'Gracias por tu apoyo'
                : 'Desbloquea todas las funciones y mejora como portero',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentSubscription() {
    final expirationDate = _currentUser.subscription.expirationDate;
    final plan = _currentUser.subscription.plan;

    String planName = 'Desconocido';
    if (plan != null) {
      switch (plan) {
        case 'goalkeeper_stats_monthly':
          planName = 'Mensual';
          break;
        case 'goalkeeper_stats_quarterly':
          planName = 'Trimestral';
          break;
        case 'goalkeeper_stats_annual':
          planName = 'Anual';
          break;
      }
    }

    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tu Suscripción Actual',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Plan', planName),
          if (expirationDate != null)
            _buildInfoRow(
              'Próxima renovación',
              DateFormat('dd/MM/yyyy').format(expirationDate),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isOffline ? null : () {
                    _showCancelSubscriptionDialog();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: const Text('Cancelar Suscripción'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _isOffline ? null : () {
                    // Abrir configuración de suscripción de la tienda
                    _purchaseService.openSubscriptionSettings();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                  ),
                  child: const Text('Administrar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildPlanSelector() {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: _plans.length,
        itemBuilder: (context, index) {
          final plan = _plans[index];
          final isSelected = _selectedPlan == index;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedPlan = index;
              });
            },
            child: Container(
              width: 180,
              margin: const EdgeInsets.only(right: 16.0),
              decoration: BoxDecoration(
                color: isSelected ? Colors.green.shade50 : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Colors.green : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.green.shade100
                              : Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.star,
                          color: isSelected ? Colors.green : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        plan['name'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color:
                              isSelected ? Colors.green.shade800 : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${plan['price']}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color:
                              isSelected ? Colors.green.shade800 : Colors.black,
                        ),
                      ),
                      Text(
                        plan['period'],
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    plan['billingText'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const Spacer(),
                  if (plan['discount'] > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Ahorra ${plan['discount']}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBenefitItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check,
              color: Colors.green.shade800,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelSubscriptionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Suscripción'),
        content: const Text(
          '¿Estás seguro de que quieres cancelar tu suscripción Premium? '
          'Seguirás teniendo acceso hasta el final del período actual, '
          'pero no se renovará automáticamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No, Mantener'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelSubscription();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Sí, Cancelar'),
          ),
        ],
      ),
    );
  }

  void _cancelSubscription() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Cancelar la suscripción en la tienda
      final success = await _purchaseService.cancelSubscription();
      
      if (success) {
        // Crear una SubscriptionInfo no premium pero que durará hasta la fecha actual
        final cancelledSubscription = _currentUser.subscription.copyWith(
          type: 'free', // Seguirá siendo premium hasta la fecha de expiración
        );
        
        // Actualizar estado local
        setState(() {
          _currentUser = _currentUser.copyWith(
            subscription: cancelledSubscription,
          );
        });
        
        // Actualizar en Firebase
        context.read<AuthBloc>().add(UpdateSubscriptionEvent(cancelledSubscription));
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Suscripción cancelada correctamente. Tendrás acceso Premium hasta el final del período actual.'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Volver con el usuario actualizado
        Navigator.of(context).pop(_currentUser);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo cancelar la suscripción. Por favor, inténtalo desde la configuración de la tienda.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      _crashlytics.recordError(
        e, 
        StackTrace.current,
        reason: 'Error al cancelar suscripción',
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startSubscription() async {
    if (_isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay conexión a internet'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final selectedPlan = _plans[_selectedPlan];
      // Iniciar proceso de compra
      await _purchaseService.purchaseSubscription(selectedPlan['storeId']);
      // El resto del proceso se maneja en el listener de compras
    } catch (e) {
      _crashlytics.recordError(
        e, 
        StackTrace.current,
        reason: 'Error al iniciar suscripción',
      );
      
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _updateSubscription() async {
    if (_isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay conexión a internet'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final selectedPlan = _plans[_selectedPlan];
      // Actualizar suscripción existente
      await _purchaseService.updateSubscription(selectedPlan['storeId']);
      // El resto del proceso se maneja en el listener de compras
    } catch (e) {
      _crashlytics.recordError(
        e, 
        StackTrace.current,
        reason: 'Error al actualizar suscripción',
      );
      
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccessDialog(bool isUpdate) {
    final plan = _plans[_selectedPlan];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(isUpdate ? 'Plan Actualizado' : '¡Bienvenido a Premium!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              isUpdate
                  ? 'Tu plan ha sido actualizado correctamente a ${plan['name']}'
                  : '¡Ya eres usuario Premium! Disfruta de todos los beneficios.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Cerrar diálogo
              // Pasar el usuario actualizado como resultado
              Navigator.pop(context, _currentUser);
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }
}