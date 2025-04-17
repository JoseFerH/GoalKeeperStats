import 'dart:async';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/data/models/user_settings.dart';
import 'package:goalkeeper_stats/data/models/subscription_info.dart';
import 'package:goalkeeper_stats/domain/repositories/auth_repository.dart';

/// Implementación de AuthRepository que proporciona un usuario de prueba
///
/// Útil para desarrollo y pruebas sin depender de Firebase Auth
class MockAuthRepository implements AuthRepository {
  // Usuario de prueba predefinido con Premium
  final UserModel _testUser = UserModel(
    id: 'test_user_123',
    name: 'Usuario de Prueba',
    email: 'test@example.com',
    photoUrl: null,
    subscription: SubscriptionInfo(
      type: 'premium',
      expirationDate: DateTime.now().add(const Duration(days: 365)),
      plan: 'annual',
    ),
    settings: UserSettings(
      language: 'es',
      darkMode: false,
      notificationsEnabled: true,
    ),
  );

  final _authController = StreamController<UserModel?>.broadcast();

  MockAuthRepository() {
    // Iniciar con usuario autenticado
    _authController.add(_testUser);
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    // No simulamos retraso para acelerar el inicio
    return _testUser;
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    // Simular un breve retraso para mostrar la carga
    await Future.delayed(const Duration(milliseconds: 300));
    _authController.add(_testUser);
    return _testUser;
  }

  @override
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _authController.add(null);
  }

  @override
  Future<bool> isSignedIn() async {
    return true; // Siempre autenticado para pruebas
  }

  @override
  Future<UserModel> updateUserProfile(UserModel user) async {
    return user;
  }

  @override
  Future<UserModel> updateUserSettings(
      String userId, UserSettings settings) async {
    final updatedUser = _testUser.copyWith(settings: settings);
    _authController.add(updatedUser);
    return updatedUser;
  }

  @override
  Future<UserModel> updateSubscription(
      String userId, SubscriptionInfo subscription) async {
    final updatedUser = _testUser.copyWith(subscription: subscription);
    _authController.add(updatedUser);
    return updatedUser;
  }

  @override
  Future<void> deleteAccount(String userId) async {
    _authController.add(null);
  }

  @override
  Stream<UserModel?> get authStateChanges => _authController.stream;

  // Cerrar recursos
  void dispose() {
    _authController.close();
  }
}
