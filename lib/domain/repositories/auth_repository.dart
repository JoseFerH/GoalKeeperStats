import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/data/models/user_settings.dart';
import 'package:goalkeeper_stats/data/models/subscription_info.dart';

/// Interfaz que define las operaciones de autenticación
abstract class AuthRepository {
  /// Obtiene el usuario actualmente autenticado
  Future<UserModel?> getCurrentUser();

  /// Inicia sesión con Google
  Future<UserModel> signInWithGoogle();

  /// Inicia sesión con email y contraseña
  Future<UserModel> signInWithEmailPassword({
    required String email,
    required String password,
  });

  /// Registra un nuevo usuario con email y contraseña
  Future<UserModel> registerWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
  });

  /// Envía un email de recuperación de contraseña
  Future<void> sendPasswordResetEmail(String email);

  /// Actualiza la contraseña del usuario actual
  Future<void> updatePassword(String newPassword);

  /// Reautentica al usuario con su contraseña actual
  Future<void> reauthenticateWithPassword(String currentPassword);

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
