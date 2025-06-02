import 'package:equatable/equatable.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/data/models/user_settings.dart';
import 'package:goalkeeper_stats/data/models/subscription_info.dart';

/// Eventos base para el AuthBloc
abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

/// Verificar estado de autenticación al iniciar la app
class CheckAuthStatusEvent extends AuthEvent {}

/// Iniciar sesión con Google
class SignInWithGoogleEvent extends AuthEvent {}

/// Iniciar sesión con email y contraseña
class SignInWithEmailPasswordEvent extends AuthEvent {
  final String email;
  final String password;

  SignInWithEmailPasswordEvent({
    required this.email,
    required this.password,
  });

  @override
  List<Object> get props => [email, password];
}

/// Registrar nuevo usuario con email y contraseña
class RegisterWithEmailPasswordEvent extends AuthEvent {
  final String email;
  final String password;
  final String displayName;

  RegisterWithEmailPasswordEvent({
    required this.email,
    required this.password,
    required this.displayName,
  });

  @override
  List<Object> get props => [email, password, displayName];
}

/// Enviar email de recuperación de contraseña
class SendPasswordResetEvent extends AuthEvent {
  final String email;

  SendPasswordResetEvent({required this.email});

  @override
  List<Object> get props => [email];
}

/// Actualizar contraseña del usuario
class UpdatePasswordEvent extends AuthEvent {
  final String currentPassword;
  final String newPassword;

  UpdatePasswordEvent({
    required this.currentPassword,
    required this.newPassword,
  });

  @override
  List<Object> get props => [currentPassword, newPassword];
}

/// Cerrar sesión
class SignOutEvent extends AuthEvent {}

/// Actualizar datos del usuario
class UpdateUserEvent extends AuthEvent {
  final UserModel user;

  UpdateUserEvent({required this.user});

  @override
  List<Object> get props => [user];
}

/// Actualizar configuraciones del usuario
class UpdateUserSettingsEvent extends AuthEvent {
  final UserSettings settings;
  final bool allowOffline;

  UpdateUserSettingsEvent({
    required this.settings,
    this.allowOffline = false,
  });

  @override
  List<Object> get props => [settings, allowOffline];
}

/// Actualizar suscripción del usuario
class UpdateSubscriptionEvent extends AuthEvent {
  final SubscriptionInfo subscription;

  UpdateSubscriptionEvent({required this.subscription});

  @override
  List<Object> get props => [subscription];
}

/// Verificar estado de suscripción con el servidor
class VerifySubscriptionEvent extends AuthEvent {}
