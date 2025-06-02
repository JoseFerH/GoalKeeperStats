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

  // ✅ MÉTODOS FALTANTES IMPLEMENTADOS

  @override
  Future<UserModel> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    print("LocalAuthRepository.signInWithEmailPassword llamado");
    print("Email: $email, Password: ${password.replaceAll(RegExp(r'.'), '*')}");

    // Simular validación básica
    if (email.isEmpty || password.isEmpty) {
      throw Exception('Email y contraseña son requeridos');
    }

    if (!email.contains('@')) {
      throw Exception('Email inválido');
    }

    if (password.length < 6) {
      throw Exception('La contraseña debe tener al menos 6 caracteres');
    }

    // Simular un delay de red
    await Future.delayed(const Duration(seconds: 1));

    _isSignedIn = true;

    // Crear usuario con el email proporcionado
    final user = _fakeUser.copyWith(email: email);

    // Emitir cambio en el stream
    _authStateController.add(user);

    return user;
  }

  @override
  Future<UserModel> registerWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    print("LocalAuthRepository.registerWithEmailPassword llamado");
    print(
        "Email: $email, Name: $displayName, Password: ${password.replaceAll(RegExp(r'.'), '*')}");

    // Simular validación básica
    if (email.isEmpty || password.isEmpty || displayName.isEmpty) {
      throw Exception('Todos los campos son requeridos');
    }

    if (!email.contains('@')) {
      throw Exception('Email inválido');
    }

    if (password.length < 6) {
      throw Exception('La contraseña debe tener al menos 6 caracteres');
    }

    if (displayName.length < 2) {
      throw Exception('El nombre debe tener al menos 2 caracteres');
    }

    // Simular un delay de red
    await Future.delayed(const Duration(seconds: 1));

    _isSignedIn = true;

    // Crear nuevo usuario con los datos proporcionados
    final newUser = UserModel.newUser(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      name: displayName,
      email: email,
      photoUrl: null,
    );

    // Emitir cambio en el stream
    _authStateController.add(newUser);

    return newUser;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    print("LocalAuthRepository.sendPasswordResetEmail llamado");
    print("Email: $email");

    // Simular validación básica
    if (email.isEmpty) {
      throw Exception('Email es requerido');
    }

    if (!email.contains('@')) {
      throw Exception('Email inválido');
    }

    // Simular un delay de red
    await Future.delayed(const Duration(milliseconds: 800));

    print("Email de restablecimiento enviado a: $email (simulado)");
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    print("LocalAuthRepository.updatePassword llamado");
    print("Nueva contraseña: ${newPassword.replaceAll(RegExp(r'.'), '*')}");

    // Verificar que hay un usuario autenticado
    if (!_isSignedIn) {
      throw Exception('No hay usuario autenticado');
    }

    // Simular validación básica
    if (newPassword.isEmpty) {
      throw Exception('La nueva contraseña es requerida');
    }

    if (newPassword.length < 6) {
      throw Exception('La contraseña debe tener al menos 6 caracteres');
    }

    // Simular un delay de red
    await Future.delayed(const Duration(milliseconds: 500));

    print("Contraseña actualizada exitosamente (simulado)");
  }

  @override
  Future<void> reauthenticateWithPassword(String currentPassword) async {
    print("LocalAuthRepository.reauthenticateWithPassword llamado");
    print(
        "Contraseña actual: ${currentPassword.replaceAll(RegExp(r'.'), '*')}");

    // Verificar que hay un usuario autenticado
    if (!_isSignedIn) {
      throw Exception('No hay usuario autenticado');
    }

    // Simular validación básica
    if (currentPassword.isEmpty) {
      throw Exception('La contraseña actual es requerida');
    }

    if (currentPassword.length < 6) {
      throw Exception('Contraseña inválida');
    }

    // Simular un delay de red
    await Future.delayed(const Duration(milliseconds: 800));

    // En un entorno local, siempre "exitoso" para facilitar desarrollo
    print("Re-autenticación exitosa (simulado)");
  }

  // ✅ MÉTODOS EXISTENTES (sin cambios)

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
