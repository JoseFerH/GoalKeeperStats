import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/data/models/user_settings.dart';
import 'package:goalkeeper_stats/data/models/subscription_info.dart';

/// Interfaz que define las operaciones de autenticación
abstract class AuthRepository {
  /// Obtiene el usuario actualmente autenticado
  Future<UserModel?> getCurrentUser();

  /// Inicia sesión con Google
  Future<UserModel> signInWithGoogle();

  /// Cierra la sesión del usuario actual
  Future<void> signOut();

  /// Verifica si hay un usuario actualmente autenticado
  Future<bool> isSignedIn();

  /// Actualiza la información del perfil del usuario
  Future<UserModel> updateUserProfile(UserModel user);

  /// Actualiza las configuraciones del usuario
  Future<UserModel> updateUserSettings(String userId, UserSettings settings);

  /// Actualiza la información de suscripción del usuario
  Future<UserModel> updateSubscription(
    String userId,
    SubscriptionInfo subscription,
  );

  /// Elimina la cuenta del usuario
  Future<void> deleteAccount(String userId);

  /// Obtiene un stream con los cambios en el estado de autenticación
  Stream<UserModel?> get authStateChanges;
}
