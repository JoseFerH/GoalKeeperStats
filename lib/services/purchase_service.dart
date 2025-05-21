import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/core/constants/app_constants.dart';
import 'package:goalkeeper_stats/data/models/subscription_info.dart';

/// Clase que representa información sobre una compra
class PurchaseInfo {
  final String productId;
  final PurchaseStatus status;
  final String? message;

  PurchaseInfo({
    required this.productId,
    required this.status,
    this.message,
  });
}

/// Servicio para gestionar compras y suscripciones dentro de la aplicación
///
/// Maneja la inicialización de la tienda, compra de productos, verificación
/// de recibos y actualización del estado de suscripción.
class PurchaseService {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream Controller para emitir actualizaciones de compra
  final StreamController<PurchaseInfo> _purchaseController =
      StreamController<PurchaseInfo>.broadcast();

  // Stream de compras de la tienda
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  // Productos disponibles
  List<ProductDetails> _products = [];

  // Estado de inicialización
  bool _isInitialized = false;
  bool _isAvailable = false;

  // Singleton
  static final PurchaseService _instance = PurchaseService._internal();

  Future<bool> verifyActivePurchase(String productId, String userId) async {
  try {
    // Obtener la información actual de suscripción
    final subscription = await verifyCurrentSubscription(userId);
    
    // Verificar si el usuario tiene suscripción premium
    if (subscription.type != 'premium' || subscription.plan == null) {
      return false;
    }
    
    // Verificar si la suscripción ha expirado
    if (subscription.expirationDate == null || 
        subscription.expirationDate!.isBefore(DateTime.now())) {
      return false;
    }
    
    // Verificar que el ID del producto coincida con el plan actual
    switch (subscription.plan) {
      case 'monthly':
        return productId == AppConstants.monthlySubscriptionId;
      case 'quarterly':
        return productId == AppConstants.quarterlySubscriptionId;
      case 'biannual':
        return productId == AppConstants.biannualSubscriptionId;
      case 'annual':
        return productId == AppConstants.annualSubscriptionId;
      default:
        return false;
    }
  } catch (e, stack) {
    _crashlytics.recordError(e, stack, 
        reason: 'Error al verificar compra activa');
    debugPrint('Error al verificar compra activa: $e');
    return false; // En caso de error, considerar como no activa
  }
}

/// Refresca y actualiza el estado de suscripción del usuario
/// consultando directamente con Firestore y verificando con las tiendas
///
/// [userId] - ID del usuario cuya suscripción se va a verificar
/// Retorna la información de suscripción actualizada o null si hay error
Future<SubscriptionInfo?> refreshSubscriptionStatus(String userId) async {
  try {
    // Obtener la información actual de suscripción desde Firestore
    final subscription = await verifyCurrentSubscription(userId);
    
    // Si la suscripción ya no es premium o ha expirado, no es necesario
    // verificar con las tiendas
    if (subscription.type != 'premium' || 
        subscription.expirationDate == null ||
        subscription.expirationDate!.isBefore(DateTime.now())) {
      return subscription;
    }
    
    // Verificar con las tiendas si la suscripción sigue activa
    // Esto es importante para detectar cancelaciones o problemas de pago
    bool isStillActive = false;
    
    if (subscription.plan != null) {
      String productId;
      
      switch (subscription.plan) {
        case 'monthly':
          productId = AppConstants.monthlySubscriptionId;
          break;
        case 'quarterly':
          productId = AppConstants.quarterlySubscriptionId;
          break;
        case 'biannual':
          productId = AppConstants.biannualSubscriptionId;
          break;
        case 'annual':
          productId = AppConstants.annualSubscriptionId;
          break;
        default:
          productId = '';
      }
      
      if (productId.isNotEmpty) {
        isStillActive = await verifyActivePurchase(productId, userId);
      }
    }
    
    // Si la verificación con la tienda indica que ya no está activa,
    // actualizar a versión gratuita
    if (!isStillActive && subscription.isPremium) {
      final freeSubscription = SubscriptionInfo.free();
      
      // Actualizar en Firestore
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update({
        'subscription': freeSubscription.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return freeSubscription;
    }
    
    return subscription;
  } catch (e, stack) {
    _crashlytics.recordError(e, stack,
        reason: 'Error al refrescar estado de suscripción');
    debugPrint('Error al refrescar estado de suscripción: $e');
    return null;
  }
}

  /// Constructor de fábrica para el patrón singleton
  factory PurchaseService() {
    return _instance;
  }

  PurchaseService._internal();

  /// Estado de disponibilidad de la tienda
  bool get isAvailable => _isAvailable;

  /// Lista de productos disponibles
  List<ProductDetails> get products => _products;

  /// Estado de inicialización
  bool get isInitialized => _isInitialized;

  /// Stream de actualizaciones de compra
  Stream<PurchaseInfo> get purchaseStream => _purchaseController.stream;

  /// Inicializar el servicio de compras con los IDs de productos
  Future<bool> initialize(List<String> productIds) async {
    if (_isInitialized) return true;

    try {
      // Verificar si las compras están disponibles
      _isAvailable = await _inAppPurchase.isAvailable();

      if (!_isAvailable) {
        debugPrint(
            'Las compras in-app no están disponibles en este dispositivo');
        return false;
      }

      // Configurar tienda para iOS
      if (Platform.isIOS) {
        final InAppPurchaseStoreKitPlatformAddition iosPlatformAddition =
            _inAppPurchase
                .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();

        await iosPlatformAddition.setDelegate(_createStoreKitDelegate());
      }

      // Escuchar actualizaciones de compras
      _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
        _handlePurchaseUpdate,
        onDone: () {
          _purchaseSubscription?.cancel();
        },
        onError: (error) {
          _crashlytics.recordError(error, StackTrace.current,
              reason: 'Error en stream de compras');
          debugPrint('Error en stream de compras: $error');
        },
      );

      // Cargar productos disponibles
      await _loadProducts(productIds);

      _isInitialized = true;
      debugPrint('PurchaseService inicializado correctamente');
      return true;
    } catch (e, stack) {
      _crashlytics.recordError(e, stack,
          reason: 'Error al inicializar PurchaseService');
      debugPrint('Error al inicializar PurchaseService: $e');
      return false;
    }
  }

  /// Cargar los productos disponibles desde las tiendas
  Future<void> _loadProducts(List<String> productIds) async {
    try {
      // Convertir lista a conjunto
      final Set<String> ids = productIds.toSet();

      // Consultar detalles de productos
      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails(ids);

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('Productos no encontrados: ${response.notFoundIDs}');
      }

      if (response.error != null) {
        debugPrint('Error al cargar productos: ${response.error}');
        _crashlytics.recordError(response.error!, StackTrace.current,
            reason: 'Error al cargar productos');
        return;
      }

      _products = response.productDetails;
      debugPrint('Productos cargados: ${_products.length}');
    } catch (e, stack) {
      _crashlytics.recordError(e, stack,
          reason: 'Error al cargar productos de suscripción');
      debugPrint('Error al cargar productos: $e');
    }
  }

