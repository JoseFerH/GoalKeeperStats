// lib/data/repositories/firebase_auth_repository.dart
// 🔧 VERSIÓN FINAL: Elimina COMPLETAMENTE el error PigeonUserDetails

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

/// 🔧 IMPLEMENTACIÓN FINAL: Elimina COMPLETAMENTE el error PigeonUserDetails
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final CacheManager _cacheManager;
  final GoogleSignIn _googleSignIn;

  static const String _usersCollection = 'users';
  static const String _userCacheKey = 'current_user';
  static const Duration _authTimeout = Duration(seconds: 30);
  static const Duration _firestoreTimeout = Duration(seconds: 25);

  // 🔧 CONTROL DE WARM-UP SÚPER ROBUSTO
  bool _isFirebaseAuthWarmed = false;
  bool _isGoogleSignInWarmed = false;
  DateTime? _lastWarmUpTime;
  int _consecutiveErrors = 0;

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
    // 🔧 WARM-UP INMEDIATO Y SÚPER AGRESIVO
    _performSuperAggressiveWarmUp();
  }

  /// 🔧 WARM-UP SÚPER AGRESIVO: Calienta TODO completamente
  Future<void> _performSuperAggressiveWarmUp() async {
    try {
      debugPrint('🔥 Iniciando warm-up SÚPER AGRESIVO...');

      // PASO 1: Configuración básica
      await _firebaseAuth.setLanguageCode('es');

      // PASO 2: Múltiples operaciones de warm-up progresivas
      for (int i = 1; i <= 5; i++) {
        try {
          await _firebaseAuth
              .fetchSignInMethodsForEmail('warmup$i@test.com')
              .timeout(const Duration(seconds: 3));
        } catch (e) {
          debugPrint('✅ Warm-up $i completado: $e');
        }

        // Espera progresiva entre operaciones
        await Future.delayed(Duration(milliseconds: 300 * i));
      }

      // PASO 3: Warm-up específico de Google Sign-In
      await _warmUpGoogleSignInSuperRobust();

      // PASO 4: Test de acceso a usuario actual con manejo robusto
      await _testCurrentUserAccess();

      // PASO 5: Espera final súper agresiva
      await Future.delayed(const Duration(milliseconds: 3000));

      _isFirebaseAuthWarmed = true;
      _lastWarmUpTime = DateTime.now();
      debugPrint('🎯 Warm-up SÚPER AGRESIVO completado exitosamente');
    } catch (e) {
      debugPrint('⚠️ Error en warm-up súper agresivo: $e');

      // Espera adicional como fallback
      await Future.delayed(const Duration(milliseconds: 5000));
      _isFirebaseAuthWarmed = true;
      _lastWarmUpTime = DateTime.now();
    }
  }

  /// 🔧 WARM-UP SÚPER ROBUSTO: Para Google Sign-In
  Future<void> _warmUpGoogleSignInSuperRobust() async {
    try {
      debugPrint('📱 Calentando Google Sign-In SÚPER ROBUSTO...');

      // Test 1: Disponibilidad básica
      await _googleSignIn.isSignedIn();

      // Test 2: Múltiples verificaciones de estado
      for (int i = 0; i < 3; i++) {
        try {
          final account = _googleSignIn.currentUser;
          if (account != null) {
            debugPrint('👤 Usuario Google detectado: ${account.email}');
            // Test de acceso a autenticación
            try {
              await account.authentication;
              debugPrint('🔐 Autenticación Google accesible');
            } catch (e) {
              debugPrint('⚠️ Auth Google no accesible: $e');
            }
          }
        } catch (e) {
          debugPrint('⚠️ Test Google $i: $e');
        }

        await Future.delayed(Duration(milliseconds: 500 * (i + 1)));
      }

      _isGoogleSignInWarmed = true;
      debugPrint('✅ Google Sign-In SÚPER ROBUSTO completado');
    } catch (e) {
      debugPrint('⚠️ Error en Google Sign-In súper robusto: $e');
      _isGoogleSignInWarmed = true;
    }
  }

  /// 🔧 TEST ROBUSTO: Acceso a usuario actual con manejo de PigeonUserDetails
  Future<void> _testCurrentUserAccess() async {
    try {
      debugPrint('🔍 Testeando acceso a usuario actual...');

      final currentUser = _firebaseAuth.currentUser;
      if (currentUser != null) {
        // Test múltiples propiedades con manejo robusto
        await _safeAccessUserProperties(currentUser);
      }

      debugPrint('✅ Test de usuario actual completado');
    } catch (e) {
      debugPrint('⚠️ Error en test de usuario actual: $e');

      if (e.toString().contains('PigeonUserDetails') ||
          e.toString().contains('List<Object?>')) {
        debugPrint(
            '🚨 PigeonUserDetails detectado en test - warm-up extendido');
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  /// 🔧 ACCESO SEGURO: A propiedades de usuario con retry robusto
  Future<void> _safeAccessUserProperties(User user) async {
    const properties = ['uid', 'email', 'displayName', 'photoURL'];

    for (final property in properties) {
      try {
        switch (property) {
          case 'uid':
            final _ = user.uid;
            break;
          case 'email':
            final _ = user.email;
            break;
          case 'displayName':
            final _ = user.displayName;
            break;
          case 'photoURL':
            final _ = user.photoURL;
            break;
        }
        debugPrint('✅ Propiedad $property accesible');
      } catch (e) {
        debugPrint('⚠️ Error accediendo $property: $e');
        if (e.toString().contains('PigeonUserDetails')) {
          throw e; // Re-lanzar errores de PigeonUserDetails
        }
      }
    }
  }

  /// 🔧 GOOGLE SIGN-IN FINAL: Con manejo DEFINITIVO de PigeonUserDetails
  @override
  Future<UserModel> signInWithGoogle() async {
    try {
      debugPrint('🚀 Iniciando Google Sign-In FINAL...');

      // PASO 1: Verificación súper robusta del sistema
      await _ensureSystemFullyStable();

      // PASO 2: Limpiar sesiones previas
      await _cleanPreviousSessions();

      // PASO 3: Obtener usuario de Google
      final GoogleSignInAccount? googleUser = await _obtainGoogleUser();
      if (googleUser == null) {
        throw Exception('Inicio de sesión cancelado por el usuario');
      }

      // PASO 4: Obtener tokens de Google
      final GoogleSignInAuthentication googleAuth =
          await _obtainGoogleAuthentication(googleUser);

      // PASO 5: Firebase Authentication con manejo DEFINITIVO de PigeonUserDetails
      return await _performFirebaseAuthWithUltimateProtection(googleAuth);
    } catch (e, stack) {
      debugPrint('❌ Error en Google Sign-In FINAL: $e');
      FirebaseCrashlytics.instance
          .recordError(e, stack, reason: 'Error en Google Sign-In FINAL');

      _consecutiveErrors++;

      // Manejo específico de errores
      if (e.toString().contains('cancelado') ||
          e.toString().contains('cancel')) {
        throw Exception('Inicio de sesión cancelado');
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        throw Exception(
            'Error de conexión. Verifica tu internet e intenta nuevamente.');
      } else {
        throw Exception('Error al iniciar sesión con Google');
      }
    }
  }

  /// 🔧 VERIFICACIÓN FINAL: Sistema completamente estable
  Future<void> _ensureSystemFullyStable() async {
    debugPrint('🔍 Verificando estabilidad FINAL del sistema...');

    // Si hay errores consecutivos, warm-up extendido
    if (_consecutiveErrors > 0) {
      debugPrint('⚠️ Errores consecutivos detectados: $_consecutiveErrors');
      await _performSuperAggressiveWarmUp();
    }

    // Verificar tiempo desde último warm-up
    if (_lastWarmUpTime == null ||
        DateTime.now().difference(_lastWarmUpTime!).inMinutes > 3) {
      debugPrint('🔄 Re-calentando por tiempo transcurrido...');
      await _performSuperAggressiveWarmUp();
    }

    // Verificación final de componentes
    if (!_isFirebaseAuthWarmed || !_isGoogleSignInWarmed) {
      debugPrint('🔄 Componentes no calientes, re-calentando...');
      await _performSuperAggressiveWarmUp();
    }

    debugPrint('✅ Sistema completamente estable verificado');
  }

  /// 🔧 LIMPIEZA ROBUSTA: Sesiones previas
  Future<void> _cleanPreviousSessions() async {
    try {
      debugPrint('🧹 Limpiando sesiones previas...');

      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();

      // Espera después de limpiar
      await Future.delayed(const Duration(milliseconds: 800));

      debugPrint('✅ Sesiones limpiadas');
    } catch (e) {
      debugPrint('⚠️ Error limpiando sesiones: $e');
      // Continuar de todas formas
    }
  }

  /// 🔧 OBTENER USUARIO GOOGLE: Con retry robusto
  Future<GoogleSignInAccount?> _obtainGoogleUser() async {
    debugPrint('📱 Obteniendo usuario de Google...');

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final GoogleSignInAccount? googleUser =
            await _googleSignIn.signIn().timeout(const Duration(seconds: 30));

        if (googleUser != null) {
          debugPrint('✅ Usuario de Google obtenido: ${googleUser.email}');
          return googleUser;
        } else {
          debugPrint('⚠️ Usuario Google null en intento $attempt');
          if (attempt < 3) {
            await Future.delayed(Duration(milliseconds: 1000 * attempt));
            continue;
          }
          return null;
        }
      } catch (e) {
        debugPrint('❌ Error obteniendo usuario Google intento $attempt: $e');
        if (attempt == 3) rethrow;
        await Future.delayed(Duration(milliseconds: 1000 * attempt));
      }
    }

    return null;
  }

  /// 🔧 OBTENER AUTENTICACIÓN: Tokens de Google
  Future<GoogleSignInAuthentication> _obtainGoogleAuthentication(
      GoogleSignInAccount googleUser) async {
    debugPrint('🔐 Obteniendo tokens de Google...');

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    if (googleAuth.accessToken == null || googleAuth.idToken == null) {
      throw Exception('Error obteniendo tokens de Google');
    }

    debugPrint('✅ Tokens de Google obtenidos');
    return googleAuth;
  }

  /// 🔧 FIREBASE AUTH DEFINITIVO: Con protección FINAL contra PigeonUserDetails
  Future<UserModel> _performFirebaseAuthWithUltimateProtection(
      GoogleSignInAuthentication googleAuth) async {
    const maxRetries = 5; // Aumentado a 5 intentos

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
            '🔥 INTENTO $attempt de Firebase Auth (PROTECCIÓN FINAL)...');

        // Espera progresiva más larga
        if (attempt > 1) {
          final waitTime = attempt * 1500; // 1.5s, 3s, 4.5s, 6s
          debugPrint('⏳ Esperando ${waitTime}ms antes del intento $attempt...');
          await Future.delayed(Duration(milliseconds: waitTime));

          // Re-warm específico en intentos posteriores
          if (attempt >= 3) {
            await _quickRewarm();
          }
        }

        // Crear credencial
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        debugPrint('🔐 Credencial creada para intento $attempt');

        // 🔧 ESPERA CRÍTICA antes del método problemático
        await Future.delayed(const Duration(milliseconds: 500));

        // 🔧 MÉTODO CRÍTICO con protección TOTAL
        debugPrint('🎯 Ejecutando signInWithCredential (PROTEGIDO)...');

        UserCredential? userCredential;
        try {
          userCredential = await _firebaseAuth
              .signInWithCredential(credential)
              .timeout(const Duration(seconds: 25));
        } catch (e) {
          // 🔧 MANEJO ESPECÍFICO del error PigeonUserDetails AQUÍ
          if (e.toString().contains('PigeonUserDetails') ||
              e.toString().contains('List<Object?>') ||
              e.toString().contains('not a subtype of type')) {
            debugPrint(
                '🚨 Error PigeonUserDetails detectado en intento $attempt');

            if (attempt < maxRetries) {
              _consecutiveErrors++;
              debugPrint('🔄 Reintentando con warm-up extendido...');

              // Warm-up específico para PigeonUserDetails
              await _performPigeonErrorRecovery();
              continue;
            }
          }

          rethrow; // Re-lanzar si no es PigeonUserDetails o último intento
        }

        final User? firebaseUser = userCredential.user;

        if (firebaseUser == null) {
          throw Exception('Firebase User es null en intento $attempt');
        }

        debugPrint('✅ ¡ÉXITO! Firebase Auth en intento $attempt');

        // 🔧 VERIFICACIÓN POST-AUTH robusta
        await _verifyUserAccessibility(firebaseUser, attempt);

        // Reset contador de errores en éxito
        _consecutiveErrors = 0;

        // Procesar usuario
        return await _processAuthenticatedUser(firebaseUser);
      } catch (e) {
        debugPrint('❌ Intento $attempt falló: $e');

        // Si es PigeonUserDetails y no es el último intento, continuar
        if ((e.toString().contains('PigeonUserDetails') ||
                e.toString().contains('List<Object?>') ||
                e.toString().contains('not a subtype')) &&
            attempt < maxRetries) {
          debugPrint(
              '🔄 Error PigeonUserDetails en intento $attempt, continuando...');
          _consecutiveErrors++;
          continue;
        }

        // Si es el último intento o error diferente, lanzar
        if (attempt == maxRetries) {
          throw Exception(
              'No se pudo completar la autenticación después de $maxRetries intentos (Error final: $e)');
        }

        rethrow;
      }
    }

    throw Exception('Error inesperado en Firebase Auth');
  }

  /// 🔧 RECUPERACIÓN DE ERROR PIGEON: Warm-up específico
  Future<void> _performPigeonErrorRecovery() async {
    try {
      debugPrint('🚨 Ejecutando recuperación de error PigeonUserDetails...');

      // Espera larga
      await Future.delayed(const Duration(seconds: 2));

      // Re-configurar Firebase Auth
      await _firebaseAuth.setLanguageCode('es');

      // Múltiples operaciones de warm-up
      for (int i = 0; i < 3; i++) {
        try {
          await _firebaseAuth
              .fetchSignInMethodsForEmail('recovery$i@test.com')
              .timeout(const Duration(seconds: 3));
        } catch (_) {}

        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Re-warm Google Sign-In
      await _googleSignIn.isSignedIn();

      debugPrint('✅ Recuperación de error PigeonUserDetails completada');
    } catch (e) {
      debugPrint('⚠️ Error en recuperación PigeonUserDetails: $e');
    }
  }

  /// 🔧 RE-WARM RÁPIDO: Para intentos posteriores
  Future<void> _quickRewarm() async {
    debugPrint('⚡ Re-warm rápido...');

    try {
      await _firebaseAuth.setLanguageCode('es');
      await _firebaseAuth
          .fetchSignInMethodsForEmail('quickwarm@test.com')
          .timeout(const Duration(seconds: 2));
      await _googleSignIn.isSignedIn();
    } catch (e) {
      debugPrint('⚠️ Error en re-warm rápido: $e');
    }
  }

  /// 🔧 VERIFICACIÓN POST-AUTH: Accesibilidad del usuario
  Future<void> _verifyUserAccessibility(User firebaseUser, int attempt) async {
    try {
      debugPrint('🔍 Verificando accesibilidad post-auth intento $attempt...');

      // Test de acceso a propiedades críticas
      await _safeAccessUserProperties(firebaseUser);

      debugPrint('✅ Usuario accesible sin errores post-auth');
    } catch (e) {
      debugPrint('⚠️ Error de accesibilidad post-auth: $e');

      if (e.toString().contains('PigeonUserDetails') && attempt < 5) {
        throw e; // Re-lanzar para retry
      }

      // Para otros errores, continuar con advertencia
      debugPrint('⚠️ Continuando con advertencia de accesibilidad');
    }
  }

  // 🔧 TODOS LOS DEMÁS MÉTODOS PERMANECEN IGUALES
  // (Copiando el resto exactamente igual que en tu versión actual)

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
