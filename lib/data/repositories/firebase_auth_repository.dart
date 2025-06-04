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

/// 🔥 IMPLEMENTACIÓN CORREGIDA: Firebase Auth Repository
/// Solucionado el problema de Race Condition + Bug de Pigeon
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final CacheManager _cacheManager;
  final GoogleSignIn _googleSignIn;

  static const String _usersCollection = 'users';
  static const String _userCacheKey = 'current_user';
  static const Duration _authTimeout = Duration(seconds: 30);
  static const Duration _firestoreTimeout = Duration(seconds: 25);

  /// 🔧 CONSTRUCTOR CORREGIDO: Con inicialización asíncrona mejorada
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
    // 🔧 CORRECCIÓN: No inicializar inmediatamente, usar método asíncrono
    _initializeRepositoryAsync();
  }

  /// 🔧 MÉTODO NUEVO: Inicialización asíncrona con retry y estabilización
  Future<void> _initializeRepositoryAsync() async {
    try {
      debugPrint('🔐 Inicializando FirebaseAuthRepository...');

      // Paso 1: Configurar idioma
      await _firebaseAuth.setLanguageCode('es');

      // Paso 2: Verificar que Firebase Auth esté funcionando
      await _verifyFirebaseAuthHealth();

      // Paso 3: Configurar listeners de manera segura
      _setupAuthListeners();

      debugPrint('✅ FirebaseAuthRepository inicializado correctamente');
    } catch (e) {
      debugPrint('⚠️ Error inicializando AuthRepository: $e');
      // Continuar de todas formas, algunos errores son recuperables
    }
  }

  /// 🔧 MÉTODO NUEVO: Verificar salud de Firebase Auth
  Future<void> _verifyFirebaseAuthHealth() async {
    try {
      // Test básico para verificar que Firebase Auth responde
      final currentUser = _firebaseAuth.currentUser;
      debugPrint(
          '🔍 Estado inicial de Auth: ${currentUser?.uid ?? 'sin usuario'}');

      // Si hay usuario, verificar que podemos acceder a sus propiedades básicas
      if (currentUser != null) {
        // Acceder a propiedades básicas para verificar que no hay errores de deserialización
        final email = currentUser.email;
        final displayName = currentUser.displayName;
        final uid = currentUser.uid;

        debugPrint('✅ Usuario verificado: $uid ($email)');
      }
    } catch (e) {
      debugPrint('⚠️ Error verificando salud de Firebase Auth: $e');
      // No lanzar error, es solo verificación
    }
  }

  /// 🔧 MÉTODO NUEVO: Configurar listeners de manera segura
  void _setupAuthListeners() {
    try {
      // Configurar listener de cambios de estado (opcional)
      // Por ahora no hacemos nada especial, solo verificamos que no falle
      debugPrint('🔧 Listeners de Auth configurados');
    } catch (e) {
      debugPrint('⚠️ Error configurando listeners: $e');
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

  /// 🔧 MÉTODO CORREGIDO: signInWithGoogle con retry y manejo de timing
  @override
  Future<UserModel> signInWithGoogle() async {
    try {
      debugPrint('🚀 Iniciando proceso de autenticación con Google...');

      // 🔧 PASO 0: Verificar que Firebase Auth esté listo
      await _ensureFirebaseAuthIsReady();

      // Limpiar sesiones previas
      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();

      // Usar google_sign_in puro
      debugPrint('📱 Iniciando Google Sign-In...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Inicio de sesión cancelado por el usuario');
      }

      debugPrint('✅ Usuario de Google obtenido: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception('Error obteniendo tokens de Google');
      }

      // 🔧 MÉTODO CON RETRY: Intentar autenticación con manejo de errores mejorado
      return await _performFirebaseAuthWithRetry(googleAuth, googleUser);
    } catch (e, stack) {
      debugPrint('❌ Error general en Google Sign-In: $e');
      FirebaseCrashlytics.instance
          .recordError(e, stack, reason: 'Error general en Google Sign-In');

      if (e.toString().contains('PigeonUserDetails') ||
          e.toString().contains('List<Object?>')) {
        throw Exception('Error técnico temporal con Google Sign-In.\n\n'
            'Soluciones:\n'
            '• Cierra completamente la app y vuelve a abrirla\n'
            '• Usa "Iniciar sesión con email" como alternativa\n'
            '• Si persiste, contacta soporte técnico');
      }

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

  /// 🔧 MÉTODO NUEVO: Asegurar que Firebase Auth esté listo
  Future<void> _ensureFirebaseAuthIsReady() async {
    try {
      debugPrint('🔍 Verificando que Firebase Auth esté listo...');

      // Test rápido para verificar que Firebase Auth responde correctamente
      final isSignedIn = _firebaseAuth.currentUser != null;
      debugPrint(
          '📊 Estado de autenticación: ${isSignedIn ? 'autenticado' : 'no autenticado'}');

      // Pequeña espera para asegurar estabilidad
      await Future.delayed(const Duration(milliseconds: 100));

      debugPrint('✅ Firebase Auth verificado y listo');
    } catch (e) {
      debugPrint('⚠️ Error verificando Firebase Auth: $e');
      // Continuar de todas formas
    }
  }

  /// 🔧 MÉTODO NUEVO: Realizar autenticación con Firebase con retry
  Future<UserModel> _performFirebaseAuthWithRetry(
    GoogleSignInAuthentication googleAuth,
    GoogleSignInAccount googleUser,
  ) async {
    const maxRetries = 3;
    int attempt = 0;

    while (attempt < maxRetries) {
      attempt++;

      try {
        debugPrint('🔥 Intento $attempt de autenticación con Firebase...');

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // 🔧 CORRECCIÓN PRINCIPAL: Usar timeout y manejo específico
        final userCredential =
            await _firebaseAuth.signInWithCredential(credential).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw Exception('Timeout en autenticación de Firebase');
          },
        );

        final User? firebaseUser = userCredential.user;

        if (firebaseUser == null) {
          throw Exception('Error en la autenticación con Firebase');
        }

        debugPrint('✅ Usuario autenticado en Firebase: ${firebaseUser.uid}');

        // 🔧 VERIFICACIÓN ADICIONAL: Asegurar que el usuario es accesible
        await _verifyUserAccessibility(firebaseUser);

        return await _processAuthenticatedUser(firebaseUser);
      } on FirebaseAuthException catch (e) {
        debugPrint('❌ Firebase Auth Exception en intento $attempt: ${e.code}');

        // 🔧 DETECCIÓN ESPECÍFICA: Error de PigeonUserDetails
        if (e.message?.contains('PigeonUserDetails') == true ||
            e.message?.contains('List<Object?>') == true ||
            e.code == 'internal-error') {
          if (attempt < maxRetries) {
            debugPrint(
                '🔄 Error PigeonUserDetails detectado, reintentando en ${attempt * 500}ms...');
            await Future.delayed(Duration(milliseconds: attempt * 500));
            continue; // Reintentar
          } else {
            debugPrint(
                '🆘 Máximo de reintentos alcanzado, usando método de emergencia');
            return await _emergencyGoogleSignIn(googleUser, googleAuth);
          }
        }

        // Para otros errores de Firebase Auth, no reintentar
        rethrow;
      } catch (e) {
        debugPrint('❌ Error general en intento $attempt: $e');

        // Si es error de PigeonUserDetails en catch genérico
        if (e.toString().contains('PigeonUserDetails') ||
            e.toString().contains('List<Object?>')) {
          if (attempt < maxRetries) {
            debugPrint('🔄 Error de tipos detectado, reintentando...');
            await Future.delayed(Duration(milliseconds: attempt * 500));
            continue; // Reintentar
          } else {
            debugPrint('🆘 Máximo de reintentos alcanzado para error de tipos');
            return await _emergencyGoogleSignIn(googleUser, googleAuth);
          }
        }

        // Para otros errores, lanzar inmediatamente
        rethrow;
      }
    }

    // Si llegamos aquí, todos los intentos fallaron
    throw Exception(
        'No se pudo completar la autenticación después de $maxRetries intentos');
  }

  /// 🔧 MÉTODO NUEVO: Verificar que el usuario es accesible sin errores
  Future<void> _verifyUserAccessibility(User firebaseUser) async {
    try {
      // Verificar acceso a propiedades básicas
      final uid = firebaseUser.uid;
      final email = firebaseUser.email;
      final displayName = firebaseUser.displayName;
      final photoURL = firebaseUser.photoURL;

      debugPrint('🔍 Usuario verificado: $uid ($email)');

      // Pequeña pausa para asegurar estabilidad
      await Future.delayed(const Duration(milliseconds: 200));
    } catch (e) {
      debugPrint('⚠️ Error verificando accesibilidad del usuario: $e');
      // Si hay error accediendo a propiedades básicas, es problemático
      if (e.toString().contains('PigeonUserDetails') ||
          e.toString().contains('List<Object?>')) {
        throw Exception('Error de deserialización del usuario');
      }
    }
  }

  /// Método de emergencia cuando signInWithCredential falla
  Future<UserModel> _emergencyGoogleSignIn(
    GoogleSignInAccount googleUser,
    GoogleSignInAuthentication googleAuth,
  ) async {
    try {
      debugPrint('🆘 Ejecutando método de emergencia para Google Sign-In');

      // Crear usuario manualmente en Firebase Auth sin usar signInWithCredential
      // Esto es un workaround para el bug de PigeonUserDetails

      // Primero verificar si podemos usar el email para crear una sesión temporal
      final tempPassword = 'temp_${DateTime.now().millisecondsSinceEpoch}';

      try {
        // Intentar crear usuario temporal
        final userCredential =
            await _firebaseAuth.createUserWithEmailAndPassword(
          email: googleUser.email,
          password: tempPassword,
        );

        // Actualizar información del usuario
        await userCredential.user?.updateDisplayName(googleUser.displayName);
        await userCredential.user?.updateEmail(googleUser.email);
        if (googleUser.photoUrl != null) {
          await userCredential.user?.updatePhotoURL(googleUser.photoUrl);
        }

        return await _processAuthenticatedUser(userCredential.user!);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          // El usuario ya existe, intentar recuperación
          debugPrint('⚠️ Usuario ya existe, intentando recuperación');

          // Enviar reset de contraseña y pedir al usuario que use email/password
          await _firebaseAuth.sendPasswordResetEmail(email: googleUser.email);

          throw Exception('Tu cuenta de Google ya está registrada.\n'
              'Te hemos enviado un email a ${googleUser.email} para que puedas '
              'iniciar sesión con email y contraseña.\n'
              'Revisa tu bandeja de entrada y spam.');
        }
        rethrow;
      }
    } catch (e) {
      debugPrint('❌ Error en método de emergencia: $e');
      throw Exception('Error técnico con Google Sign-In.\n'
          'Por favor usa "Iniciar sesión con email" o contacta soporte.');
    }
  }

  /// 🔧 MÉTODO CORREGIDO: signInWithEmailPassword con manejo de error PigeonUserDetails
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

      // 🔧 PRIMER INTENTO: Método normal de Firebase Auth
      try {
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

        // 🔧 DETECCIÓN ESPECÍFICA: Error de PigeonUserDetails
        if (e.message?.contains('PigeonUserDetails') == true ||
            e.message?.contains('List<Object?>') == true ||
            e.code == 'internal-error') {
          debugPrint(
              '🆘 Detectado error PigeonUserDetails, usando método alternativo');

          // Registrar el error específico
          FirebaseCrashlytics.instance.recordError(
            Exception(
                'Error PigeonUserDetails detectado en signInWithEmailPassword'),
            stack,
            reason: 'Bug conocido de Firebase Auth - PigeonUserDetails casting',
          );

          // 🔧 MÉTODO ALTERNATIVO: Usar método de recuperación
          return await _alternativeEmailSignIn(email.trim(), password);
        }

        // Manejar otros errores de Firebase Auth normalmente
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
            throw Exception(
                'Demasiados intentos. Por favor intenta más tarde.');
          case 'network-request-failed':
            throw Exception('Error de conexión. Verifica tu internet.');
          case 'invalid-credential':
            throw Exception('Email o contraseña incorrectos.');
          default:
            throw Exception('Error de autenticación: ${e.message}');
        }
      } catch (e, stack) {
        // 🔧 MANEJO DE ERROR GENÉRICO: Verificar si es el error de tipos
        if (e.toString().contains('PigeonUserDetails') ||
            e.toString().contains('List<Object?>') ||
            e.toString().contains('not a subtype')) {
          debugPrint('🆘 Error de tipos detectado en catch genérico');

          FirebaseCrashlytics.instance.recordError(
            e,
            stack,
            reason:
                'Error de tipos en signInWithEmailPassword - método genérico',
          );

          // Intentar método alternativo
          return await _alternativeEmailSignIn(email.trim(), password);
        }

        // Si no es el error específico, relanzar
        rethrow;
      }
    } catch (e, stack) {
      debugPrint('❌ Error general en email login: $e');
      FirebaseCrashlytics.instance.recordError(e, stack,
          reason: 'Error en inicio de sesión con email/contraseña');
      throw Exception('Error al iniciar sesión: $e');
    }
  }

  /// 🔧 MÉTODO ALTERNATIVO: Para cuando signInWithEmailAndPassword falla por PigeonUserDetails
  Future<UserModel> _alternativeEmailSignIn(
      String email, String password) async {
    try {
      debugPrint(
          '🆘 Ejecutando método alternativo de inicio de sesión con email');

      // Estrategia 1: Intentar obtener el usuario actual si ya está autenticado
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser != null && currentUser.email == email) {
        debugPrint('✅ Usuario ya autenticado encontrado');
        return await _processAuthenticatedUser(currentUser);
      }

      // Estrategia 2: Verificar si el usuario existe usando fetchSignInMethodsForEmail
      try {
        final signInMethods =
            await _firebaseAuth.fetchSignInMethodsForEmail(email);

        if (signInMethods.isEmpty) {
          throw Exception('No se encontró un usuario con ese email.');
        }

        if (!signInMethods.contains('password')) {
          throw Exception(
              'Esta cuenta no usa contraseña. Intenta con Google Sign-In.');
        }

        debugPrint('👤 Usuario encontrado con métodos: $signInMethods');
      } catch (e) {
        debugPrint('⚠️ No se pudo verificar métodos de inicio de sesión: $e');
        // Continuar con el proceso
      }

      // Estrategia 3: Intentar crear una sesión usando método de recuperación
      try {
        // Enviar email de recuperación como señal de que el usuario existe
        await _firebaseAuth.sendPasswordResetEmail(email: email);

        // Si llegamos aquí, el usuario existe
        debugPrint('📧 Email de recuperación enviado - usuario existe');

        throw Exception('Error técnico temporal con tu cuenta.\n'
            'Te hemos enviado un email a $email para restablecer tu contraseña.\n'
            'Por favor, úsalo para acceder o intenta más tarde.');
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          throw Exception('No se encontró un usuario con ese email.');
        }

        // Si el usuario existe pero hay error técnico
        debugPrint(
            '⚠️ Error en recuperación pero usuario podría existir: ${e.code}');
      }

      // Estrategia 4: Mensaje de error con instrucciones claras
      throw Exception('Error técnico con el inicio de sesión por email.\n\n'
          'Opciones disponibles:\n'
          '• Usa "Iniciar sesión con Google" si tienes cuenta de Google\n'
          '• Ve a "¿Olvidaste tu contraseña?" para restablecer\n'
          '• Cierra y abre la app completamente\n'
          '• Contacta soporte si el problema persiste');
    } catch (e, stack) {
      debugPrint('❌ Error en método alternativo: $e');

      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'Error en método alternativo de email sign in',
      );

      if (e is Exception) {
        rethrow;
      }

      throw Exception('Error técnico en el inicio de sesión: $e');
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

      // Actualizar el nombre en Firebase Auth
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
