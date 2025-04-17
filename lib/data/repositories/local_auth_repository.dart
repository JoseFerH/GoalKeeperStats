// lib/data/repositories/local_auth_repository.dart

import 'package:goalkeeper_stats/domain/repositories/auth_repository.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/data/models/subscription_info.dart';
import 'package:goalkeeper_stats/data/models/user_settings.dart';
import 'dart:async';

class LocalAuthRepository implements AuthRepository {
  // Usuario ficticio para desarrollo local
  final UserModel _fakeUser = UserModel.newUser(
    id: 'local_user_123',
    name: 'Usuario Local',
    email: 'usuario@ejemplo.com',
    photoUrl: null,
  );

  // Estado de autenticación simulado
  bool _isSignedIn = true; // Inicialmente true para saltar login

  // Controlador para el stream de cambios de autenticación
  final _authStateController = StreamController<UserModel?>.broadcast();

  LocalAuthRepository() {
    // Emitir el estado inicial en el stream
    _authStateController.add(_isSignedIn ? _fakeUser : null);
  }

  @override
  Stream<UserModel?> get authStateChanges => _authStateController.stream;

  @override
  Future<UserModel?> getCurrentUser() async {
    print(
        "LocalAuthRepository.getCurrentUser llamado, isSignedIn=$_isSignedIn");
    // Simular un pequeño delay para emular una operación de red
    await Future.delayed(const Duration(milliseconds: 300));
    return _isSignedIn ? _fakeUser : null;
  }

  @override
  Future<bool> isSignedIn() async {
    print("LocalAuthRepository.isSignedIn: $_isSignedIn");
    // Simular un pequeño delay
    await Future.delayed(const Duration(milliseconds: 100));
    return _isSignedIn;
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    print("LocalAuthRepository.signInWithGoogle llamado");
    // Simular un pequeño delay para emular una operación de red
    await Future.delayed(const Duration(seconds: 1));
    _isSignedIn = true;

    // Emitir cambio en el stream
    _authStateController.add(_fakeUser);

    return _fakeUser;
  }

  @override
  Future<void> signOut() async {
    print("LocalAuthRepository.signOut llamado");
    // Simular un pequeño delay para emular una operación de red
    await Future.delayed(const Duration(milliseconds: 500));
    _isSignedIn = false;

    // Emitir cambio en el stream
    _authStateController.add(null);
  }

  @override
  Future<void> deleteAccount(String userId) async {
    print("LocalAuthRepository.deleteAccount llamado");
    // Simular eliminación
    await Future.delayed(const Duration(milliseconds: 500));
    _isSignedIn = false;

    // Emitir cambio en el stream
    _authStateController.add(null);
  }

  @override
  Future<UserModel> updateSubscription(
      String userId, SubscriptionInfo subscription) async {
    print("LocalAuthRepository.updateSubscription llamado");
    // Crear un usuario actualizado
    final updatedUser = _fakeUser.copyWith(subscription: subscription);

    // Simular retraso de red
    await Future.delayed(const Duration(milliseconds: 300));

    return updatedUser;
  }

  @override
  Future<UserModel> updateUserProfile(UserModel user) async {
    print("LocalAuthRepository.updateUserProfile llamado");
    // Simular retraso de red
    await Future.delayed(const Duration(milliseconds: 300));

    return user;
  }

  @override
  Future<UserModel> updateUserSettings(
      String userId, UserSettings settings) async {
    print("LocalAuthRepository.updateUserSettings llamado");
    // Crear un usuario actualizado
    final updatedUser = _fakeUser.copyWith(settings: settings);

    // Simular retraso de red
    await Future.delayed(const Duration(milliseconds: 300));

    return updatedUser;
  }

  // Método para simular cierre del repositorio
  void dispose() {
    _authStateController.close();
  }
}
