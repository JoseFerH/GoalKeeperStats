import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:goalkeeper_stats/domain/repositories/auth_repository.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/data/models/user_settings.dart';
import 'package:goalkeeper_stats/data/models/subscription_info.dart';
import 'package:goalkeeper_stats/services/cache_manager.dart';

/// Implementación de Firebase para el repositorio de autenticación
///
/// Versión mejorada con manejo robusto de errores, timeouts y logging.
/// Corrige el error: type 'List<Object?>' is not a subtype of type 'PigeonUserDetails?'
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;
  final CacheManager _cacheManager;

  // Colección donde se almacenan los usuarios en Firestore
  static const String _usersCollection = 'users';

  // Clave de caché para el usuario actual
  static const String _userCacheKey = 'current_user';

  // Timeouts para operaciones
  static const Duration _authTimeout = Duration(seconds: 30);
  static const Duration _firestoreTimeout = Duration(seconds: 25);
  static const Duration _credentialsTimeout = Duration(seconds: 30);

  /// Constructor con posibilidad de inyección para pruebas
  FirebaseAuthRepository({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
    CacheManager? cacheManager,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(),
        _cacheManager = cacheManager ?? CacheManager() {
    _initializeRepository();
  }

  /// Inicialización del repositorio con configuración adicional
  void _initializeRepository() {
    try {
      // Configurar idioma por defecto para Firebase Auth
      _firebaseAuth.setLanguageCode('es');

      // Log de inicialización
      debugPrint('🔐 FirebaseAuthRepository inicializado correctamente');
    } catch (e) {
      debugPrint('⚠️ Error inicializando AuthRepository: $e');
    }
  }

  /// NUEVO: Registra un nuevo usuario con email y contraseña
  @override
  Future<UserModel> registerWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      debugPrint('📝 Registrando nuevo usuario: $email');

      // Verificar conectividad
      await _verifyConnectivity();

      // Crear cuenta en Firebase Auth
      final userCredential = await _firebaseAuth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          )
          .timeout(_authTimeout);

      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception('Error al crear la cuenta');
      }

      debugPrint('✅ Cuenta creada en Firebase Auth: ${firebaseUser.uid}');

      // Actualizar el nombre de usuario en Firebase Auth
      await firebaseUser.updateDisplayName(displayName.trim());
      await firebaseUser.reload();

      // Crear el modelo de usuario
      final newUser = UserModel.newUser(
        id: firebaseUser.uid,
        name: displayName.trim(),
        email: email.trim(),
        photoUrl: firebaseUser.photoURL,
      );

      // Guardar en Firestore
      await _firestore.collection(_usersCollection).doc(firebaseUser.uid).set({
        ...newUser.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'registrationMethod': 'email', // NUEVO: Método de registro
      }).timeout(_firestoreTimeout);

      debugPrint('✅ Usuario guardado en Firestore');

      // Actualizar caché
      await _cacheManager.set(_userCacheKey, newUser);

      // Actualizar datos en Crashlytics
      _updateCrashlyticsUserData(newUser);

      debugPrint('✅ Registro exitoso con email');
      return newUser;
    } on FirebaseAuthException catch (e, stack) {
      debugPrint('❌ FirebaseAuthException en registro: ${e.code}');

      // Registrar error específico de Firebase Auth
      FirebaseCrashlytics.instance.recordError(e, stack,
          reason: 'Error en registro con email: ${e.code}');

      // Manejar errores específicos
      switch (e.code) {
        case 'email-already-in-use':
          throw Exception('Ya existe una cuenta con este email.');
        case 'weak-password':
          throw Exception('La contraseña es muy débil.');
        case 'invalid-email':
          throw Exception('El email ingresado no es válido.');
        case 'operation-not-allowed':
          throw Exception('El registro con email no está habilitado.');
        case 'network-request-failed':
          throw Exception('Error de conexión. Verifica tu internet.');
        case 'too-many-requests':
          throw Exception('Demasiados intentos. Por favor intenta más tarde.');
        default:
          throw Exception('Error al crear la cuenta: ${e.message}');
      }
    } catch (e, stack) {
      debugPrint('❌ Error general en registro: $e');

      // Registrar otros errores
      FirebaseCrashlytics.instance.recordError(e, stack,
          reason: 'Error en registro con email/contraseña');

      if (e.toString().contains('timeout') ||
          e.toString().contains('Timeout')) {
        throw Exception('La creación de cuenta está tardando demasiado. '
            'Verifica tu conexión e intenta nuevamente.');
      }

      throw Exception('Error al crear la cuenta. Intenta nuevamente.');
    }
  }

  /// NUEVO: Envía un email de recuperación de contraseña
  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      debugPrint('📧 Enviando email de recuperación a: $email');

      // Verificar conectividad
      await _verifyConnectivity();

      await _firebaseAuth
          .sendPasswordResetEmail(email: email.trim())
          .timeout(_authTimeout);

      debugPrint('✅ Email de recuperación enviado');
    } on FirebaseAuthException catch (e, stack) {
      debugPrint('❌ FirebaseAuthException en recuperación: ${e.code}');

      // Registrar error
      FirebaseCrashlytics.instance.recordError(e, stack,
          reason: 'Error enviando email de recuperación: ${e.code}');

      // Manejar errores específicos
      switch (e.code) {
        case 'user-not-found':
          throw Exception('No se encontró un usuario con este email.');
        case 'invalid-email':
          throw Exception('El email ingresado no es válido.');
        case 'network-request-failed':
          throw Exception('Error de conexión. Verifica tu internet.');
        case 'too-many-requests':
          throw Exception('Demasiados intentos. Por favor intenta más tarde.');
        default:
          throw Exception(
              'Error al enviar email de recuperación: ${e.message}');
      }
    } catch (e, stack) {
      debugPrint('❌ Error general en recuperación: $e');

      FirebaseCrashlytics.instance.recordError(e, stack,
          reason: 'Error enviando email de recuperación');

      if (e.toString().contains('timeout') ||
          e.toString().contains('Timeout')) {
        throw Exception('El envío del email está tardando demasiado. '
            'Verifica tu conexión e intenta nuevamente.');
      }

      throw Exception('Error al enviar email de recuperación.');
    }
  }

  /// NUEVO: Actualiza la contraseña del usuario actual
  @override
  Future<void> updatePassword(String newPassword) async {
    try {
      debugPrint('🔒 Actualizando contraseña del usuario');

      final User? currentUser = _firebaseAuth.currentUser;
      if (currentUser == null) {
        throw Exception('No hay usuario autenticado');
      }

      // Verificar conectividad
      await _verifyConnectivity();

      await currentUser.updatePassword(newPassword).timeout(_authTimeout);

      debugPrint('✅ Contraseña actualizada exitosamente');
    } on FirebaseAuthException catch (e, stack) {
      debugPrint('❌ FirebaseAuthException actualizando contraseña: ${e.code}');

      // Registrar error
      FirebaseCrashlytics.instance.recordError(e, stack,
          reason: 'Error actualizando contraseña: ${e.code}');

      // Manejar errores específicos
      switch (e.code) {
        case 'weak-password':
          throw Exception('La nueva contraseña es muy débil.');
        case 'requires-recent-login':
          throw Exception(
              'Necesitas autenticarte de nuevo para cambiar la contraseña.');
        case 'network-request-failed':
          throw Exception('Error de conexión. Verifica tu internet.');
        default:
          throw Exception('Error al actualizar contraseña: ${e.message}');
      }
    } catch (e, stack) {
      debugPrint('❌ Error general actualizando contraseña: $e');

      FirebaseCrashlytics.instance
          .recordError(e, stack, reason: 'Error actualizando contraseña');

      throw Exception('Error al actualizar la contraseña.');
    }
  }

  /// NUEVO: Reautentica al usuario con su contraseña actual
  @override
  Future<void> reauthenticateWithPassword(String currentPassword) async {
    try {
      debugPrint('🔐 Reautenticando usuario');

      final User? currentUser = _firebaseAuth.currentUser;
      if (currentUser == null || currentUser.email == null) {
        throw Exception('No hay usuario autenticado');
      }

      // Verificar conectividad
      await _verifyConnectivity();

      // Crear credencial con email y contraseña actual
      final credential = EmailAuthProvider.credential(
        email: currentUser.email!,
        password: currentPassword,
      );

      // Reautenticar
      await currentUser
          .reauthenticateWithCredential(credential)
          .timeout(_authTimeout);

      debugPrint('✅ Reautenticación exitosa');
    } on FirebaseAuthException catch (e, stack) {
      debugPrint('❌ FirebaseAuthException en reautenticación: ${e.code}');

      // Registrar error
      FirebaseCrashlytics.instance
          .recordError(e, stack, reason: 'Error en reautenticación: ${e.code}');

      // Manejar errores específicos
      switch (e.code) {
        case 'wrong-password':
          throw Exception('La contraseña actual es incorrecta.');
        case 'user-mismatch':
          throw Exception('Error de autenticación. Intenta nuevamente.');
        case 'network-request-failed':
          throw Exception('Error de conexión. Verifica tu internet.');
        case 'too-many-requests':
          throw Exception('Demasiados intentos. Por favor intenta más tarde.');
        default:
          throw Exception('Error de autenticación: ${e.message}');
      }
    } catch (e, stack) {
      debugPrint('❌ Error general en reautenticación: $e');

      FirebaseCrashlytics.instance
          .recordError(e, stack, reason: 'Error en reautenticación');

      throw Exception('Error al verificar la contraseña actual.');
    }
  }

  /// Actualizar el método existente signInWithEmailPassword para incluir @override
  @override
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

  // Timeouts optimizados para diferentes escenarios
  static const Duration _authTimeoutFast =
      Duration(seconds: 45); // ⬆️ Aumentado
  static const Duration _authTimeoutSlow =
      Duration(seconds: 60); // ⬆️ Para conexiones lentas
  // static const Duration _firestoreTimeout = Duration(seconds: 20); // ⬆️ Aumentado
  // static const Duration _credentialsTimeout = Duration(seconds: 25); // ⬆️ Aumentado

  @override
  Future<UserModel> signInWithGoogle() async {
    try {
      debugPrint('🚀 Iniciando proceso de autenticación con Google...');

      // 🔧 PASO 0: Verificar conectividad antes de comenzar
      debugPrint('🌐 Verificando conectividad...');
      await _verifyConnectivity();

      // 🔧 PASO 1: Limpiar cualquier sesión previa de Google
      debugPrint('🧹 Limpiando sesiones previas...');
      try {
        await _googleSignIn.signOut().timeout(Duration(seconds: 10));
      } catch (e) {
        debugPrint('⚠️ Error limpiando sesión previa (continuando): $e');
        // No fallar por esto, continuar
      }

      // 🔧 PASO 2: Iniciar el flujo de autenticación de Google con timeout extendido
      debugPrint(
          '📱 Iniciando Google Sign-In (timeout: ${_authTimeoutSlow.inSeconds}s)...');
      final GoogleSignInAccount? googleUser =
          await _googleSignIn.signIn().timeout(
        _authTimeoutSlow, // Timeout más largo para Google Sign-In
        onTimeout: () {
          debugPrint(
              '⏰ Timeout al conectar con Google (${_authTimeoutSlow.inSeconds}s)');
          throw Exception(
              'La autenticación con Google está tardando demasiado. '
              'Esto puede deberse a una conexión lenta. Por favor:\n'
              '• Verifica tu conexión a internet\n'
              '• Intenta nuevamente en un momento\n'
              '• Considera usar una conexión más estable');
        },
      );

      if (googleUser == null) {
        debugPrint('❌ Usuario canceló el inicio de sesión');
        throw Exception('Inicio de sesión cancelado por el usuario');
      }

      debugPrint('✅ Google Sign-In exitoso para: ${googleUser.email}');

      // 🔧 PASO 3: Obtener detalles de autenticación con timeout extendido
      debugPrint(
          '🔑 Obteniendo credenciales (timeout: ${_credentialsTimeout.inSeconds}s)...');
      GoogleSignInAuthentication googleAuth;
      try {
        googleAuth = await googleUser.authentication.timeout(
          _credentialsTimeout,
          onTimeout: () {
            debugPrint(
                '⏰ Timeout obteniendo credenciales (${_credentialsTimeout.inSeconds}s)');
            throw Exception('Timeout al obtener credenciales de Google. '
                'La conexión es muy lenta. Intenta nuevamente.');
          },
        );
      } catch (e) {
        debugPrint('❌ Error obteniendo credenciales: $e');
        if (e.toString().contains('timeout') ||
            e.toString().contains('Timeout')) {
          throw Exception(
              'Las credenciales de Google están tardando demasiado en obtenerse. '
              'Verifica tu conexión e intenta nuevamente.');
        }
        throw Exception('Error al obtener credenciales de Google: $e');
      }

      // 🔧 PASO 4: Verificar que tenemos los tokens necesarios
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        debugPrint('❌ Tokens de autenticación faltantes');
        debugPrint(
            '   AccessToken: ${googleAuth.accessToken != null ? "✅" : "❌"}');
        debugPrint('   IdToken: ${googleAuth.idToken != null ? "✅" : "❌"}');
        throw Exception('No se pudieron obtener los tokens de autenticación. '
            'Por favor intenta nuevamente.');
      }

      debugPrint('✅ Credenciales obtenidas correctamente');

      // 🔧 PASO 5: Crear credencial para Firebase
      debugPrint('🔗 Creando credencial Firebase...');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 🔧 PASO 6: Iniciar sesión en Firebase con timeout optimizado
      debugPrint(
          '🔥 Autenticando con Firebase (timeout: ${_authTimeoutFast.inSeconds}s)...');
      UserCredential userCredential;
      try {
        userCredential =
            await _firebaseAuth.signInWithCredential(credential).timeout(
          _authTimeoutFast,
          onTimeout: () {
            debugPrint(
                '⏰ Timeout autenticando con Firebase (${_authTimeoutFast.inSeconds}s)');
            throw Exception(
                'La autenticación con Firebase está tardando demasiado. '
                'Esto puede indicar problemas del servidor. Intenta nuevamente.');
          },
        );
      } on FirebaseAuthException catch (e) {
        debugPrint('❌ FirebaseAuthException: ${e.code} - ${e.message}');

        // Manejar errores específicos de Firebase Auth
        switch (e.code) {
          case 'account-exists-with-different-credential':
            throw Exception(
                'Esta cuenta ya existe con un método de inicio de sesión diferente');
          case 'invalid-credential':
            throw Exception(
                'Credenciales inválidas. Por favor intenta nuevamente.');
          case 'operation-not-allowed':
            throw Exception(
                'El inicio de sesión con Google no está habilitado en la configuración');
          case 'user-disabled':
            throw Exception('Esta cuenta ha sido deshabilitada');
          case 'network-request-failed':
            throw Exception(
                'Error de conexión con Firebase. Verifica tu internet.');
          case 'too-many-requests':
            throw Exception(
                'Demasiados intentos. Espera un momento e intenta nuevamente.');
          default:
            throw Exception('Error de autenticación: ${e.message}');
        }
      } catch (e) {
        debugPrint('❌ Error genérico en autenticación Firebase: $e');
        if (e.toString().contains('timeout') ||
            e.toString().contains('Timeout')) {
          throw Exception('Firebase está tardando en responder. '
              'Verifica tu conexión e intenta nuevamente.');
        }
        throw Exception('Error conectando con Firebase: $e');
      }

      // 🔧 PASO 7: Verificar que obtuvimos el usuario
      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        debugPrint('❌ Usuario Firebase es null después de autenticación');
        throw Exception('No se pudo completar el inicio de sesión');
      }

      debugPrint('✅ Usuario autenticado en Firebase: ${firebaseUser.uid}');

      // 🔧 PASO 8: Verificar si el usuario ya existe en Firestore
      debugPrint(
          '🔍 Verificando usuario en Firestore (timeout: ${_firestoreTimeout.inSeconds}s)...');
      DocumentSnapshot userDoc;
      try {
        userDoc = await _firestore
            .collection(_usersCollection)
            .doc(firebaseUser.uid)
            .get()
            .timeout(
          _firestoreTimeout,
          onTimeout: () {
            debugPrint(
                '⏰ Timeout obteniendo datos del usuario (${_firestoreTimeout.inSeconds}s)');
            throw Exception('La base de datos está tardando en responder. '
                'Intenta nuevamente en un momento.');
          },
        );
      } catch (e) {
        debugPrint('❌ Error verificando usuario en Firestore: $e');
        if (e.toString().contains('timeout') ||
            e.toString().contains('Timeout')) {
          throw Exception(
              'La base de datos está tardando demasiado en responder. '
              'Intenta nuevamente.');
        }
        throw Exception('Error verificando datos del usuario: $e');
      }

      // Resto del método permanece igual...
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
          name: firebaseUser.displayName ?? googleUser.displayName ?? 'Usuario',
          email: firebaseUser.email ?? googleUser.email,
          photoUrl: firebaseUser.photoURL ?? googleUser.photoUrl,
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
          if (e.toString().contains('timeout') ||
              e.toString().contains('Timeout')) {
            throw Exception('Error guardando usuario en la base de datos. '
                'Intenta nuevamente.');
          }
          throw Exception('Error al crear usuario en la base de datos: $e');
        }

        // Actualizar caché
        await _cacheManager.set(_userCacheKey, newUser);

        // Actualizar datos en Crashlytics
        _updateCrashlyticsUserData(newUser);

        debugPrint('✅ Inicio de sesión exitoso - Usuario nuevo creado');
        return newUser;
      }
    } on FirebaseAuthException catch (e, stack) {
      debugPrint('❌ FirebaseAuthException en signInWithGoogle: ${e.code}');
      FirebaseCrashlytics.instance.recordError(e, stack,
          reason:
              'FirebaseAuthException en inicio de sesión con Google: ${e.code}');
      throw Exception('Error de autenticación: ${e.message}');
    } catch (e, stack) {
      debugPrint('❌ Error general en signInWithGoogle: $e');
      FirebaseCrashlytics.instance.recordError(e, stack,
          reason: 'Error en inicio de sesión con Google');

      // 🔧 MEJORADO: Manejo específico de timeouts
      if (e.toString().contains('timeout') ||
          e.toString().contains('Timeout')) {
        // No re-lanzar el timeout, el mensaje ya es específico
        rethrow;
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        throw Exception(
            'Error de conexión. Verifica tu internet e intenta nuevamente.');
      } else if (e.toString().contains('cancelado')) {
        throw Exception('Inicio de sesión cancelado');
      } else {
        throw Exception(
            'Error al iniciar sesión con Google. Por favor intenta nuevamente.');
      }
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

  @override
  Future<void> signOut() async {
    try {
      debugPrint('🚪 Cerrando sesión...');

      // Limpiar caché al cerrar sesión
      await _cacheManager.remove(_userCacheKey);

      // Cerrar sesión en Google
      await _googleSignIn.signOut();

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
}
