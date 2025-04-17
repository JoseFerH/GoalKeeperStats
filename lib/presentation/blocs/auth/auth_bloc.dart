import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:goalkeeper_stats/services/analytics_service.dart';
import 'package:goalkeeper_stats/services/connectivity_service.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/domain/repositories/auth_repository.dart';
import 'package:goalkeeper_stats/presentation/blocs/auth/auth_event.dart';
import 'package:goalkeeper_stats/presentation/blocs/auth/auth_state.dart';

/// BLoC que maneja la lógica de autenticación con Firebase
///
/// Gestiona el flujo de autenticación y mantiene el estado actual
/// del usuario en la aplicación, con integración completa de Firebase.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final AnalyticsService _analyticsService;
  final FirebaseCrashlytics _crashlytics;
  final ConnectivityService _connectivityService;

  // Constructor con dependencias inyectadas
  AuthBloc({
    required AuthRepository authRepository,
    required AnalyticsService analyticsService,
    required FirebaseCrashlytics crashlytics,
    required ConnectivityService connectivityService,
  })  : _authRepository = authRepository,
        _analyticsService = analyticsService,
        _crashlytics = crashlytics,
        _connectivityService = connectivityService,
        super(AuthInitialState()) {
    on<CheckAuthStatusEvent>(_onCheckAuthStatus);
    on<SignInWithGoogleEvent>(_onSignInWithGoogle);
    on<SignOutEvent>(_onSignOut);
    on<UpdateUserEvent>(_onUpdateUser);
    on<UpdateUserSettingsEvent>(_onUpdateUserSettings);
    on<UpdateSubscriptionEvent>(_onUpdateSubscription);
    on<VerifySubscriptionEvent>(_onVerifySubscription);
  }

  /// Verifica si hay un usuario autenticado al iniciar la app
  Future<void> _onCheckAuthStatus(
    CheckAuthStatusEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoadingState());
    try {
      final isOnline = await _connectivityService.checkConnectivity();
      if (!isOnline) {
        _crashlytics.log('Verificando autenticación sin conexión');
        // Intentar obtener datos de caché o informar al usuario
      }

      final isSignedIn = await _authRepository.isSignedIn();

      if (isSignedIn) {
        final user = await _authRepository.getCurrentUser();
        if (user != null) {
          // Configurar identificadores para análisis y crashlytics
          await _crashlytics.setUserIdentifier(user.id);
          await _analyticsService.setUserId(user.id);
          await _analyticsService.updateUserFromModel(user);

          emit(AuthenticatedState(user));
        } else {
          emit(UnauthenticatedState());
        }
      } else {
        emit(UnauthenticatedState());
      }
    } catch (e, stack) {
      // Registrar error en Crashlytics
      _crashlytics.recordError(e, stack,
          reason: 'Error al verificar estado de autenticación');

      debugPrint('Error al verificar autenticación: $e');
      emit(AuthErrorState(
          'Error al verificar autenticación. Verifica tu conexión a internet e intenta nuevamente.'));
    }
  }

  /// Maneja el inicio de sesión con Google
  Future<void> _onSignInWithGoogle(
    SignInWithGoogleEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoadingState());
    try {
      // Verificar conectividad
      final isOnline = await _connectivityService.checkConnectivity();
      if (!isOnline) {
        emit(AuthErrorState(
            'No hay conexión a internet. Por favor, conéctate e intenta nuevamente.'));
        return;
      }

      final user = await _authRepository.signInWithGoogle();

      // Registrar evento de inicio de sesión
      await _analyticsService.logLogin('google');

      // Configurar identificadores para servicios
      await _crashlytics.setUserIdentifier(user.id);
      await _analyticsService.setUserId(user.id);
      await _analyticsService.updateUserFromModel(user);

      emit(AuthenticatedState(user));
    } catch (e, stack) {
      // Registrar error en Crashlytics
      _crashlytics.recordError(e, stack,
          reason: 'Error en inicio de sesión con Google');

      // Registrar evento de error
      _analyticsService.logError('auth', 'Error en inicio de sesión: $e');

      debugPrint('Error en inicio de sesión: $e');
      emit(AuthErrorState(
          'No se pudo iniciar sesión. Por favor intenta nuevamente.'));
    }
  }

  /// Maneja el cierre de sesión
  Future<void> _onSignOut(
    SignOutEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoadingState());
    try {
      // Registrar evento de cierre de sesión
      await _analyticsService.logLogout();

      // Limpiar datos de usuario en servicios
      await _crashlytics.setUserIdentifier('');
      await _analyticsService.clearUserData();

      await _authRepository.signOut();
      emit(UnauthenticatedState());
    } catch (e, stack) {
      // Registrar error en Crashlytics
      _crashlytics.recordError(e, stack, reason: 'Error al cerrar sesión');

      debugPrint('Error al cerrar sesión: $e');
      emit(AuthErrorState(
          'Error al cerrar sesión. Por favor intenta nuevamente.'));
    }
  }

  /// Actualiza los datos del usuario
  Future<void> _onUpdateUser(
    UpdateUserEvent event,
    Emitter<AuthState> emit,
  ) async {
    final currentState = state;
    if (currentState is AuthenticatedState) {
      emit(AuthLoadingState());
      try {
        // Verificar conectividad
        final isOnline = await _connectivityService.checkConnectivity();
        if (!isOnline) {
          emit(AuthErrorState(
              'No hay conexión a internet. Los cambios se aplicarán cuando te conectes.'));
          emit(currentState);
          return;
        }

        final updatedUser = await _authRepository.updateUserProfile(event.user);

        // Actualizar datos de usuario en servicios
        await _analyticsService.updateUserFromModel(updatedUser);

        emit(AuthenticatedState(updatedUser));
      } catch (e, stack) {
        // Registrar error en Crashlytics
        _crashlytics.recordError(e, stack,
            reason: 'Error al actualizar perfil de usuario');

        debugPrint('Error al actualizar perfil: $e');
        emit(AuthErrorState(
            'Error al actualizar perfil. Por favor intenta nuevamente.'));

        // Volver al estado anterior si falla
        emit(currentState);
      }
    }
  }

  /// Actualiza las configuraciones del usuario
  Future<void> _onUpdateUserSettings(
    UpdateUserSettingsEvent event,
    Emitter<AuthState> emit,
  ) async {
    final currentState = state;
    if (currentState is AuthenticatedState) {
      emit(AuthLoadingState());
      try {
        // Verificar conectividad
        final isOnline = await _connectivityService.checkConnectivity();
        if (!isOnline && !event.allowOffline) {
          emit(AuthErrorState(
              'No hay conexión a internet. Los cambios se aplicarán cuando te conectes.'));
          emit(currentState);
          return;
        }

        // Registrar cambios de configuración
        if (event.settings.language != currentState.user.settings.language) {
          await _analyticsService.logLanguageChanged(event.settings.language);
        }

        if (event.settings.darkMode != currentState.user.settings.darkMode) {
          await _analyticsService.logThemeChanged(event.settings.darkMode);
        }

        final updatedUser = await _authRepository.updateUserSettings(
          currentState.user.id,
          event.settings,
        );

        emit(AuthenticatedState(updatedUser));
      } catch (e, stack) {
        // Registrar error en Crashlytics
        _crashlytics.recordError(e, stack,
            reason: 'Error al actualizar configuraciones de usuario');

        debugPrint('Error al actualizar configuraciones: $e');
        emit(AuthErrorState(
            'Error al guardar configuraciones. Por favor intenta nuevamente.'));

        // Volver al estado anterior si falla
        emit(currentState);
      }
    }
  }

  /// Actualiza la información de suscripción
  Future<void> _onUpdateSubscription(
    UpdateSubscriptionEvent event,
    Emitter<AuthState> emit,
  ) async {
    final currentState = state;
    if (currentState is AuthenticatedState) {
      emit(AuthLoadingState());
      try {
        // Verificar conectividad (crítico para suscripciones)
        final isOnline = await _connectivityService.checkConnectivity();
        if (!isOnline) {
          emit(AuthErrorState(
              'Se requiere conexión a internet para actualizar la suscripción.'));
          emit(currentState);
          return;
        }

        final updatedUser = await _authRepository.updateSubscription(
          currentState.user.id,
          event.subscription,
        );

        // Actualizar estado premium en servicios
        await _analyticsService.setUserProperties(
          userId: updatedUser.id,
          isPremium: updatedUser.subscription.isPremium,
          subscriptionPlan: updatedUser.subscription.plan,
        );

        await _crashlytics.setCustomKey(
            'isPremium', updatedUser.subscription.isPremium);
        if (updatedUser.subscription.plan != null) {
          await _crashlytics.setCustomKey(
              'subscriptionPlan', updatedUser.subscription.plan!);
        }

        emit(AuthenticatedState(updatedUser));
      } catch (e, stack) {
        // Registrar error en Crashlytics
        _crashlytics.recordError(e, stack,
            reason: 'Error al actualizar suscripción');

        debugPrint('Error al actualizar suscripción: $e');
        emit(AuthErrorState(
            'Error al actualizar suscripción. Por favor intenta nuevamente.'));

        // Volver al estado anterior si falla
        emit(currentState);
      }
    }
  }

  /// Verifica el estado actual de la suscripción con el servidor
  Future<void> _onVerifySubscription(
    VerifySubscriptionEvent event,
    Emitter<AuthState> emit,
  ) async {
    final currentState = state;
    if (currentState is AuthenticatedState) {
      try {
        // No emitimos estado de carga para no interrumpir la experiencia

        // Verificar conectividad
        final isOnline = await _connectivityService.checkConnectivity();
        if (!isOnline) {
          // Si no hay conexión, continuamos con el estado actual
          _crashlytics.log(
              'Verificación de suscripción diferida por falta de conexión');
          return;
        }

        // Obtener datos actualizados del usuario
        final latestUser = await _authRepository.getCurrentUser();

        if (latestUser != null) {
          // Verificar si la información de suscripción ha cambiado
          final currentSub = currentState.user.subscription;
          final latestSub = latestUser.subscription;

          final hasChanged = currentSub.type != latestSub.type ||
              currentSub.plan != latestSub.plan ||
              currentSub.expirationDate != latestSub.expirationDate;

          if (hasChanged) {
            // Si ha cambiado, actualizar estado
            emit(AuthenticatedState(latestUser));

            // Actualizar servicios
            await _analyticsService.updateUserFromModel(latestUser);
            await _crashlytics.setCustomKey(
                'isPremium', latestUser.subscription.isPremium);
            if (latestUser.subscription.plan != null) {
              await _crashlytics.setCustomKey(
                  'subscriptionPlan', latestUser.subscription.plan!);
            }

            debugPrint('Estado de suscripción actualizado: ${latestSub.type}');
          }
        }
      } catch (e, stack) {
        // Registrar error sin interrumpir la experiencia
        _crashlytics.recordError(e, stack,
            reason: 'Error al verificar estado de suscripción');

        debugPrint('Error al verificar suscripción: $e');
        // No emitimos estado de error para no interrumpir la experiencia
      }
    }
  }
}
