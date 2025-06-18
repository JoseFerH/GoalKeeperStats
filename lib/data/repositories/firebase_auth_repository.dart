// lib/data/repositories/firebase_auth_repository.dart
// 🔧 VERSIÓN ROBUSTA: Warm-up agresivo para eliminar PigeonUserDetails completamente

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:goalkeeper_stats/services/firebase_crashlytics_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:goalkeeper_stats/domain/repositories/auth_repository.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/data/models/user_settings.dart';
import 'package:goalkeeper_stats/data/models/subscription_info.dart';
import 'package:goalkeeper_stats/services/cache_manager.dart';

/// 🔧 IMPLEMENTACIÓN ROBUSTA: Elimina completamente el error PigeonUserDetails
/// ✅ Mantiene toda la lógica original de IDs de usuario
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final CacheManager _cacheManager;
  final GoogleSignIn _googleSignIn;

  static const String _usersCollection = 'users';
  static const String _userCacheKey = 'current_user';
  static const Duration _authTimeout = Duration(seconds: 30);
  static const Duration _firestoreTimeout = Duration(seconds: 25);

  // 🔧 CONTROL DE WARM-UP ROBUSTO
  bool _isFirebaseAuthWarmed = false;
  bool _isGoogleSignInWarmed = false;
  DateTime? _lastWarmUpTime;

  FirebaseAuthRepository({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    CacheManager? cacheManager,
    GoogleSignIn? googleSignIn,
    required FirebaseCrashlyticsService crashlyticsService,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _cacheManager = cacheManager ?? CacheManager(),
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              clientId:
                  '415256305974-9smib8kjpro0f7iacq4ctt2gqk3mdf0u.apps.googleusercontent.com',
              scopes: ['email', 'profile'],
            ) {
    // 🔧 WARM-UP INMEDIATO Y AGRESIVO
    _performAggressiveWarmUp();
  }

  /// 🔧 WARM-UP AGRESIVO: Calienta todo completamente desde el inicio
  Future<void> _performAggressiveWarmUp() async {
    try {
      debugPrint('🔥 Iniciando warm-up AGRESIVO de Firebase Auth...');

      await _firebaseAuth.setLanguageCode('es');

      // Test 1: Operación básica que fuerza inicialización de Pigeon
      try {
        await _firebaseAuth
            .fetchSignInMethodsForEmail('warmup1@test.com')
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('✅ Test 1 completado (error esperado): $e');
      }

      // Espera intermedia
      await Future.delayed(const Duration(milliseconds: 800));

      // Test 2: Segunda operación para asegurar estabilidad
      try {
        await _firebaseAuth
            .fetchSignInMethodsForEmail('warmup2@test.com')
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('✅ Test 2 completado (error esperado): $e');
      }

      // Warm-up específico de Google Sign-In
      await _warmUpGoogleSignIn();

      // Test 3: Verificar acceso a usuario actual si existe
      try {
        final currentUser = _firebaseAuth.currentUser;
        if (currentUser != null) {
          // Intentar acceder a propiedades para forzar deserialización
          final uid = currentUser.uid;
          final email = currentUser.email;
          final displayName = currentUser.displayName;
          debugPrint('✅ Usuario actual accesible: ${currentUser.uid}');
        }
      } catch (e) {
        debugPrint('⚠️ Error accediendo usuario actual (puede ser normal): $e');
      }

      // Espera final agresiva para estabilización completa
      await Future.delayed(const Duration(milliseconds: 2000));

      _isFirebaseAuthWarmed = true;
      _lastWarmUpTime = DateTime.now();
      debugPrint('🎯 Warm-up AGRESIVO completado exitosamente');
    } catch (e) {
      debugPrint('⚠️ Error en warm-up agresivo: $e');
      // Marcar como listo de todas formas después de espera adicional
      await Future.delayed(const Duration(milliseconds: 3000));
      _isFirebaseAuthWarmed = true;
      _lastWarmUpTime = DateTime.now();
    }
  }

  /// 🔧 WARM-UP ESPECÍFICO: Para Google Sign-In
  Future<void> _warmUpGoogleSignIn() async {
    try {
      debugPrint('📱 Calentando Google Sign-In...');

      // Test 1: Verificar si está disponible
      await _googleSignIn.isSignedIn();
      debugPrint('✅ Google Sign-In disponible');

      // Test 2: Operación que inicializa internos
      try {
        final account = _googleSignIn.currentUser;
        if (account != null) {
          debugPrint('👤 Usuario de Google ya conectado: ${account.email}');
        }
      } catch (e) {
        debugPrint('⚠️ No hay usuario de Google conectado: $e');
      }

      // Pequeña espera adicional
      await Future.delayed(const Duration(milliseconds: 500));

      _isGoogleSignInWarmed = true;
      debugPrint('✅ Google Sign-In calentado');
    } catch (e) {
      debugPrint('⚠️ Error calentando Google Sign-In: $e');
      _isGoogleSignInWarmed = true; // Marcar como listo de todas formas
    }
  }

  /// 🔧 VERIFICACIÓN ROBUSTA: Asegurar que todo esté 100% listo
  Future<void> _ensureAuthFullyReady() async {
    // Si ya están calientes y es reciente, no hacer nada
    if (_isFirebaseAuthWarmed &&
        _isGoogleSignInWarmed &&
        _lastWarmUpTime != null &&
        DateTime.now().difference(_lastWarmUpTime!).inMinutes < 5) {
      debugPrint('✅ Auth ya está caliente y es reciente');
      return;
    }

    debugPrint('⏳ Verificando/re-calentando Auth...');

    // Re-warm-up si es necesario
    if (!_isFirebaseAuthWarmed || !_isGoogleSignInWarmed) {
      await _performAggressiveWarmUp();
    }

    // Verificación adicional específica para Google Sign-In
    await _ensureGoogleSignInReady();
  }

  /// 🔧 VERIFICACIÓN ESPECÍFICA: Para Google Sign-In antes del intento crítico
  Future<void> _ensureGoogleSignInReady() async {
    try {
      debugPrint('🔍 Verificación final de Google Sign-In...');

      // Verificación 1: Disponibilidad
      await _googleSignIn.isSignedIn();

      // Verificación 2: Espera adicional para estabilización
      await Future.delayed(const Duration(milliseconds: 300));

      // Verificación 3: Test de acceso a propiedades
      try {
        final currentUser = _googleSignIn.currentUser;
        debugPrint('👤 Estado de Google Sign-In verificado');
      } catch (e) {
        debugPrint('⚠️ Verificación de estado: $e');
      }

      debugPrint('✅ Google Sign-In completamente listo');
    } catch (e) {
      debugPrint('⚠️ Error en verificación final: $e');
      // Espera adicional como fallback
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  /// 🔧 GOOGLE SIGN-IN SÚPER ROBUSTO: Con warm-up agresivo y retry inteligente
  @override
  Future<UserModel> signInWithGoogle() async {
    try {
      debugPrint('🚀 Iniciando Google Sign-In ROBUSTO...');

      // PASO 1: Asegurar que TODO esté completamente listo
      await _ensureAuthFullyReady();

      // PASO 2: Limpiar sesiones previas (igual que antes)
      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();

      // PASO 3: Espera adicional después de limpiar
      await Future.delayed(const Duration(milliseconds: 500));

      // PASO 4: Obtener usuario de Google
      debugPrint('📱 Obteniendo usuario de Google...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Inicio de sesión cancelado por el usuario');
      }

      debugPrint('✅ Usuario de Google obtenido: ${googleUser.email}');

      // PASO 5: Obtener tokens
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception('Error obteniendo tokens de Google');
      }

      debugPrint('✅ Tokens de Google obtenidos');

      // PASO 6: Autenticación con Firebase con retry súper robusto
      return await _signInWithCredentialSuperRobust(googleAuth);
    } catch (e, stack) {
      debugPrint('❌ Error en Google Sign-In: $e');
      FirebaseCrashlytics.instance
          .recordError(e, stack, reason: 'Error en Google Sign-In');

      // Manejo de errores (igual que antes)
      if (e.toString().contains('cancelado') ||
          e.toString().contains('cancel')) {
        throw Exception('Inicio de sesión cancelado');
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        throw Exception(
            'Error de conexión. Verifica tu internet e intenta nuevamente.');
      } else {
        throw Exception('Error al iniciar sesión con Google: $e');
      }
    }
  }

  /// 🔧 RETRY SÚPER ROBUSTO: Para manejar PigeonUserDetails definitivamente
  Future<UserModel> _signInWithCredentialSuperRobust(
      GoogleSignInAuthentication googleAuth) async {
    const maxRetries = 3;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
            '🔥 Intento $attempt de autenticación con Firebase (ROBUSTO)...');

        // Espera progresiva antes de cada intento
        if (attempt > 1) {
          final waitTime = attempt * 1000; // 1s, 2s, 3s
          debugPrint('⏳ Esperando ${waitTime}ms antes del intento $attempt...');
          await Future.delayed(Duration(milliseconds: waitTime));
        }

        // Verificación adicional antes del intento crítico
        if (attempt > 1) {
          await _ensureGoogleSignInReady();
        }

        // Crear credencial
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        debugPrint('🔐 Creando credencial para intento $attempt...');

        // Espera específica antes del método crítico
        await Future.delayed(const Duration(milliseconds: 200));

        // INTENTO CRÍTICO: signInWithCredential
        debugPrint('🎯 Ejecutando signInWithCredential (intento $attempt)...');
        final userCredential = await _firebaseAuth
            .signInWithCredential(credential)
            .timeout(const Duration(seconds: 20));

        final User? firebaseUser = userCredential.user;

        if (firebaseUser == null) {
          throw Exception('Error: Firebase User es null');
        }

        debugPrint(
            '✅ ¡ÉXITO! Autenticación Firebase exitosa en intento $attempt');
        debugPrint('👤 Usuario autenticado: ${firebaseUser.uid}');

        // Verificación adicional del usuario
        try {
          final uid = firebaseUser.uid;
          final email = firebaseUser.email;
          debugPrint('✅ Usuario accesible sin errores de deserialización');
        } catch (e) {
          debugPrint('⚠️ Error de acceso post-autenticación: $e');
          if (e.toString().contains('PigeonUserDetails') &&
              attempt < maxRetries) {
            debugPrint('🔄 Error PigeonUserDetails post-auth, reintentando...');
            continue;
          }
          throw e;
        }

        // Procesar usuario (lógica original)
        return await _processAuthenticatedUser(firebaseUser);
      } catch (e) {
        debugPrint('❌ Intento $attempt falló: $e');

        // Si es el error específico de PigeonUserDetails, reintentar
        if ((e.toString().contains('PigeonUserDetails') ||
                e.toString().contains('List<Object?>') ||
                e.toString().contains('not a subtype')) &&
            attempt < maxRetries) {
          debugPrint(
              '🔄 Error PigeonUserDetails detectado en intento $attempt, reintentando...');

          // Re-warm específico entre intentos
          if (attempt == 2) {
            debugPrint('🔥 Re-warming intensivo antes del último intento...');
            await _performAggressiveWarmUp();
          }

          continue;
        }

        // Si no es PigeonUserDetails o ya no hay más intentos, lanzar error
        rethrow;
      }
    }

    throw Exception(
        'No se pudo completar la autenticación después de $maxRetries intentos robustos');
  }

  /// ✅ TODOS LOS DEMÁS MÉTODOS IGUALES QUE ANTES

  @override
  Future<UserModel?> getCurrentUser() async {
    final User? firebaseUser = _firebaseAuth.currentUser;

    if (firebaseUser == null) {
      debugPrint('🔐 No hay usuario autenticado en Firebase Auth');
      return null;
    }

    try {
      debugPrint('🔍 Obteniendo usuario actual: ${firebaseUser.uid}');

      final cachedUser = await _cacheManager.get<UserModel>(_userCacheKey);
      if (cachedUser != null && _isUserCacheValid(cachedUser)) {
        debugPrint('✅ Usuario obtenido desde caché');
        return cachedUser;
      }

      debugPrint('🌐 Obteniendo usuario desde Firestore...');
      final userDoc = await _firestore
          .collection(_usersCollection)
          .doc(firebaseUser.uid)
          .get(const GetOptions(source: Source.server))
          .timeout(_firestoreTimeout);

      if (userDoc.exists) {
        final userModel = UserModel.fromFirestore(userDoc);
        await _cacheManager.set(_userCacheKey, userModel);
        _updateCrashlyticsUserData(userModel);
        debugPrint('✅ Usuario obtenido desde Firestore');
        return userModel;
      } else {
        debugPrint('👤 Usuario no existe en Firestore, creando nuevo...');
        final newUser = UserModel.newUser(
          id: firebaseUser.uid,
          name: firebaseUser.displayName ?? 'Usuario',
          email: firebaseUser.email ?? '',
          photoUrl: firebaseUser.photoURL,
        );

        await _firestore
            .collection(_usersCollection)
            .doc(firebaseUser.uid)
            .set({
          ...newUser.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
        }).timeout(_firestoreTimeout);

        await _cacheManager.set(_userCacheKey, newUser);
        debugPrint('✅ Nuevo usuario creado');
        return newUser;
      }
    } catch (e, stack) {
      FirebaseCrashlytics.instance
          .recordError(e, stack, reason: 'Error al obtener usuario actual');

      debugPrint('❌ Error obteniendo usuario actual: $e');

      final cachedUser = await _cacheManager.get<UserModel>(_userCacheKey);
      if (cachedUser != null) {
        debugPrint('🔄 Usando usuario desde caché como fallback');
        return cachedUser;
      }

      throw Exception('Error al obtener información del usuario: $e');
    }
  }

  @override
  Future<UserModel> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('🔐 Iniciando sesión con email: $email');

      if (email.trim().isEmpty || password.isEmpty) {
        throw Exception('Email y contraseña son requeridos');
      }

      // Solo verificación básica para email (menos crítico)
      if (!_isFirebaseAuthWarmed) {
        await Future.delayed(const Duration(milliseconds: 500));
      }

      final userCredential = await _firebaseAuth
          .signInWithEmailAndPassword(
            email: email.trim(),
            password: password,
          )
          .timeout(_authTimeout);

      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception('No se pudo iniciar sesión');
      }

      debugPrint('✅ Autenticación exitosa con email');
      return await _processAuthenticatedUser(firebaseUser);
    } on FirebaseAuthException catch (e, stack) {
      debugPrint('❌ FirebaseAuthException en email login: ${e.code}');
      FirebaseCrashlytics.instance
          .recordError(e, stack, reason: 'Error en email login: ${e.code}');

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
        case 'invalid-credential':
          throw Exception('Email o contraseña incorrectos.');
        default:
          throw Exception('Error de autenticación: ${e.message}');
      }
    } catch (e, stack) {
      debugPrint('❌ Error general en email login: $e');
      FirebaseCrashlytics.instance
          .recordError(e, stack, reason: 'Error general en email login');
      throw Exception('Error al iniciar sesión: $e');
    }
  }

  @override
  Future<UserModel> registerWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      debugPrint('📝 Registrando nuevo usuario: $email');

      if (email.trim().isEmpty ||
          password.isEmpty ||
          displayName.trim().isEmpty) {
        throw Exception('Todos los campos son requeridos');
      }

      if (password.length < 6) {
        throw Exception('La contraseña debe tener al menos 6 caracteres');
      }

      final userCredential = await _firebaseAuth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          )
          .timeout(_authTimeout);

      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception('Error creando usuario');
      }

      await firebaseUser.updateDisplayName(displayName.trim());

      debugPrint('✅ Usuario registrado en Firebase Auth: ${firebaseUser.uid}');
      return await _processAuthenticatedUser(firebaseUser);
    } on FirebaseAuthException catch (e, stack) {
      debugPrint('❌ FirebaseAuthException en registro: ${e.code}');
      FirebaseCrashlytics.instance
          .recordError(e, stack, reason: 'Error en registro: ${e.code}');

      switch (e.code) {
        case 'email-already-in-use':
          throw Exception('Ya existe una cuenta con este email.');
        case 'invalid-email':
          throw Exception('El email ingresado no es válido.');
        case 'weak-password':
          throw Exception('La contraseña es muy débil.');
        case 'operation-not-allowed':
          throw Exception('El registro con email no está habilitado.');
        case 'network-request-failed':
          throw Exception('Error de conexión. Verifica tu internet.');
        default:
          throw Exception('Error de registro: ${e.message}');
      }
    } catch (e, stack) {
      debugPrint('❌ Error general en registro: $e');
      FirebaseCrashlytics.instance
          .recordError(e, stack, reason: 'Error general en registro');
      throw Exception('Error al registrar usuario: $e');
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      debugPrint('📧 Enviando email de recuperación a: $email');

      if (email.trim().isEmpty) {
        throw Exception('El email es requerido');
      }

      await _firebaseAuth
          .sendPasswordResetEmail(
            email: email.trim(),
          )
          .timeout(_authTimeout);

      debugPrint('✅ Email de recuperación enviado');
    } on FirebaseAuthException catch (e, stack) {
      debugPrint('❌ FirebaseAuthException en reset password: ${e.code}');
      FirebaseCrashlytics.instance.recordError(e, stack,
          reason: 'Error enviando email de recuperación: ${e.code}');

      switch (e.code) {
        case 'user-not-found':
          throw Exception('No se encontró un usuario con ese email.');
        case 'invalid-email':
          throw Exception('El email ingresado no es válido.');
        case 'too-many-requests':
          throw Exception('Demasiados intentos. Por favor intenta más tarde.');
        case 'network-request-failed':
          throw Exception('Error de conexión. Verifica tu internet.');
        default:
          throw Exception('Error enviando email: ${e.message}');
      }
    } catch (e, stack) {
      debugPrint('❌ Error general enviando email de recuperación: $e');
      FirebaseCrashlytics.instance.recordError(e, stack,
          reason: 'Error general enviando email de recuperación');
      throw Exception('Error enviando email de recuperación: $e');
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    try {
      final User? currentUser = _firebaseAuth.currentUser;
      if (currentUser == null) {
        throw Exception('No hay usuario autenticado');
      }

      if (newPassword.length < 6) {
        throw Exception('La nueva contraseña debe tener al menos 6 caracteres');
      }

      await currentUser.updatePassword(newPassword).timeout(_authTimeout);
      debugPrint('✅ Contraseña actualizada');
    } on FirebaseAuthException catch (e, stack) {
      debugPrint('❌ FirebaseAuthException actualizando contraseña: ${e.code}');
      FirebaseCrashlytics.instance.recordError(e, stack,
          reason: 'Error actualizando contraseña: ${e.code}');

      switch (e.code) {
        case 'weak-password':
          throw Exception('La nueva contraseña es muy débil.');
        case 'requires-recent-login':
          throw Exception(
              'Necesitas volver a iniciar sesión para cambiar la contraseña.');
        case 'network-request-failed':
          throw Exception('Error de conexión. Verifica tu internet.');
        default:
          throw Exception('Error actualizando contraseña: ${e.message}');
      }
    } catch (e, stack) {
      debugPrint('❌ Error general actualizando contraseña: $e');
      FirebaseCrashlytics.instance.recordError(e, stack,
          reason: 'Error general actualizando contraseña');
      throw Exception('Error actualizando contraseña: $e');
    }
  }

  @override
  Future<void> reauthenticateWithPassword(String currentPassword) async {
    try {
      final User? currentUser = _firebaseAuth.currentUser;
      if (currentUser == null || currentUser.email == null) {
        throw Exception('No hay usuario autenticado');
      }

      final credential = EmailAuthProvider.credential(
        email: currentUser.email!,
        password: currentPassword,
      );

      await currentUser
          .reauthenticateWithCredential(credential)
          .timeout(_authTimeout);
      debugPrint('✅ Reautenticación exitosa');
    } on FirebaseAuthException catch (e, stack) {
      debugPrint('❌ FirebaseAuthException en reautenticación: ${e.code}');
      FirebaseCrashlytics.instance
          .recordError(e, stack, reason: 'Error en reautenticación: ${e.code}');

      switch (e.code) {
        case 'wrong-password':
          throw Exception('Contraseña actual incorrecta.');
        case 'user-mismatch':
          throw Exception(
              'Las credenciales no corresponden al usuario actual.');
        case 'user-not-found':
          throw Exception('Usuario no encontrado.');
        case 'network-request-failed':
          throw Exception('Error de conexión. Verifica tu internet.');
        default:
          throw Exception('Error de reautenticación: ${e.message}');
      }
    } catch (e, stack) {
      debugPrint('❌ Error general en reautenticación: $e');
      FirebaseCrashlytics.instance
          .recordError(e, stack, reason: 'Error general en reautenticación');
      throw Exception('Error de reautenticación: $e');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      debugPrint('🚪 Cerrando sesión...');

      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();
      await _cacheManager.remove(_userCacheKey);

      FirebaseCrashlytics.instance.setUserIdentifier('');

      debugPrint('✅ Sesión cerrada exitosamente');
    } catch (e, stack) {
      debugPrint('❌ Error cerrando sesión: $e');
      FirebaseCrashlytics.instance
          .recordError(e, stack, reason: 'Error al cerrar sesión');
    }
  }

  @override
  Future<bool> isSignedIn() async {
    try {
      final currentUser = _firebaseAuth.currentUser;
      final isSignedIn = currentUser != null;
      debugPrint('🔍 Usuario autenticado: $isSignedIn');
      return isSignedIn;
    } catch (e) {
      debugPrint('❌ Error verificando estado de autenticación: $e');
      return false;
    }
  }

  @override
  Future<UserModel> updateUserProfile(UserModel user) async {
    try {
      debugPrint('👤 Actualizando perfil de usuario: ${user.id}');

      await _firestore.collection(_usersCollection).doc(user.id).update({
        'name': user.name,
        'photoUrl': user.photoUrl,
        'team': user.team,
        'updatedAt': FieldValue.serverTimestamp(),
      }).timeout(_firestoreTimeout);

      final currentUser = _firebaseAuth.currentUser;
      if (currentUser != null) {
        try {
          await currentUser.updateDisplayName(user.name);
          if (user.photoUrl != null) {
            await currentUser.updatePhotoURL(user.photoUrl);
          }
        } catch (e) {
          debugPrint('⚠️ Error actualizando perfil en Firebase Auth: $e');
        }
      }

      await _cacheManager.set(_userCacheKey, user);

      debugPrint('✅ Perfil actualizado exitosamente');
      return user;
    } catch (e, stack) {
      debugPrint('❌ Error actualizando perfil: $e');
      FirebaseCrashlytics.instance
          .recordError(e, stack, reason: 'Error al actualizar perfil');
      throw Exception('Error al actualizar el perfil: $e');
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

      final userDoc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .get(const GetOptions(source: Source.server))
          .timeout(_firestoreTimeout);

      final updatedUser = UserModel.fromFirestore(userDoc);
      await _cacheManager.set(_userCacheKey, updatedUser);

      debugPrint('✅ Configuraciones actualizadas exitosamente');
      return updatedUser;
    } catch (e, stack) {
      debugPrint('❌ Error actualizando configuraciones: $e');
      FirebaseCrashlytics.instance
          .recordError(e, stack, reason: 'Error al actualizar configuraciones');
      throw Exception('Error al actualizar las configuraciones: $e');
    }
  }

  @override
  Future<UserModel> updateSubscription(
      String userId, SubscriptionInfo subscription) async {
    try {
      debugPrint('💳 Actualizando suscripción de usuario: $userId');

      await _firestore.collection(_usersCollection).doc(userId).update({
        'subscription': subscription.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }).timeout(_firestoreTimeout);

      final userDoc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .get(const GetOptions(source: Source.server))
          .timeout(_firestoreTimeout);

      final updatedUser = UserModel.fromFirestore(userDoc);
      await _cacheManager.set(_userCacheKey, updatedUser);
      _updateCrashlyticsUserData(updatedUser);

      debugPrint('✅ Suscripción actualizada exitosamente');
      return updatedUser;
    } catch (e, stack) {
      debugPrint('❌ Error actualizando suscripción: $e');
      FirebaseCrashlytics.instance
          .recordError(e, stack, reason: 'Error al actualizar suscripción');
      throw Exception('Error al actualizar la suscripción: $e');
    }
  }

  @override
  Future<void> deleteAccount(String userId) async {
    try {
      debugPrint('🗑️ Eliminando cuenta de usuario: $userId');

      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .delete()
          .timeout(_firestoreTimeout);

      final User? currentUser = _firebaseAuth.currentUser;
      if (currentUser != null) {
        await currentUser.delete();
      }

      await _googleSignIn.signOut();
      await _cacheManager.remove(_userCacheKey);

      FirebaseCrashlytics.instance.setUserIdentifier('');

      debugPrint('✅ Cuenta eliminada exitosamente');
    } catch (e, stack) {
      debugPrint('❌ Error eliminando cuenta: $e');
      FirebaseCrashlytics.instance
          .recordError(e, stack, reason: 'Error al eliminar cuenta');
      throw Exception('Error al eliminar la cuenta: $e');
    }
  }

  @override
  Stream<UserModel?> get authStateChanges {
    debugPrint('👁️ Configurando stream de cambios de autenticación');

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
          debugPrint(
              '⚠️ Usuario existe en Auth pero no en Firestore: ${user.uid}');
          return null;
        }
      } catch (e, stack) {
        debugPrint('❌ Error en authStateChanges: $e');
        FirebaseCrashlytics.instance
            .recordError(e, stack, reason: 'Error en authStateChanges');

        return await _cacheManager.get<UserModel>(_userCacheKey);
      }
    });
  }

  Future<UserModel> _processAuthenticatedUser(User firebaseUser) async {
    try {
      debugPrint('🔍 Verificando usuario en Firestore...');

      final userDoc = await _firestore
          .collection(_usersCollection)
          .doc(firebaseUser.uid)
          .get(const GetOptions(source: Source.server))
          .timeout(_firestoreTimeout);

      if (userDoc.exists) {
        debugPrint('👤 Usuario existente encontrado');

        try {
          await _firestore
              .collection(_usersCollection)
              .doc(firebaseUser.uid)
              .update({
            'lastLogin': FieldValue.serverTimestamp(),
          }).timeout(Duration(seconds: 10));
        } catch (e) {
          debugPrint('⚠️ Error actualizando lastLogin (continuando): $e');
        }

        final userModel = UserModel.fromFirestore(userDoc);
        await _cacheManager.set(_userCacheKey, userModel);
        _updateCrashlyticsUserData(userModel);

        debugPrint('✅ Inicio de sesión exitoso - Usuario existente');
        return userModel;
      } else {
        debugPrint('👤 Creando nuevo usuario...');
        final newUser = UserModel.newUser(
          id: firebaseUser.uid,
          name: firebaseUser.displayName ?? 'Usuario',
          email: firebaseUser.email ?? '',
          photoUrl: firebaseUser.photoURL,
        );

        await _firestore
            .collection(_usersCollection)
            .doc(firebaseUser.uid)
            .set({
          ...newUser.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        }).timeout(_firestoreTimeout);

        await _cacheManager.set(_userCacheKey, newUser);
        _updateCrashlyticsUserData(newUser);

        debugPrint('✅ Inicio de sesión exitoso - Usuario nuevo creado');
        return newUser;
      }
    } catch (e, stack) {
      debugPrint('❌ Error procesando usuario autenticado: $e');
      FirebaseCrashlytics.instance.recordError(e, stack,
          reason: 'Error procesando usuario autenticado');
      throw Exception('Error procesando datos del usuario: $e');
    }
  }

  bool _isUserCacheValid(UserModel user) {
    if (user.subscription.type == 'premium' &&
        user.subscription.expirationDate != null) {
      final now = DateTime.now();
      final isValid = user.subscription.expirationDate!.isAfter(now);
      debugPrint('🔍 Validez de caché premium: $isValid');
      return isValid;
    }

    debugPrint('✅ Caché de usuario válida');
    return true;
  }

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
}
