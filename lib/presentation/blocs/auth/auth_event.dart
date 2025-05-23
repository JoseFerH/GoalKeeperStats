import 'package:equatable/equatable.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/data/models/user_settings.dart';
import 'package:goalkeeper_stats/data/models/subscription_info.dart';

/// Eventos base para el AuthBloc
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Evento para verificar el estado de autenticación
class CheckAuthStatusEvent extends AuthEvent {}

/// Evento para iniciar sesión con Google
class SignInWithGoogleEvent extends AuthEvent {}

/// Evento para iniciar sesión con email y contraseña
class SignInWithEmailPasswordEvent extends AuthEvent {
  final String email;
  final String password;

  const SignInWithEmailPasswordEvent({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

/// Evento para cerrar sesión
class SignOutEvent extends AuthEvent {}

/// Evento para actualizar el perfil del usuario
class UpdateUserEvent extends AuthEvent {
  final UserModel user;

  const UpdateUserEvent(this.user);

  @override
  List<Object?> get props => [user];
}

/// Evento para actualizar las configuraciones del usuario
class UpdateUserSettingsEvent extends AuthEvent {
  final String userId;
  final UserSettings settings;
  final bool allowOffline;

  const UpdateUserSettingsEvent({
    required this.userId,
    required this.settings,
    this.allowOffline = false,
  });

  @override
  List<Object?> get props => [userId, settings, allowOffline];
}

/// Evento para actualizar la suscripción del usuario
class UpdateSubscriptionEvent extends AuthEvent {
  final String userId;
  final SubscriptionInfo subscription;

  const UpdateSubscriptionEvent({
    required this.userId,
    required this.subscription,
  });

  @override
  List<Object?> get props => [userId, subscription];
}

/// Evento para eliminar la cuenta del usuario
class DeleteAccountEvent extends AuthEvent {
  final String userId;

  const DeleteAccountEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}

/// Evento para verificar el estado de la suscripción
class VerifySubscriptionEvent extends AuthEvent {
  final String userId;

  const VerifySubscriptionEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}
