import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/core/constants/app_constants.dart';
import 'package:goalkeeper_stats/data/models/subscription_info.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Clase que representa información sobre una compra
class PurchaseInfo {
  final String productId;
  final PurchaseStatus status;
  final String? message;
  final PurchaseDetails? purchaseDetails;

  PurchaseInfo({
    required this.productId,
    required this.status,
    this.message,
    this.purchaseDetails,
  });
}

/// Servicio para gestionar compras y suscripciones reales
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

  // IDs de productos
  static const List<String> _subscriptionIds = [
    AppConstants.monthlySubscriptionId,
    AppConstants.quarterlySubscriptionId,
    AppConstants.biannualSubscriptionId,
    AppConstants.annualSubscriptionId,
  ];

  // Singleton
  static final PurchaseService _instance = PurchaseService._internal();

  factory PurchaseService() => _instance;

  PurchaseService._internal();

  /// Getters
  bool get isAvailable => _isAvailable;
  List<ProductDetails> get products => _products;
  bool get isInitialized => _isInitialized;
  Stream<PurchaseInfo> get purchaseStream => _purchaseController.stream;

  /// Inicializar el servicio de compras
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      debugPrint('🛒 Inicializando PurchaseService...');

      // Verificar disponibilidad
      _isAvailable = await _inAppPurchase.isAvailable();

      if (!_isAvailable) {
        debugPrint('❌ Las compras in-app no están disponibles');
        return false;
      }

      debugPrint('✅ Compras in-app disponibles');

      // Configurar Android si es necesario
      // if (Platform.isAndroid) {
      //   final InAppPurchaseAndroidPlatformAddition androidAddition =
      //       _inAppPurchase
      //           .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      //   InAppPurchaseAndroidPlatformAddition.enablePendingPurchases();
      // }

      // Escuchar actualizaciones de compras
      _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
        _handlePurchaseUpdate,
        onDone: () => _purchaseSubscription?.cancel(),
        onError: (error) {
          _crashlytics.recordError(error, StackTrace.current,
              reason: 'Error en stream de compras');
          debugPrint('❌ Error en stream de compras: $error');
        },
      );

      // Cargar productos
      await _loadProducts();

      // Verificar compras pendientes
      await _checkPendingPurchases();

      _isInitialized = true;
      debugPrint('✅ PurchaseService inicializado correctamente');
      return true;
    } catch (e, stack) {
      _crashlytics.recordError(e, stack,
          reason: 'Error inicializando PurchaseService');
      debugPrint('❌ Error inicializando PurchaseService: $e');
      return false;
    }
  }

  /// Cargar productos desde las tiendas
  Future<void> _loadProducts() async {
    try {
      debugPrint('📦 Cargando productos...');

      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails(_subscriptionIds.toSet());

      if (response.error != null) {
        throw Exception('Error al consultar productos: ${response.error}');
      }

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('⚠️ Productos no encontrados: ${response.notFoundIDs}');
        _crashlytics.log('Productos no encontrados: ${response.notFoundIDs}');
      }

      _products = response.productDetails;
      debugPrint('✅ Productos cargados: ${_products.length}');

      for (final product in _products) {
        debugPrint('📱 Producto: ${product.id} - ${product.price}');
      }
    } catch (e, stack) {
      _crashlytics.recordError(e, stack, reason: 'Error cargando productos');
      debugPrint('❌ Error cargando productos: $e');
      throw e;
    }
  }

  /// Verificar compras pendientes al inicializar
  Future<void> _checkPendingPurchases() async {
    try {
      debugPrint('🔍 Verificando compras pendientes...');

      if (Platform.isAndroid) {
        final InAppPurchaseAndroidPlatformAddition androidAddition =
            _inAppPurchase
                .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();

        final QueryPurchaseDetailsResponse response =
            await androidAddition.queryPastPurchases();

        if (response.error == null) {
          await _handlePurchaseUpdate(response.pastPurchases);
        }
      } else if (Platform.isIOS) {
        // Para iOS, las compras pendientes se manejan automáticamente
        // a través del stream de compras
        await _inAppPurchase.restorePurchases();
      }
    } catch (e, stack) {
      _crashlytics.recordError(e, stack,
          reason: 'Error verificando compras pendientes');
      debugPrint('❌ Error verificando compras pendientes: $e');
    }
  }

  /// Obtener producto por ID
  ProductDetails? getProductById(String productId) {
    try {
      return _products.firstWhere((product) => product.id == productId);
    } catch (e) {
      return null;
    }
  }

  /// Comprar suscripción
  Future<bool> purchaseSubscription(String productId) async {
    if (!_isAvailable || !_isInitialized) {
      debugPrint('❌ Tienda no disponible o no inicializada');
      throw Exception('Tienda no disponible');
    }

    try {
      debugPrint('🛒 Iniciando compra: $productId');

      final ProductDetails? product = getProductById(productId);
      if (product == null) {
        throw Exception('Producto no encontrado: $productId');
      }

      final String? userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      // Configurar parámetros de compra
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: product,
        applicationUserName: userId, // Para asociar la compra al usuario
      );

      // Iniciar compra
      final bool success =
          await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);

      if (!success) {
        throw Exception('No se pudo iniciar la compra');
      }

      debugPrint('✅ Compra iniciada exitosamente');
      return true;
    } catch (e, stack) {
      _crashlytics.recordError(e, stack, reason: 'Error en compra: $productId');
      debugPrint('❌ Error en compra: $e');

      _purchaseController.add(PurchaseInfo(
        productId: productId,
        status: PurchaseStatus.error,
        message: e.toString(),
      ));

      return false;
    }
  }

  /// Manejar actualizaciones de compras
  Future<void> _handlePurchaseUpdate(List<PurchaseDetails> purchases) async {
    debugPrint('🔄 Procesando ${purchases.length} actualizaciones de compra');

    for (final purchase in purchases) {
      debugPrint(
          '📦 Procesando compra: ${purchase.productID} - ${purchase.status}');

      try {
        await _processPurchase(purchase);
      } catch (e, stack) {
        _crashlytics.recordError(e, stack,
            reason: 'Error procesando compra: ${purchase.productID}');
        debugPrint('❌ Error procesando compra ${purchase.productID}: $e');
      }
    }
  }

  /// Procesar una compra individual
  Future<void> _processPurchase(PurchaseDetails purchase) async {
    switch (purchase.status) {
      case PurchaseStatus.pending:
        debugPrint('⏳ Compra pendiente: ${purchase.productID}');
        _purchaseController.add(PurchaseInfo(
          productId: purchase.productID,
          status: PurchaseStatus.pending,
          message: 'Procesando compra...',
          purchaseDetails: purchase,
        ));
        break;

      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        debugPrint('✅ Compra exitosa/restaurada: ${purchase.productID}');

        // Verificar y procesar la compra
        final bool isValid = await _verifyAndProcessPurchase(purchase);

        if (isValid) {
          _purchaseController.add(PurchaseInfo(
            productId: purchase.productID,
            status: purchase.status,
            message: 'Compra completada exitosamente',
            purchaseDetails: purchase,
          ));
        } else {
          _purchaseController.add(PurchaseInfo(
            productId: purchase.productID,
            status: PurchaseStatus.error,
            message: 'Error verificando la compra',
            purchaseDetails: purchase,
          ));
        }
        break;

      case PurchaseStatus.error:
        debugPrint(
            '❌ Error en compra: ${purchase.productID} - ${purchase.error}');
        _purchaseController.add(PurchaseInfo(
          productId: purchase.productID,
          status: PurchaseStatus.error,
          message: purchase.error?.message ?? 'Error desconocido',
          purchaseDetails: purchase,
        ));
        break;

      case PurchaseStatus.canceled:
        debugPrint('❌ Compra cancelada: ${purchase.productID}');
        _purchaseController.add(PurchaseInfo(
          productId: purchase.productID,
          status: PurchaseStatus.canceled,
          message: 'Compra cancelada por el usuario',
          purchaseDetails: purchase,
        ));
        break;
    }

    // Completar la compra si es necesario
    if (purchase.pendingCompletePurchase) {
      await _inAppPurchase.completePurchase(purchase);
      debugPrint('✅ Compra completada: ${purchase.productID}');
    }
  }

  /// Verificar y procesar compra
  Future<bool> _verifyAndProcessPurchase(PurchaseDetails purchase) async {
    try {
      // 1. Verificar la compra con la tienda
      final bool isValid = await _verifyPurchaseWithStore(purchase);
      if (!isValid) {
        debugPrint('❌ Verificación de compra falló: ${purchase.productID}');
        return false;
      }

      // 2. Actualizar suscripción del usuario
      await _updateUserSubscription(purchase);

      // 3. Registrar la compra para auditoría
      await _recordPurchase(purchase);

      debugPrint('✅ Compra verificada y procesada: ${purchase.productID}');
      return true;
    } catch (e, stack) {
      _crashlytics.recordError(e, stack,
          reason: 'Error verificando compra: ${purchase.productID}');
      debugPrint('❌ Error verificando compra: $e');
      return false;
    }
  }

  /// Verificar compra con la tienda (implementación básica)
  Future<bool> _verifyPurchaseWithStore(PurchaseDetails purchase) async {
    try {
      // Para producción, deberías implementar verificación de servidor
      // que valide el recibo con Google Play o App Store

      // Verificación básica: check que los datos no estén vacíos
      final verificationData = purchase.verificationData;

      if (verificationData.localVerificationData.isEmpty) {
        return false;
      }

      if (Platform.isAndroid) {
        // Para Android, verificar que tenemos la firma
        return verificationData.serverVerificationData.isNotEmpty;
      } else if (Platform.isIOS) {
        // Para iOS, verificar que tenemos el recibo
        return verificationData.serverVerificationData.isNotEmpty;
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error en verificación básica: $e');
      return false;
    }
  }

  /// Actualizar suscripción del usuario en Firestore
  Future<void> _updateUserSubscription(PurchaseDetails purchase) async {
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('Usuario no autenticado');
    }

    // Determinar tipo de plan y duración
    final Map<String, dynamic> planInfo = _getPlanInfo(purchase.productID);

    // Calcular fecha de expiración
    final DateTime expirationDate =
        DateTime.now().add(Duration(days: planInfo['durationDays']));

    // Crear información de suscripción
    final subscription = SubscriptionInfo(
      type: 'premium',
      expirationDate: expirationDate,
      plan: planInfo['planType'],
    );

    // Actualizar en Firestore
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .update({
      'subscription': subscription.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint(
        '✅ Suscripción actualizada: ${planInfo['planType']} hasta $expirationDate');
  }

  /// Registrar compra para auditoría
  Future<void> _recordPurchase(PurchaseDetails purchase) async {
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore.collection('purchases').add({
        'userId': userId,
        'productId': purchase.productID,
        'purchaseId': purchase.purchaseID,
        'transactionDate': FieldValue.serverTimestamp(),
        'status': purchase.status.toString(),
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'verificationData': {
          'local': purchase.verificationData.localVerificationData,
          'server': purchase.verificationData.serverVerificationData,
          'source': purchase.verificationData.source,
        },
      });

      debugPrint('✅ Compra registrada en auditoría');
    } catch (e) {
      debugPrint('⚠️ Error registrando compra para auditoría: $e');
      // No lanzar error, es solo para auditoría
    }
  }

  /// Obtener información del plan
  Map<String, dynamic> _getPlanInfo(String productId) {
    switch (productId) {
      case AppConstants.monthlySubscriptionId:
        return {
          'planType': 'monthly',
          'durationDays': AppConstants.monthlySubscriptionDays,
        };
      case AppConstants.quarterlySubscriptionId:
        return {
          'planType': 'quarterly',
          'durationDays': AppConstants.quarterlySubscriptionDays,
        };
      case AppConstants.biannualSubscriptionId:
        return {
          'planType': 'biannual',
          'durationDays': AppConstants.biannualSubscriptionDays,
        };
      case AppConstants.annualSubscriptionId:
        return {
          'planType': 'annual',
          'durationDays': AppConstants.annualSubscriptionDays,
        };
      default:
        throw Exception('Producto desconocido: $productId');
    }
  }

  /// Restaurar compras
  Future<bool> restorePurchases() async {
    if (!_isAvailable || !_isInitialized) {
      throw Exception('Tienda no disponible');
    }

    try {
      debugPrint('🔄 Restaurando compras...');
      await _inAppPurchase.restorePurchases();
      debugPrint('✅ Restauración iniciada');
      return true;
    } catch (e, stack) {
      _crashlytics.recordError(e, stack, reason: 'Error restaurando compras');
      debugPrint('❌ Error restaurando compras: $e');
      return false;
    }
  }

  /// Verificar suscripción actual
  Future<SubscriptionInfo> verifyCurrentSubscription(String userId) async {
    try {
      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get(GetOptions(source: Source.server));

      if (!userDoc.exists) {
        return SubscriptionInfo.free();
      }

      final userData = userDoc.data();
      if (userData == null || !userData.containsKey('subscription')) {
        return SubscriptionInfo.free();
      }

      final subscription = SubscriptionInfo.fromMap(userData['subscription']);

      // Verificar si ha expirado
      if (subscription.expirationDate != null &&
          subscription.expirationDate!.isBefore(DateTime.now())) {
        // Actualizar a versión gratuita
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
          reason: 'Error verificando suscripción');
      debugPrint('❌ Error verificando suscripción: $e');
      return SubscriptionInfo.free();
    }
  }

  /// Abrir configuración de suscripciones
  Future<bool> openSubscriptionSettings() async {
    try {
      Uri url;
      if (Platform.isAndroid) {
        url = Uri.parse('https://play.google.com/store/account/subscriptions');
      } else if (Platform.isIOS) {
        url = Uri.parse('https://apps.apple.com/account/subscriptions');
      } else {
        return false;
      }

      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('❌ Error abriendo configuración: $e');
      return false;
    }
  }

  /// Liberar recursos
  void dispose() {
    _purchaseSubscription?.cancel();
    _purchaseController.close();
    debugPrint('🗑️ PurchaseService disposed');
  }
}
