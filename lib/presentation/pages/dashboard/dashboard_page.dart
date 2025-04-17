import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/data/repositories/firebase_auth_repository.dart';
import 'package:goalkeeper_stats/data/repositories/firebase_goalkeeper_passes_repository.dart';
import 'package:goalkeeper_stats/data/repositories/firebase_matches_repository.dart';
import 'package:goalkeeper_stats/data/repositories/firebase_shots_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/auth_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/matches_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/shots_repository.dart';
import 'package:goalkeeper_stats/domain/repositories/goalkeeper_passes_repository.dart';
import 'package:goalkeeper_stats/presentation/blocs/auth/auth_bloc.dart';
import 'package:goalkeeper_stats/presentation/blocs/auth/auth_event.dart';
import 'package:goalkeeper_stats/presentation/blocs/auth/auth_state.dart';
import 'package:goalkeeper_stats/presentation/pages/auth/login_page.dart';
import 'package:goalkeeper_stats/services/connectivity_service.dart';
import 'package:goalkeeper_stats/services/firebase_crashlytics_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
// Importar las pestañas aquí - asegúrate de que las rutas sean correctas
import 'package:goalkeeper_stats/presentation/pages/dashboard/home_tab.dart';
import 'package:goalkeeper_stats/presentation/pages/match_records/matches_tab.dart';
import 'package:goalkeeper_stats/presentation/pages/shot_records/shot_entry_tab.dart';
import 'package:goalkeeper_stats/presentation/pages/stats/stats_tab.dart';
import 'package:goalkeeper_stats/presentation/pages/subscription/profile_tab.dart';

/// Página principal del dashboard con navegación por pestañas
class DashboardPage extends StatefulWidget {
  final UserModel user;

