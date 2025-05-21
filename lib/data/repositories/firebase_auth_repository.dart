// lib/data/repositories/firebase_auth_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:goalkeeper_stats/domain/repositories/auth_repository.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/data/models/user_settings.dart';
import 'package:goalkeeper_stats/data/models/subscription_info.dart';
import 'package:goalkeeper_stats/services/cache_manager.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;
  final CacheManager _cacheManager;

  // Colección donde se almacenan los usuarios en Firestore
  static const String _usersCollection = 'users';

  // Clave de caché para el usuario actual
  static const String _userCacheKey = 'current_user';

  /// Constructor con posibilidad de inyección para pruebas
  FirebaseAuthRepository({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
    CacheManager? cacheManager,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(),
        _cacheManager = cacheManager ?? CacheManager();

  @override
  Future<UserModel?> getCurrentUser() async {
    final User? firebaseUser = _firebaseAuth.currentUser;

    if (firebaseUser == null) {
      return null;
    }

    try {
      // Intentar obtener datos del usuario desde caché primero
      final cachedUser = await _cacheManager.get<UserModel>(_userCacheKey);
      if (cachedUser != null) {
        // Verificar si la caché está actualizada comprobando la expiración de suscripción
        if (_isUserCacheValid(cachedUser)) {
          return cachedUser;
        }
      }

      // Si no hay caché o está desactualizada, obtener desde servidor
      final userDoc = await _firestore
          .collection(_usersCollection)
          .doc(firebaseUser.uid)
          .get(const GetOptions(source: Source.server));

      if (userDoc.exists) {
        final userModel = UserModel.fromFirestore(userDoc);

        // Actualizar caché
        await _cacheManager.set(_userCacheKey, userModel);

        // Si tiene suscripción, actualizar metadata de Crashlytics
        _updateCrashlyticsUserData(userModel);

        return userModel;
      } else {
        // Si el documento no existe en Firestore pero sí en Auth, crear nuevo usuario
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
            .set(newUser.toMap());

        // Actualizar caché
        await _cacheManager.set(_userCacheKey, newUser);

        return newUser;
      }
    } catch (e) {
      // Registrar error en Crashlytics pero no exponer detalles al usuario
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al obtener usuario actual');

      // En caso de error de red, intentar usar caché como fallback
      final cachedUser = await _cacheManager.get<UserModel>(_userCacheKey);
      if (cachedUser != null) {
        return cachedUser;
      }

      throw Exception('Error al obtener información del usuario');
    }
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    try {
      // Iniciar el flujo de autenticación de Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Inicio de sesión cancelado por el usuario');
      }

      // Obtener detalles de autenticación
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Crear credencial para Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Iniciar sesión en Firebase
      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception('No se pudo iniciar sesión con Google');
      }

      // Verificar si el usuario ya existe en Firestore
      final userDoc = await _firestore
          .collection(_usersCollection)
          .doc(firebaseUser.uid)
          .get();

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
          name: firebaseUser.displayName ?? 'Usuario',
          email: firebaseUser.email ?? '',
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
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error en inicio de sesión con Google');
      throw Exception('Error al iniciar sesión con Google');
    }
  }

  // Agrega este método en firebase_auth_repository.dart, antes del método signOut():

  @override
  Future<UserModel> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      // Iniciar sesión con Firebase Auth
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final User? firebaseUser = userCredential.user;
      
      if (firebaseUser == null) {
        throw Exception('No se pudo iniciar sesión con email/contraseña');
      }
      
      // Verificar si el usuario existe en Firestore
      final userDoc = await _firestore
          .collection(_usersCollection)
          .doc(firebaseUser.uid)
          .get();
      
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
    } on FirebaseAuthException catch (e) {
      // Registrar error específico de Firebase Auth
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error en inicio de sesión con email: ${e.code}');
      throw Exception('Error de autenticación: ${e.message}');
    } catch (e) {
      // Registrar otros errores
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error en inicio de sesión con email/contraseña');
      throw Exception('Error al iniciar sesión con email/contraseña');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      // Limpiar caché al cerrar sesión
      await _cacheManager.remove(_userCacheKey);

      // Cerrar sesión en Google
      await _googleSignIn.signOut();

      // Cerrar sesión en Firebase
      await _firebaseAuth.signOut();

      // Limpiar datos de usuario en Crashlytics
      FirebaseCrashlytics.instance.setUserIdentifier('');
    } catch (e) {
      FirebaseCrashlytics.instance
          .recordError(e, StackTrace.current, reason: 'Error al cerrar sesión');
      throw Exception('Error al cerrar sesión');
    }
  }

  @override
  Future<bool> isSignedIn() async {
    final currentUser = _firebaseAuth.currentUser;
    return currentUser != null;
  }

  @override
  Future<UserModel> updateUserProfile(UserModel user) async {
    try {
      // Actualizar en Firestore
      await _firestore.collection(_usersCollection).doc(user.id).update({
        'name': user.name,
        'photoUrl': user.photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

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

      return user;
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al actualizar perfil');
      throw Exception('Error al actualizar el perfil');
    }
  }

  @override
  Future<UserModel> updateUserSettings(
      String userId, UserSettings settings) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'settings': settings.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Obtener usuario actualizado
      final userDoc =
          await _firestore.collection(_usersCollection).doc(userId).get();

      final updatedUser = UserModel.fromFirestore(userDoc);

      // Actualizar caché
      await _cacheManager.set(_userCacheKey, updatedUser);

      return updatedUser;
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al actualizar configuraciones');
      throw Exception('Error al actualizar las configuraciones');
    }
  }

  @override
  Future<UserModel> updateSubscription(
      String userId, SubscriptionInfo subscription) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'subscription': subscription.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Obtener usuario actualizado directamente del servidor para asegurar datos frescos
      final userDoc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .get(const GetOptions(source: Source.server));

      final updatedUser = UserModel.fromFirestore(userDoc);

      // Actualizar caché
      await _cacheManager.set(_userCacheKey, updatedUser);

      // Actualizar datos en Crashlytics
      _updateCrashlyticsUserData(updatedUser);

      return updatedUser;
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al actualizar suscripción');
      throw Exception('Error al actualizar la suscripción');
    }
  }

  @override
  Future<void> deleteAccount(String userId) async {
    try {
      // Eliminar datos de usuario de Firestore
      await _firestore.collection(_usersCollection).doc(userId).delete();

      // Eliminar cuenta de Firebase Auth
      final User? currentUser = _firebaseAuth.currentUser;
      if (currentUser != null) {
        await currentUser.delete();
      }

      // Limpiar caché
      await _cacheManager.remove(_userCacheKey);

      // Limpiar datos de usuario en Crashlytics
      FirebaseCrashlytics.instance.setUserIdentifier('');
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error al eliminar cuenta');
      throw Exception('Error al eliminar la cuenta');
    }
  }

  @override
  Stream<UserModel?> get authStateChanges {
    // Convertir el stream de Firebase Auth a stream de UserModel
    return _firebaseAuth.authStateChanges().asyncMap((User? user) async {
      if (user == null) {
        await _cacheManager.remove(_userCacheKey);
        return null;
      }

      try {
        final userDoc =
            await _firestore.collection(_usersCollection).doc(user.uid).get();

        if (userDoc.exists) {
          final userModel = UserModel.fromFirestore(userDoc);
          await _cacheManager.set(_userCacheKey, userModel);
          return userModel;
        } else {
          // Si no existe en Firestore pero sí en Auth, posible error de sincronización
          FirebaseCrashlytics.instance
              .log('Usuario existe en Auth pero no en Firestore: ${user.uid}');
          return null;
        }
      } catch (e) {
        FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
            reason: 'Error en authStateChanges');

        // Intentar usar caché como fallback
        return _cacheManager.get<UserModel>(_userCacheKey);
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
      return user.subscription.expirationDate!.isAfter(now);
    }

    // Para usuarios gratuitos o premium sin fecha de expiración, la caché es válida
    return true;
  }

  /// Actualiza los datos de usuario en Crashlytics para mejor análisis
  void _updateCrashlyticsUserData(UserModel user) {
    FirebaseCrashlytics.instance.setUserIdentifier(user.id);
    FirebaseCrashlytics.instance
        .setCustomKey('isPremium', user.subscription.isPremium);
    FirebaseCrashlytics.instance.setCustomKey('email', user.email);

    if (user.subscription.isPremium && user.subscription.plan != null) {
      FirebaseCrashlytics.instance
          .setCustomKey('subscriptionPlan', user.subscription.plan!);
    }
  }
}
