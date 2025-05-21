import 'package:equatable/equatable.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/data/models/user_settings.dart';
import 'package:goalkeeper_stats/data/models/subscription_info.dart';

/// Eventos relacionados con la autenticación
///
/// Define todas las acciones que pueden desencadenar cambios
/// en el estado de autenticación.
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Evento para verificar si el usuario ya está autenticado
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

/// Evento para actualizar datos del usuario
class UpdateUserEvent extends AuthEvent {
  final UserModel user;

  const UpdateUserEvent(this.user);

  @override
  List<Object?> get props => [user];
}

/// Evento para actualizar configuraciones de usuario
class UpdateUserSettingsEvent extends AuthEvent {
  final UserSettings settings;
  final bool allowOffline;

  /// Constructor para actualizar configuraciones
  /// [allowOffline] indica si se permite guardar configuraciones localmente
  /// cuando no hay conexión a internet
  const UpdateUserSettingsEvent(this.settings, {this.allowOffline = false});

  @override
  List<Object?> get props => [settings, allowOffline];
}

/// Evento para actualizar información de suscripción
class UpdateSubscriptionEvent extends AuthEvent {
  final SubscriptionInfo subscription;

  const UpdateSubscriptionEvent(this.subscription);

  @override
  List<Object?> get props => [subscription];
}

/// Evento para verificar el estado actual de la suscripción
///
/// Este evento se usa para actualizaciones periódicas del estado
/// de la suscripción desde el servidor
class VerifySubscriptionEvent extends AuthEvent {}