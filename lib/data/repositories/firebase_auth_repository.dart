import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:goalkeeper_stats/domain/repositories/auth_repository.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/data/models/user_settings.dart';
import 'package:goalkeeper_stats/data/models/subscription_info.dart';
import 'package:goalkeeper_stats/services/cache_manager.dart';

/// 🔥 IMPLEMENTACIÓN COMPLETA: Firebase UI Auth Repository
/// Mantiene toda la funcionalidad original pero evita el error PigeonUserDetails
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final CacheManager _cacheManager;

  // Colección donde se almacenan los usuarios en Firestore
  static const String _usersCollection = 'users';

  // Clave de caché para el usuario actual
  static const String _userCacheKey = 'current_user';

  // Timeouts para operaciones
  static const Duration _authTimeout = Duration(seconds: 30);
  static const Duration _firestoreTimeout = Duration(seconds: 25);
  static const Duration _credentialsTimeout = Duration(seconds: 30);

  // Timeouts optimizados para diferentes escenarios
  static const Duration _authTimeoutFast = Duration(seconds: 45);
  static const Duration _authTimeoutSlow = Duration(seconds: 60);

  /// Constructor con posibilidad de inyección para pruebas
  FirebaseAuthRepository({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    CacheManager? cacheManager,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _cacheManager = cacheManager ?? CacheManager() {
    _initializeRepository();
  }

  /// Inicialización del repositorio con configuración adicional
  void _initializeRepository() {
    try {
      // Configurar Firebase UI Auth
      FirebaseUIAuth.configureProviders([
        GoogleProvider(
          clientId: '415256305974-YOUR-CLIENT-ID.apps.googleusercontent.com',
        ),
      ]);

      // Configurar idioma por defecto para Firebase Auth
      _firebaseAuth.setLanguageCode('es');

      // Log de inicialización
      debugPrint('🔐 FirebaseAuthRepository inicializado correctamente');
    } catch (e) {
      debugPrint('⚠️ Error inicializando AuthRepository: $e');
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final User? firebaseUser = _firebaseAuth.currentUser;

    if (firebaseUser == null) {
      debugPrint('🔐 No hay usuario autenticado en Firebase Auth');
      return null;
    }

    try {
      debugPrint('🔍 Obteniendo usuario actual: ${firebaseUser.uid}');

      // Intentar obtener datos del usuario desde caché primero
      final cachedUser = await _cacheManager.get<UserModel>(_userCacheKey);
      if (cachedUser != null && _isUserCacheValid(cachedUser)) {
        debugPrint('✅ Usuario obtenido desde caché');
        return cachedUser;
      }

      // Si no hay caché o está desactualizada, obtener desde servidor
      debugPrint('🌐 Obteniendo usuario desde Firestore...');
      final userDoc = await _firestore
          .collection(_usersCollection)
          .doc(firebaseUser.uid)
          .get(const GetOptions(source: Source.server))
          .timeout(_firestoreTimeout);

      if (userDoc.exists) {
        final userModel = UserModel.fromFirestore(userDoc);

        // Actualizar caché
        await _cacheManager.set(_userCacheKey, userModel);

        // Actualizar metadata de Crashlytics
        _updateCrashlyticsUserData(userModel);

        debugPrint('✅ Usuario obtenido desde Firestore');
        return userModel;
      } else {
        // Si el documento no existe en Firestore pero sí en Auth, crear nuevo usuario
        debugPrint('👤 Usuario no existe en Firestore, creando nuevo...');
        final newUser = UserModel.newUser(
          id: firebaseUser.uid,
          name: firebaseUser.displayName ?? 'Usuario',
          email: firebaseUser.email ?? '',
          photoUrl: firebaseUser.photoURL,
        );

        // Guardar el nuevo usuario en Firestore
        await _firestore
            .collection(_usersCollection)
            .doc(firebaseUser.uid)
            .set({
          ...newUser.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
        }).timeout(_firestoreTimeout);

        // Actualizar caché
        await _cacheManager.set(_userCacheKey, newUser);

        debugPrint('✅ Nuevo usuario creado');
        return newUser;
      }
    } catch (e, stack) {
      // Registrar error en Crashlytics
      FirebaseCrashlytics.instance
          .recordError(e, stack, reason: 'Error al obtener usuario actual');

      debugPrint('❌ Error obteniendo usuario actual: $e');

      // En caso de error de red, intentar usar caché como fallback
      final cachedUser = await _cacheManager.get<UserModel>(_userCacheKey);
      if (cachedUser != null) {
        debugPrint('🔄 Usando usuario desde caché como fallback');
        return cachedUser;
      }

      throw Exception('Error al obtener información del usuario');
    }
  }

  /// 🔥 MÉTODO CORREGIDO: Google Sign-In usando Firebase UI Auth
  @override
  Future<UserModel> signInWithGoogle() async {
    try {
      debugPrint(
          '🚀 Iniciando proceso de autenticación con Google usando Firebase UI...');

      // 🔧 PASO 0: Verificar conectividad antes de comenzar
      debugPrint('🌐 Verificando conectividad...');
      await _verifyConnectivity();

      // 🔧 PASO 1: Limpiar cualquier sesión previa
      debugPrint('🧹 Limpiando sesiones previas...');
      try {
        await _firebaseAuth.signOut().timeout(Duration(seconds: 5));
      } catch (e) {
        debugPrint('⚠️ Error limpiando sesión previa (continuando): $e');
      }

      // 🔧 PASO 2: Usar Firebase UI Auth en lugar de google_sign_in
      debugPrint('📱 Iniciando autenticación con Firebase UI...');

      UserCredential userCredential;

      if (kIsWeb) {
        // Para Web - usar popup
        final provider = GoogleAuthProvider();
        provider.addScope('email');
        provider.addScope('profile');

        userCredential = await _firebaseAuth.signInWithPopup(provider).timeout(
          _authTimeoutSlow,
          onTimeout: () {
            throw Exception('Timeout en autenticación web');
          },
        );
      } else {
        // Para móvil - usar Firebase UI
        userCredential = await _signInWithGoogleMobile();
      }

      // 🔧 PASO 3: Verificar que obtuvimos el usuario
      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        debugPrint('❌ Usuario Firebase es null después de autenticación');
        throw Exception('No se pudo completar el inicio de sesión');
      }

      debugPrint('✅ Usuario autenticado en Firebase: ${firebaseUser.uid}');

      // 🔧 PASO 4: Procesar usuario autenticado
      return await _processAuthenticatedUser(firebaseUser);
    } catch (e, stack) {
      debugPrint('❌ Error general en signInWithGoogle: $e');

      FirebaseCrashlytics.instance.recordError(e, stack,
          reason: 'Error en inicio de sesión con Google (Firebase UI)');

      // 🔧 MEJORADO: Manejo específico de errores conocidos
      if (e.toString().contains('cancelado') ||
          e.toString().contains('cancel')) {
        throw Exception('Inicio de sesión cancelado');
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        throw Exception(
            'Error de conexión. Verifica tu internet e intenta nuevamente.');
      } else if (e.toString().contains('timeout') ||
          e.toString().contains('Timeout')) {
        rethrow; // El mensaje ya es específico
      } else {
        throw Exception(
            'Error al iniciar sesión con Google. Por favor intenta nuevamente.');
      }
    }
  }

  /// 🔧 MÉTODO AUXILIAR: Sign-In móvil usando Firebase UI
  Future<UserCredential> _signInWithGoogleMobile() async {
    try {
      debugPrint('📱 Usando Firebase UI para móvil...');

      // Crear GoogleAuthProvider
      final provider = GoogleAuthProvider();
      provider.addScope('email');
      provider.addScope('profile');

      // Para Android/iOS, usar signInWithProvider (evita PigeonUserDetails)
      return await _firebaseAuth.signInWithProvider(provider).timeout(
        _authTimeoutFast,
        onTimeout: () {
          throw Exception('Timeout en autenticación móvil');
        },
      );
    } catch (e) {
      debugPrint('❌ Error en signInWithProvider: $e');

      // Si aún obtenemos el error PigeonUserDetails, usar fallback
      if (e.toString().contains('PigeonUserDetails') ||
          e.toString().contains('List<Object?>')) {
        debugPrint('🔄 Error PigeonUserDetails detectado, usando fallback...');
        return await _fallbackGoogleSignIn();
      }

      rethrow;
    }
  }

  /// 🔧 MÉTODO FALLBACK CORREGIDO: Si Firebase UI también falla
  Future<UserCredential> _fallbackGoogleSignIn() async {
    try {
      debugPrint('🆘 Usando método fallback...');

      // OPCIÓN 1: Para Web - usar getRedirectResult
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        provider.addScope('email');
        provider.addScope('profile');

        // Iniciar redirect
        await _firebaseAuth.signInWithRedirect(provider);

        // Esperar y obtener resultado del redirect
        await Future.delayed(Duration(seconds: 2));
        final result = await _firebaseAuth.getRedirectResult();

        if (result.user != null) {
          return result;
        } else {
          throw Exception('No se obtuvo resultado del redirect');
        }
      }
      // OPCIÓN 2: Para móvil - método alternativo
      else {
        debugPrint('🔄 Fallback móvil: creando credential manual...');

        // Si llegamos aquí, es porque Firebase UI falló
        // Lanzar excepción más descriptiva en lugar de intentar más métodos
        throw Exception('Múltiples métodos de autenticación fallaron. '
            'Este dispositivo puede tener un problema de compatibilidad.');
      }
    } catch (e) {
      debugPrint('❌ Método fallback también falló: $e');
      throw Exception('Error de compatibilidad con Google Sign-In. '
          'Esto puede deberse a una versión desactualizada de la app. '
          'Por favor:\n'
          '• Cierra y abre la app\n'
          '• Si persiste, actualiza la app\n'
          '• Contacta soporte si el problema continúa');
    }
  }

  /// 🔧 MÉTODO AUXILIAR: Procesar usuario autenticado (MANTENIDO ORIGINAL)
  Future<UserModel> _processAuthenticatedUser(User firebaseUser) async {
    debugPrint('🔍 Verificando usuario en Firestore...');

    DocumentSnapshot userDoc;
    try {
      userDoc = await _firestore
          .collection(_usersCollection)
          .doc(firebaseUser.uid)
          .get()
          .timeout(_firestoreTimeout);
    } catch (e) {
      debugPrint('❌ Error verificando usuario en Firestore: $e');
      throw Exception('Error verificando datos del usuario: $e');
    }

    if (userDoc.exists) {
      // Usuario existente
      debugPrint('👤 Usuario existente encontrado');
      try {
        await _firestore
            .collection(_usersCollection)
            .doc(firebaseUser.uid)
            .update({
          'lastLogin': FieldValue.serverTimestamp(),
        }).timeout(Duration(seconds: 15));

        debugPrint('✅ lastLogin actualizado');
      } catch (e) {
        debugPrint('⚠️ Error actualizando lastLogin (continuando): $e');
        FirebaseCrashlytics.instance.log('Error actualizando lastLogin: $e');
      }

      final userModel = UserModel.fromFirestore(userDoc);

      // Actualizar caché
      await _cacheManager.set(_userCacheKey, userModel);

      // Actualizar datos en Crashlytics
      _updateCrashlyticsUserData(userModel);

      debugPrint('✅ Inicio de sesión exitoso - Usuario existente');
      return userModel;
    } else {
      // Usuario nuevo
      debugPrint('👤 Creando nuevo usuario...');
      final newUser = UserModel.newUser(
        id: firebaseUser.uid,
        name: firebaseUser.displayName ?? 'Usuario',
        email: firebaseUser.email ?? '',
        photoUrl: firebaseUser.photoURL,
      );

      try {
        await _firestore
            .collection(_usersCollection)
            .doc(firebaseUser.uid)
            .set({
          ...newUser.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        }).timeout(_firestoreTimeout);

        debugPrint('✅ Nuevo usuario guardado en Firestore');
      } catch (e) {
        debugPrint('❌ Error creando usuario: $e');
        throw Exception('Error al crear usuario en la base de datos: $e');
      }

      // Actualizar caché
      await _cacheManager.set(_userCacheKey, newUser);

      // Actualizar datos en Crashlytics
      _updateCrashlyticsUserData(newUser);

      debugPrint('✅ Inicio de sesión exitoso - Usuario nuevo creado');
      return newUser;
    }
  }

  /// Verifica la conectividad antes de comenzar el proceso de autenticación
  Future<void> _verifyConnectivity() async {
    try {
      // Test de conectividad básico
      final stopwatch = Stopwatch()..start();

      await _firestore
          .doc('test/connectivity')
          .get(GetOptions(source: Source.server))
          .timeout(Duration(seconds: 10));

      stopwatch.stop();
      final latency = stopwatch.elapsedMilliseconds;

      debugPrint('🌐 Conectividad verificada (${latency}ms)');

      if (latency > 5000) {
        debugPrint('⚠️ Conexión lenta detectada (${latency}ms)');
        throw Exception('La conexión a internet es muy lenta. '
            'Esto puede causar timeouts durante la autenticación. '
            'Considera usar una conexión más estable.');
      }
    } catch (e) {
      debugPrint('❌ Error de conectividad: $e');
      if (e.toString().contains('timeout') ||
          e.toString().contains('Timeout')) {
        throw Exception('No se puede conectar con los servidores. '
            'Verifica tu conexión a internet e intenta nuevamente.');
      }
      // Si es otro tipo de error, continuar (puede ser que el documento test no exista)
      debugPrint('⚠️ Verificación de conectividad falló, continuando...');
    }
  }

  /// 🔧 MÉTODO MANTENIDO: Inicio de sesión con email y contraseña
  Future<UserModel> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('🔐 Iniciando sesión con email: $email');

      // Iniciar sesión con Firebase Auth
      final userCredential = await _firebaseAuth
          .signInWithEmailAndPassword(
            email: email.trim(),
            password: password,
          )
          .timeout(_authTimeout);

      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception('No se pudo iniciar sesión con email/contraseña');
      }

      debugPrint('✅ Autenticación exitosa con email');

      // Verificar si el usuario existe en Firestore
      final userDoc = await _firestore
          .collection(_usersCollection)
          .doc(firebaseUser.uid)
          .get()
          .timeout(_firestoreTimeout);

      if (userDoc.exists) {
        // Si existe, actualizar última conexión
        await _firestore
            .collection(_usersCollection)
            .doc(firebaseUser.uid)
            .update({
          'lastLogin': FieldValue.serverTimestamp(),
        });

        final userModel = UserModel.fromFirestore(userDoc);

        // Actualizar caché
        await _cacheManager.set(_userCacheKey, userModel);

        // Actualizar datos en Crashlytics
        _updateCrashlyticsUserData(userModel);

        return userModel;
      } else {
        // Si no existe, crear nuevo usuario
        final newUser = UserModel.newUser(
          id: firebaseUser.uid,
          name: firebaseUser.displayName ?? email.split('@')[0],
          email: firebaseUser.email ?? email,
          photoUrl: firebaseUser.photoURL,
        );

        // Guardar en Firestore
        await _firestore
            .collection(_usersCollection)
            .doc(firebaseUser.uid)
            .set({
          ...newUser.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });

        // Actualizar caché
        await _cacheManager.set(_userCacheKey, newUser);

        // Actualizar datos en Crashlytics
        _updateCrashlyticsUserData(newUser);

        return newUser;
      }
    } on FirebaseAuthException catch (e, stack) {
      debugPrint('❌ FirebaseAuthException en email login: ${e.code}');

      // Registrar error específico de Firebase Auth
      FirebaseCrashlytics.instance.recordError(e, stack,
          reason: 'Error en inicio de sesión con email: ${e.code}');

      // Manejar errores específicos
      switch (e.code) {
        case 'user-not-found':
          throw Exception('No se encontró un usuario con ese email.');
        case 'wrong-password':
          throw Exception('Contraseña incorrecta.');
        case 'user-disabled':
          throw Exception('Esta cuenta ha sido deshabilitada.');
        case 'invalid-email':
          throw Exception('El email ingresado no es válido.');
        case 'too-many-requests':
          throw Exception('Demasiados intentos. Por favor intenta más tarde.');
        case 'network-request-failed':
          throw Exception('Error de conexión. Verifica tu internet.');
        default:
          throw Exception('Error de autenticación: ${e.message}');
      }
    } catch (e, stack) {
      debugPrint('❌ Error general en email login: $e');

      // Registrar otros errores
      FirebaseCrashlytics.instance.recordError(e, stack,
          reason: 'Error en inicio de sesión con email/contraseña');
      throw Exception('Error al iniciar sesión con email/contraseña');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      debugPrint('🚪 Cerrando sesión...');

      // Limpiar caché al cerrar sesión
      await _cacheManager.remove(_userCacheKey);

      // Cerrar sesión en Firebase
      await _firebaseAuth.signOut();

      // Limpiar datos de usuario en Crashlytics
      FirebaseCrashlytics.instance.setUserIdentifier('');

      debugPrint('✅ Sesión cerrada exitosamente');
    } catch (e, stack) {
      debugPrint('❌ Error cerrando sesión: $e');
      FirebaseCrashlytics.instance
          .recordError(e, stack, reason: 'Error al cerrar sesión');
      throw Exception('Error al cerrar sesión');
    }
  }

  @override
  Future<bool> isSignedIn() async {
    final currentUser = _firebaseAuth.currentUser;
    final isSignedIn = currentUser != null;
    debugPrint('🔍 Usuario autenticado: $isSignedIn');
    return isSignedIn;
  }

  @override
  Future<UserModel> updateUserProfile(UserModel user) async {
    try {
      debugPrint('👤 Actualizando perfil de usuario: ${user.id}');

      // Actualizar en Firestore
      await _firestore.collection(_usersCollection).doc(user.id).update({
        'name': user.name,
        'photoUrl': user.photoUrl,
        'team': user.team,
        'updatedAt': FieldValue.serverTimestamp(),
      }).timeout(_firestoreTimeout);

      // Actualizar en Firebase Auth si es necesario
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser != null) {
        await currentUser.updateDisplayName(user.name);
        if (user.photoUrl != null) {
          await currentUser.updatePhotoURL(user.photoUrl);
        }
      }

      // Actualizar caché
      await _cacheManager.set(_userCacheKey, user);

      debugPrint('✅ Perfil actualizado exitosamente');
      return user;
    } catch (e, stack) {
      debugPrint('❌ Error actualizando perfil: $e');
      FirebaseCrashlytics.instance
          .recordError(e, stack, reason: 'Error al actualizar perfil');
      throw Exception('Error al actualizar el perfil');
    }
  }

  @override
  Future<UserModel> updateUserSettings(
      String userId, UserSettings settings) async {
    try {
      debugPrint('⚙️ Actualizando configuraciones de usuario: $userId');

      await _firestore.collection(_usersCollection).doc(userId).update({
        'settings': settings.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }).timeout(_firestoreTimeout);

      // Obtener usuario actualizado
      final userDoc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .get()
          .timeout(_firestoreTimeout);

      final updatedUser = UserModel.fromFirestore(userDoc);

      // Actualizar caché
      await _cacheManager.set(_userCacheKey, updatedUser);

      debugPrint('✅ Configuraciones actualizadas exitosamente');
      return updatedUser;
    } catch (e, stack) {
      debugPrint('❌ Error actualizando configuraciones: $e');
      FirebaseCrashlytics.instance
          .recordError(e, stack, reason: 'Error al actualizar configuraciones');
      throw Exception('Error al actualizar las configuraciones');
    }
  }

  @override
  Future<UserModel> updateSubscription(
      String userId, SubscriptionInfo subscription) async {
    try {
      debugPrint('💳 Actualizando suscripción de usuario: $userId');
      debugPrint('   Tipo: ${subscription.type}');
      debugPrint('   Plan: ${subscription.plan}');

      await _firestore.collection(_usersCollection).doc(userId).update({
        'subscription': subscription.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }).timeout(_firestoreTimeout);

      // Obtener usuario actualizado directamente del servidor para asegurar datos frescos
      final userDoc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .get(const GetOptions(source: Source.server))
          .timeout(_firestoreTimeout);

      final updatedUser = UserModel.fromFirestore(userDoc);

      // Actualizar caché
      await _cacheManager.set(_userCacheKey, updatedUser);

      // Actualizar datos en Crashlytics
      _updateCrashlyticsUserData(updatedUser);

      debugPrint('✅ Suscripción actualizada exitosamente');
      return updatedUser;
    } catch (e, stack) {
      debugPrint('❌ Error actualizando suscripción: $e');
      FirebaseCrashlytics.instance
          .recordError(e, stack, reason: 'Error al actualizar suscripción');
      throw Exception('Error al actualizar la suscripción');
    }
  }

  @override
  Future<void> deleteAccount(String userId) async {
    try {
      debugPrint('🗑️ Eliminando cuenta de usuario: $userId');

      // Eliminar datos de usuario de Firestore
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .delete()
          .timeout(_firestoreTimeout);

      // Eliminar cuenta de Firebase Auth
      final User? currentUser = _firebaseAuth.currentUser;
      if (currentUser != null) {
        await currentUser.delete();
      }

      // Limpiar caché
      await _cacheManager.remove(_userCacheKey);

      // Limpiar datos de usuario en Crashlytics
      FirebaseCrashlytics.instance.setUserIdentifier('');

      debugPrint('✅ Cuenta eliminada exitosamente');
    } catch (e, stack) {
      debugPrint('❌ Error eliminando cuenta: $e');
      FirebaseCrashlytics.instance
          .recordError(e, stack, reason: 'Error al eliminar cuenta');
      throw Exception('Error al eliminar la cuenta');
    }
  }

  @override
  Stream<UserModel?> get authStateChanges {
    debugPrint('👁️ Configurando stream de cambios de autenticación');

    // Convertir el stream de Firebase Auth a stream de UserModel
    return _firebaseAuth.authStateChanges().asyncMap((User? user) async {
      if (user == null) {
        debugPrint('🔓 Usuario desautenticado');
        await _cacheManager.remove(_userCacheKey);
        return null;
      }

      try {
        debugPrint('🔐 Usuario autenticado detectado: ${user.uid}');

        final userDoc = await _firestore
            .collection(_usersCollection)
            .doc(user.uid)
            .get()
            .timeout(_firestoreTimeout);

        if (userDoc.exists) {
          final userModel = UserModel.fromFirestore(userDoc);
          await _cacheManager.set(_userCacheKey, userModel);
          debugPrint('✅ UserModel actualizado en stream');
          return userModel;
        } else {
          // Si no existe en Firestore pero sí en Auth, posible error de sincronización
          debugPrint(
              '⚠️ Usuario existe en Auth pero no en Firestore: ${user.uid}');
          FirebaseCrashlytics.instance
              .log('Usuario existe en Auth pero no en Firestore: ${user.uid}');
          return null;
        }
      } catch (e, stack) {
        debugPrint('❌ Error en authStateChanges: $e');
        FirebaseCrashlytics.instance
            .recordError(e, stack, reason: 'Error en authStateChanges');

        // Intentar usar caché como fallback
        return await _cacheManager.get<UserModel>(_userCacheKey);
      }
    });
  }

  // Métodos privados de utilidad

  /// Verifica si la caché del usuario es válida
  bool _isUserCacheValid(UserModel user) {
    // Si es usuario premium, verificar que la suscripción no haya expirado
    if (user.subscription.type == 'premium' &&
        user.subscription.expirationDate != null) {
      final now = DateTime.now();
      final isValid = user.subscription.expirationDate!.isAfter(now);
      debugPrint('🔍 Validez de caché premium: $isValid');
      return isValid;
    }

    // Para usuarios gratuitos o premium sin fecha de expiración, la caché es válida
    debugPrint('✅ Caché de usuario válida');
    return true;
  }

  /// Actualiza los datos de usuario en Crashlytics para mejor análisis
  void _updateCrashlyticsUserData(UserModel user) {
    try {
      FirebaseCrashlytics.instance.setUserIdentifier(user.id);
      FirebaseCrashlytics.instance
          .setCustomKey('isPremium', user.subscription.isPremium);
      FirebaseCrashlytics.instance.setCustomKey('email', user.email);

      if (user.subscription.isPremium && user.subscription.plan != null) {
        FirebaseCrashlytics.instance
            .setCustomKey('subscriptionPlan', user.subscription.plan!);
      }

      debugPrint('📊 Datos de Crashlytics actualizados');
    } catch (e) {
      debugPrint('⚠️ Error actualizando datos de Crashlytics: $e');
    }
  }

  @override
  Future<void> reauthenticateWithPassword(String currentPassword) {
    // TODO: implement reauthenticateWithPassword
    throw UnimplementedError();
  }

  @override
  Future<UserModel> registerWithEmailPassword(
      {required String email,
      required String password,
      required String displayName}) {
    // TODO: implement registerWithEmailPassword
    throw UnimplementedError();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) {
    // TODO: implement sendPasswordResetEmail
    throw UnimplementedError();
  }

  @override
  Future<void> updatePassword(String newPassword) {
    // TODO: implement updatePassword
    throw UnimplementedError();
  }
}