  /// Obtener un producto por su ID
  ProductDetails? getProductById(String productId) {
    try {
      return _products.firstWhere((product) => product.id == productId);
    } catch (e) {
      return null;
    }
  }

  /// Iniciar compra de suscripción
  Future<bool> purchaseSubscription(String productId) async {
    if (!_isAvailable || !_isInitialized) {
      debugPrint('La tienda no está disponible o inicializada');
      return false;
    }

    try {
      final ProductDetails? product = getProductById(productId);
      if (product == null) {
        debugPrint('Producto no encontrado: $productId');
        return false;
      }

      // Configurar compra
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: product,
        applicationUserName: _auth.currentUser?.uid,
      );

      // Iniciar compra de suscripción
      return await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e, stack) {
      _crashlytics.recordError(e, stack, reason: 'Error al iniciar compra');
      debugPrint('Error al iniciar compra: $e');
      return false;
    }
  }

  /// Actualizar suscripción existente
  Future<bool> updateSubscription(String newProductId) async {
    if (!_isAvailable || !_isInitialized) {
      debugPrint('La tienda no está disponible o inicializada');
      return false;
    }

    try {
      final ProductDetails? newProduct = getProductById(newProductId);
      if (newProduct == null) {
        debugPrint('Producto no encontrado: $newProductId');
        return false;
      }

      // En Android, manejar actualización de suscripción
      if (Platform.isAndroid) {
        final oldPurchase = await _checkExistingSubscription();
        if (oldPurchase != null) {
          // Configurar actualización
          final GooglePlayPurchaseParam googlePlayParam =
              GooglePlayPurchaseParam(
            productDetails: newProduct,
            changeSubscriptionParam: ChangeSubscriptionParam(
              oldPurchaseDetails: oldPurchase,
              prorationMode: ProrationMode.immediateWithTimeProration,
            ),
          );

          return await _inAppPurchase.buyNonConsumable(
              purchaseParam: googlePlayParam);
        }
      }

      // Si no hay suscripción anterior o estamos en iOS, realizar compra normal
      return await purchaseSubscription(newProductId);
    } catch (e, stack) {
      _crashlytics.recordError(e, stack, 
          reason: 'Error al actualizar suscripción');
      debugPrint('Error al actualizar suscripción: $e');
      return false;
    }
  }

  /// Cancelar suscripción actual
  Future<bool> cancelSubscription() async {
    if (!_isAvailable || !_isInitialized) {
      debugPrint('La tienda no está disponible o inicializada');
      return false;
    }

    try {
      // No se puede cancelar directamente desde la API, redirigir a configuración
      if (await openSubscriptionSettings()) {
        // Actualizar el estado en Firestore como cancelado
        final userId = _auth.currentUser?.uid;
        if (userId != null) {
          // Obtener suscripción actual
          final userDoc = await _firestore
              .collection(AppConstants.usersCollection)
              .doc(userId)
              .get();

          if (userDoc.exists && userDoc.data()?['subscription'] != null) {
            // Marcar como cancelada pero mantener fecha de expiración
            await _firestore
                .collection(AppConstants.usersCollection)
                .doc(userId)
                .update({
              'subscription.cancelledAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
        return true;
      }
      return false;
    } catch (e, stack) {
      _crashlytics.recordError(e, stack, 
          reason: 'Error al cancelar suscripción');
      debugPrint('Error al cancelar suscripción: $e');
      return false;
    }
  }

  /// Abrir configuración de suscripciones de la tienda
  Future<bool> openSubscriptionSettings() async {
    try {
      Uri url;
      if (Platform.isAndroid) {
        url = Uri.parse(
            'https://play.google.com/store/account/subscriptions');
      } else if (Platform.isIOS) {
        url = Uri.parse('https://apps.apple.com/account/subscriptions');
      } else {
        return false;
      }

      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error al abrir configuración de suscripciones: $e');
      return false;
    }
  }

  /// Verificar si existe una suscripción activa
  Future<GooglePlayPurchaseDetails?> _checkExistingSubscription() async {
    if (Platform.isAndroid) {
      try {
        // Obtener compras pasadas en Android
        final InAppPurchaseAndroidPlatformAddition androidAddition =
            _inAppPurchase
                .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();

        final QueryPurchaseDetailsResponse response =
            await androidAddition.queryPastPurchases();

        if (response.error != null) {
          debugPrint('Error al consultar compras pasadas: ${response.error}');
          return null;
        }

        // Buscar suscripción activa
        for (final purchase in response.pastPurchases) {
          if (purchase is GooglePlayPurchaseDetails &&
              purchase.status == PurchaseStatus.purchased &&
              !purchase.billingClientPurchase.isAcknowledged) {
            return purchase;
          }
        }
      } catch (e) {
        debugPrint('Error al verificar suscripción existente: $e');
      }
    }
    return null;
  }

  /// Manejar actualizaciones de compras
  Future<void> _handlePurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        debugPrint('Compra pendiente: ${purchase.productID}');
        
        // Notificar estado pendiente
        _purchaseController.add(PurchaseInfo(
          productId: purchase.productID,
          status: PurchaseStatus.pending,
          message: 'Procesando compra...',
        ));
        
      } else if (purchase.status == PurchaseStatus.error) {
        _crashlytics.recordError(purchase.error, StackTrace.current,
            reason: 'Error en compra: ${purchase.productID}');
        debugPrint('Error en compra: ${purchase.error}');
        
        // Notificar error
        _purchaseController.add(PurchaseInfo(
          productId: purchase.productID,
          status: PurchaseStatus.error,
          message: purchase.error?.message ?? 'Error desconocido',
        ));
        
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // Verificar recibo
        final bool isValid = await _verifyPurchase(purchase);

        if (isValid) {
          // Entregar producto
          await _deliverProduct(purchase);
          
          // Notificar éxito
          _purchaseController.add(PurchaseInfo(
            productId: purchase.productID,
            status: purchase.status,
            message: 'Compra completada con éxito',
          ));
          
        } else {
          debugPrint('Recibo de compra inválido');
          _crashlytics.log('Recibo de compra inválido: ${purchase.productID}');
          
          // Notificar validación fallida
          _purchaseController.add(PurchaseInfo(
            productId: purchase.productID,
            status: PurchaseStatus.error,
            message: 'Verificación de compra fallida',
          ));
        }
      } else if (purchase.status == PurchaseStatus.canceled) {
        // Notificar cancelación
        _purchaseController.add(PurchaseInfo(
          productId: purchase.productID,
          status: PurchaseStatus.canceled,
          message: 'Compra cancelada',
        ));
      }

      // Completar compra
      if (purchase.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchase);
      }
    }
  }

  /// Verificar validez de la compra/recibo
  Future<bool> _verifyPurchase(PurchaseDetails purchase) async {
    // En una implementación real, deberías verificar con el servidor
    // el recibo de compra para evitar fraudes.

    if (Platform.isIOS) {
      // Verificar recibo iOS con Apple
      return await _verifyReceiptIOS(purchase);
    } else if (Platform.isAndroid) {
      // Verificar compra Android con Google Play
      return await _verifyPurchaseAndroid(purchase);
    }

    return false;
  }

  /// Verificar recibo de compra en iOS
  Future<bool> _verifyReceiptIOS(PurchaseDetails purchase) async {
  try {
    final InAppPurchaseStoreKitPlatformAddition iosPlatformAddition =
        _inAppPurchase
            .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();

    // En producción, debes verificar el recibo con el servidor de Apple
    // a través de un backend seguro

    // Las propiedades correctas son:
    // - purchase.verificationData.localVerificationData
    // - purchase.verificationData.serverVerificationData
    // - purchase.verificationData.source

    // Ejemplo básico de verificación (NO SEGURO para producción)
    final String receiptData = purchase.verificationData.serverVerificationData;
    return receiptData.isNotEmpty;
  } catch (e) {
    debugPrint('Error al verificar recibo iOS: $e');
    return false;
  }
}

  /// Verificar compra en Android
  Future<bool> _verifyPurchaseAndroid(PurchaseDetails purchase) async {
  try {
    // En producción, verifica la firma y el token de compra con Google Play
    // a través de un backend seguro

    // Ejemplo básico de verificación (NO SEGURO para producción)
    final String purchaseData = purchase.verificationData.localVerificationData;
    final String signature = purchase.verificationData.serverVerificationData;
    
    // Verificar que los datos no estén vacíos
    return purchaseData.isNotEmpty && signature.isNotEmpty;
  } catch (e) {
    debugPrint('Error al verificar compra Android: $e');
    return false;
  }
}

  /// Entregar el producto al usuario
  Future<void> _deliverProduct(PurchaseDetails purchase) async {
    try {
      // Si es una suscripción, actualizar estado de suscripción del usuario
      final String productId = purchase.productID;
      final String? userId = _auth.currentUser?.uid;

      if (userId != null) {
        // Determinar tipo de plan y fecha de expiración
        String planType;
        int durationDays;

        switch (productId) {
          case AppConstants.monthlySubscriptionId:
            planType = 'monthly';
            durationDays = AppConstants.monthlySubscriptionDays;
            break;
          case AppConstants.quarterlySubscriptionId:
            planType = 'quarterly';
            durationDays = AppConstants.quarterlySubscriptionDays;
            break;
          case AppConstants.biannualSubscriptionId:
            planType = 'biannual';
            durationDays = AppConstants.biannualSubscriptionDays;
            break;
          case AppConstants.annualSubscriptionId:
            planType = 'annual';
            durationDays = AppConstants.annualSubscriptionDays;
            break;
          default:
            debugPrint('ID de producto desconocido: $productId');
            return;
        }

        // Calcular fecha de expiración
        final expirationDate = DateTime.now().add(Duration(days: durationDays));

        // Crear información de suscripción
        final subscription = SubscriptionInfo(
          type: 'premium',
          expirationDate: expirationDate,
          plan: planType,
        );

        // Actualizar en Firestore
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(userId)
            .update({
          'subscription': subscription.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        debugPrint('Suscripción activada: $planType hasta $expirationDate');
      }
    } catch (e, stack) {
      _crashlytics.recordError(e, stack, reason: 'Error al entregar producto');
      debugPrint('Error al entregar producto: $e');
    }
  }

  /// Restaurar compras anteriores
  Future<bool> restorePurchases() async {
    if (!_isAvailable || !_isInitialized) {
      debugPrint('La tienda no está disponible o inicializada');
      return false;
    }

    try {
      await _inAppPurchase.restorePurchases();
      return true;
    } catch (e, stack) {
      _crashlytics.recordError(e, stack, reason: 'Error al restaurar compras');
      debugPrint('Error al restaurar compras: $e');
      return false;
    }
  }

  /// Verificar el estado actual de la suscripción
  Future<SubscriptionInfo> verifyCurrentSubscription(String userId) async {
    try {
      // Obtener datos del usuario de Firestore
      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get(
              GetOptions(source: Source.server)); // Forzar obtener del servidor

      if (!userDoc.exists) {
        return SubscriptionInfo.free();
      }

      final userData = userDoc.data();
      if (userData == null || !userData.containsKey('subscription')) {
        return SubscriptionInfo.free();
      }

      final subscription = SubscriptionInfo.fromMap(userData['subscription']);

      // Verificar si la suscripción ha expirado
      if (subscription.expirationDate != null &&
          subscription.expirationDate!.isBefore(DateTime.now())) {
        // Actualizar a versión gratuita si expiró
        final freeSubscription = SubscriptionInfo.free();

        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(userId)
            .update({
          'subscription': freeSubscription.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return freeSubscription;
      }

      return subscription;
    } catch (e, stack) {
      _crashlytics.recordError(e, stack,
          reason: 'Error al verificar suscripción');
      debugPrint('Error al verificar suscripción: $e');
      return SubscriptionInfo.free(); // Por defecto, versión gratuita
    }
  }
  
  /// Crear delegado para StoreKit (iOS)
  SKPaymentQueueDelegateWrapper _createStoreKitDelegate() {
    return SKPaymentQueueDelegateWrapper(
      shouldContinueTransaction: (transaction, queue) {
        return true;
      },
      shouldShowPriceConsent: () {
        return false;
      },
    );
  }

  /// Liberar recursos
  void dispose() {
    _purchaseSubscription?.cancel();
    _purchaseController.close();
  }
}