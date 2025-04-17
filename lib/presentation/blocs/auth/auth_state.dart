import 'package:equatable/equatable.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';

/// Estados posibles del proceso de autenticación con Firebase
///
/// Define todos los estados en los que puede estar el sistema
/// de autenticación, desde no inicializado hasta error.
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Estado inicial, aún no se ha verificado la autenticación
///
/// Este es el estado al iniciar la aplicación, antes de comprobar
/// si hay una sesión activa en Firebase Auth.
class AuthInitialState extends AuthState {}

/// Estado de carga mientras se verifica o procesa la autenticación
///
/// Se muestra durante operaciones asíncronas como iniciar sesión,
/// verificar estado de sesión o actualizar datos del usuario.
class AuthLoadingState extends AuthState {}

/// Estado cuando el usuario está autenticado correctamente
///
/// Contiene el modelo de usuario con datos obtenidos de Firestore,
/// incluyendo su información de suscripción y preferencias.
class AuthenticatedState extends AuthState {
  final UserModel user;

  const AuthenticatedState(this.user);

  @override
  List<Object?> get props => [user];
}

/// Estado cuando el usuario no está autenticado
///
/// Indica que no hay sesión activa en Firebase Auth o
/// que el usuario ha cerrado sesión.
class UnauthenticatedState extends AuthState {}

/// Estado cuando ha ocurrido un error en la autenticación
///
/// Contiene un mensaje descriptivo sobre el error ocurrido
/// durante el proceso de autenticación o actualización de datos.
class AuthErrorState extends AuthState {
  final String message;

  const AuthErrorState(this.message);

  @override
  List<Object?> get props => [message];
}
