import 'package:equatable/equatable.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';

/// Estados base para el AuthBloc
abstract class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

/// Estado inicial
class AuthInitialState extends AuthState {}

/// Estado de carga
class AuthLoadingState extends AuthState {}

/// Estado cuando el usuario está autenticado
class AuthenticatedState extends AuthState {
  final UserModel user;

  AuthenticatedState(this.user);

  @override
  List<Object> get props => [user];
}

/// Estado cuando el usuario no está autenticado
class UnauthenticatedState extends AuthState {}

/// Estado de error
class AuthErrorState extends AuthState {
  final String message;

  AuthErrorState(this.message);

  @override
  List<Object> get props => [message];
}

/// Estado cuando se envía email de recuperación
class PasswordResetSentState extends AuthState {
  final String email;

  PasswordResetSentState(this.email);

  @override
  List<Object> get props => [email];
}

/// Estado cuando se actualiza la contraseña exitosamente
class PasswordUpdatedState extends AuthState {}