  const DashboardPage({
    super.key,
    required this.user,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int _previousIndex = 0;
  bool _needsRefresh = false;
  late UserModel _currentUser;
  late AuthBloc _authBloc;

  // Repositorios Firebase
  late MatchesRepository _matchesRepository;
  late ShotsRepository _shotsRepository;
  late GoalkeeperPassesRepository _passesRepository;

  // Servicios
  late ConnectivityService _connectivityService;
  late FirebaseCrashlyticsService _crashlyticsService;

  // Controlador de animación para las pestañas
  late TabController _tabController;

  // Estado de conectividad
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;

    // Inicializar servicios
    _connectivityService = ConnectivityService();
    _crashlyticsService = FirebaseCrashlyticsService();

    // Configurar Crashlytics con datos de usuario
    _setupCrashlytics();

    // Inicializar repositorios Firebase
    _initRepositories();

    // Monitorear conectividad
    _monitorConnectivity();

    // Inicializar controlador de animación
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  void _setupCrashlytics() {
    _crashlyticsService.setUserData(
      userId: _currentUser.id,
      email: _currentUser.email,
      isPremium: _currentUser.subscription.isPremium,
      subscriptionPlan: _currentUser.subscription.plan,
    );
  }

  void _initRepositories() {
    // Inicializar repositorios Firebase con el id del usuario
    _matchesRepository = FirebaseMatchesRepository(userId: _currentUser.id);
    _shotsRepository = FirebaseShotsRepository(userId: _currentUser.id);
    _passesRepository =
        FirebaseGoalkeeperPassesRepository(userId: _currentUser.id);
  }

  void _monitorConnectivity() {
    // Verificar conectividad inicial
    _connectivityService.checkConnectivity().then((isConnected) {
      setState(() {
        _isConnected = isConnected;
      });

      // Si está desconectado, mostrar mensaje
      if (!isConnected && mounted) {
        _connectivityService.showConnectivitySnackBar(context);
      }
    });

    // Escuchar cambios en la conectividad
    _connectivityService.onConnectivityChanged.listen((result) {
      final wasConnected = _isConnected;
      final isConnected = result == ConnectivityResult.wifi ||
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.ethernet;

      setState(() {
        _isConnected = isConnected;
      });

      // Mostrar snackbar solo si hay cambio de estado
      if (wasConnected != isConnected && mounted) {
        _connectivityService.showConnectivitySnackBar(context);
      }
    });
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _previousIndex = _currentIndex;
        _currentIndex = _tabController.index;

        // Si venimos de la pestaña de registro (2) y vamos a inicio (0) o estadísticas (3)
        if (_previousIndex == 2 && (_currentIndex == 0 || _currentIndex == 3)) {
          _needsRefresh = true;
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _connectivityService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Crear authBloc con repository Firebase
    final authRepository = FirebaseAuthRepository();
    _authBloc = AuthBloc(authRepository: authRepository);

    return BlocProvider.value(
      value: _authBloc,
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          // Si el usuario cierra sesión, redirigir a la pantalla de login
          if (state is UnauthenticatedState) {
            _crashlyticsService.clearUserData();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const LoginPage()),
            );
          }

          // Si el BLoC actualiza al usuario, actualizar nuestro estado local
          if (state is AuthenticatedState) {
            setState(() {
              _currentUser = state.user;

              // Actualizar datos en Crashlytics
              _setupCrashlytics();
            });
          }

          // Manejo de errores
          if (state is AuthErrorState) {
            _crashlyticsService.recordError(
              state.message,
              StackTrace.current,
              reason: 'Error de autenticación en dashboard',
            );

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${state.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: Scaffold(
          body: _buildBody(),
          bottomNavigationBar: _buildBottomNavigationBar(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    // Si no hay conexión, mostrar indicador en la parte superior
    if (!_isConnected) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.red,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: const Text(
              'Sin conexión. Funcionalidad limitada disponible.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
          ),
          Expanded(
            child: _buildContent(),
          ),
        ],
      );
    }

    return _buildContent();
  }

  Widget _buildContent() {
    return IndexedStack(
      index: _currentIndex,
      children: [
        // Página 0: Inicio
        HomeTab(
          user: _currentUser,
          shotsRepository: _shotsRepository,
          matchesRepository: _matchesRepository,
          forceRefresh: _currentIndex == 0 && _needsRefresh,
          isConnected: _isConnected,
        ),

        // Página 1: Partidos
        MatchesTab(
          user: _currentUser,
          matchesRepository: _matchesRepository,
          isConnected: _isConnected,
        ),

        // Página 2: Registrar tiro
        ShotEntryTab(
          user: _currentUser,
          matchesRepository: _matchesRepository,
          shotsRepository: _shotsRepository,
          passesRepository: _passesRepository,
          onDataRegistered: _onDataRegistered,
          isConnected: _isConnected,
        ),

        // Página 3: Estadísticas
        StatsTab(
          user: _currentUser,
          shotsRepository: _shotsRepository,
          passesRepository: _passesRepository,
          matchesRepository: _matchesRepository,
          forceRefresh: _currentIndex == 3 && _needsRefresh,
          isConnected: _isConnected,
        ),

        // Página 4: Perfil
        ProfileTab(
          user: _currentUser,
          authBloc: _authBloc,
          onUserUpdated: _updateUser,
          isConnected: _isConnected,
        ),
      ],
    );
  }

  // Método para manejar la notificación de un tiro o saque registrado
  void _onDataRegistered() {
    setState(() {
      _needsRefresh = true;
    });
  }

  // Callback para actualizar el usuario desde cualquier pestaña
  void _updateUser(UserModel updatedUser) {
    setState(() {
      _currentUser = updatedUser;
    });

    // También actualizar el BLoC para mantener consistencia
    _authBloc.add(UpdateUserEvent(updatedUser));

    // Actualizar información en Crashlytics
    _setupCrashlytics();
  }

  Widget _buildBottomNavigationBar() {
    final ThemeData theme = Theme.of(context);

    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        // Cambiar pestaña actual
        setState(() {
          _previousIndex = _currentIndex; // Guardar índice anterior
          _currentIndex = index;

          // Si venimos de la pestaña de registro (2) y vamos a inicio (0) o estadísticas (3)
          if (_previousIndex == 2 &&
              (_currentIndex == 0 || _currentIndex == 3)) {
            _needsRefresh = true;
          } else {
            // Resetear el flag si no es un cambio que requiera actualización
            _needsRefresh = false;
          }

          // Sincronizar con tab controller
          _tabController.animateTo(index);
        });
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: theme.colorScheme.primary,
      unselectedItemColor: theme.colorScheme.onSurfaceVariant,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Inicio',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.sports),
          label: 'Partidos',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.add_circle, size: 32),
          label: 'Registrar',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart),
          label: 'Estadísticas',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ],
    );
  }
}
