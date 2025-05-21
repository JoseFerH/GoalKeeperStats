import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/data/models/user_settings.dart';
import 'package:goalkeeper_stats/presentation/blocs/auth/auth_bloc.dart';
import 'package:goalkeeper_stats/presentation/blocs/auth/auth_event.dart';
import 'package:goalkeeper_stats/presentation/pages/auth/edit_profile_page.dart';
import 'package:goalkeeper_stats/presentation/pages/subscription/subscription_page.dart';
import 'package:goalkeeper_stats/presentation/pages/auth/login_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:intl/intl.dart';
import 'package:goalkeeper_stats/core/theme/app_theme.dart';
// Importaciones para Firebase
import 'package:goalkeeper_stats/services/connectivity_service.dart';
import 'package:goalkeeper_stats/services/firebase_crashlytics_service.dart';
import 'package:goalkeeper_stats/services/purchase_service.dart';
import 'package:goalkeeper_stats/services/analytics_service.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:provider/provider.dart';

/// Pestaña de perfil y configuración
///
/// Permite al usuario gestionar su información personal,
/// configuración de la aplicación y acceso a suscripciones.
class ProfileTab extends StatefulWidget {
  final UserModel user;
  final AuthBloc authBloc;
  final bool isConnected; // <-- Añadir parámetro
  final Function(UserModel)?
      onUserUpdated; // Callback opcional para notificar cambios

  const ProfileTab({
    Key? key,
    required this.user,
    required this.authBloc,
    required this.isConnected, // <-- Incluir en el constructor
    this.onUserUpdated,
  }) : super(key: key);

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late UserSettings _settings;
  bool _isLoading = false;
  late PackageInfo _packageInfo;
  bool _loadingPackageInfo = true;

  // Servicios de Firebase
  late ConnectivityService _connectivityService;
  late FirebaseCrashlyticsService _crashlyticsService;
  late PurchaseService _purchaseService;
  late AnalyticsService _analyticsService;

  // Usuario actual que puede actualizarse
  late UserModel _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _settings = _currentUser.settings;

    // Inicializar servicios de Firebase
    _connectivityService =
        Provider.of<ConnectivityService>(context, listen: false);
    _crashlyticsService =
        Provider.of<FirebaseCrashlyticsService>(context, listen: false);
    _purchaseService = Provider.of<PurchaseService>(context, listen: false);
    _analyticsService = Provider.of<AnalyticsService>(context, listen: false);

    // Registrar datos de usuario para Crashlytics
    _crashlyticsService.setUserData(
      userId: _currentUser.id,
      email: _currentUser.email,
      isPremium: _currentUser.subscription.isPremium,
      subscriptionPlan: _currentUser.subscription.plan,
    );

    // Registrar evento de analítica
    _analyticsService.logEvent(name: 'profile_view', parameters: {
      'user_id': _currentUser.id,
      'is_premium': _currentUser.subscription.isPremium.toString(),
    });

    _loadPackageInfo();
    _verifySubscriptionStatus();
  }

  Future<void> _loadPackageInfo() async {
    setState(() {
      _loadingPackageInfo = true;
    });

    try {
      _packageInfo = await PackageInfo.fromPlatform();
    } catch (e, stack) {
      // Registrar error en Crashlytics
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'Error al cargar información del paquete',
        fatal: false,
      );

      // Fallback values if package info fails
      _packageInfo = PackageInfo(
        appName: 'Goalkeeper Stats',
        packageName: 'com.example.goalkeeper_stats_app',
        version: '1.0.0',
        buildNumber: '1',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingPackageInfo = false;
        });
      }
    }
  }

  // Verificar el estado de suscripción en tiempo real con la tienda
  Future<void> _verifySubscriptionStatus() async {
    if (!_connectivityService.isConnected) {
      return; // Omitir verificación si no hay conexión
    }

    try {
      final isActive = await _purchaseService
          .verifyActivePurchase(_currentUser.subscription.plan ?? '', _currentUser.id);

      if (isActive != _currentUser.subscription.isPremium) {
        // Hay una discrepancia entre el estado local y el servidor
        final updatedSubscription =
            await _purchaseService.refreshSubscriptionStatus(_currentUser.id);

        if (mounted && updatedSubscription != null) {
          setState(() {
            _currentUser =
                _currentUser.copyWith(subscription: updatedSubscription);
          });

          // Registrar evento en analytics
          _analyticsService
              .logEvent(name: 'subscription_status_updated', parameters: {
            'user_id': _currentUser.id,
            'is_premium': _currentUser.subscription.isPremium.toString(),
            'plan': _currentUser.subscription.plan ?? 'none',
          });

          // Notificar al padre si es necesario
          if (widget.onUserUpdated != null) {
            widget.onUserUpdated!(_currentUser);
          }
        }
      }
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'Error al verificar estado de suscripción',
        fatal: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Información del perfil
                  _buildProfileCard(theme),
                  const SizedBox(height: 24),

                  // Suscripción
                  _buildSubscriptionCard(theme, isDarkMode),
                  const SizedBox(height: 24),

                  // Configuración
                  _buildSettingsSection(theme),
                  const SizedBox(height: 24),

                  // Opciones avanzadas
                  _buildAdvancedOptionsSection(theme),
                  const SizedBox(height: 24),

                  // Información de la aplicación
                  _buildAppInfoSection(theme),
                  const SizedBox(height: 24),

                  // Botón de cerrar sesión
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _confirmSignOut,
                      icon: const Icon(Icons.logout),
                      label: const Text('Cerrar Sesión'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        side: BorderSide(color: theme.colorScheme.error),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Foto de perfil
            CircleAvatar(
              radius: 40,
              backgroundImage: _currentUser.photoUrl != null
                  ? NetworkImage(_currentUser.photoUrl!)
                  : null,
              child: _currentUser.photoUrl == null
                  ? const Icon(Icons.person, size: 40)
                  : null,
            ),
            const SizedBox(height: 16),

            // Nombre
            Text(
              _currentUser.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),

            // Email
            Text(
              _currentUser.email,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            // Equipo (si está disponible)
            if (_currentUser.team != null && _currentUser.team!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sports_soccer,
                        size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      _currentUser.team!,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Botón de editar perfil
            OutlinedButton.icon(
              onPressed: () async {
                if (!_connectivityService.isConnected) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                          'No hay conexión a internet. Intenta más tarde.'),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );
                  return;
                }

                _analyticsService.logEvent(name: 'edit_profile_click');

                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BlocProvider.value(
                      value: widget.authBloc,
                      child: EditProfilePage(user: _currentUser),
                    ),
                  ),
                );

                // Si se recibió un usuario actualizado como resultado
                if (result != null && result is UserModel) {
                  // Actualizar el estado local
                  setState(() {
                    _currentUser = result;
                    _settings = _currentUser.settings;
                  });

                  // Registrar evento en analytics
                  _analyticsService.logEvent(name: 'profile_updated');

                  // Notificar al padre a través del callback si existe
                  if (widget.onUserUpdated != null) {
                    widget.onUserUpdated!(_currentUser);
                  }

                  // Mostrar confirmación
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Perfil actualizado correctamente'),
                      backgroundColor: theme.colorScheme.primary,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.edit),
              label: const Text('Editar Perfil'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(ThemeData theme, bool isDarkMode) {
    final isPremium = _currentUser.subscription.isPremium;
    final expirationDate = _currentUser.subscription.expirationDate;

    // Usar decoración premium de AppTheme
    final decoration = AppTheme.premiumCardDecoration(isDarkMode);
    final Color cardBgColor = isPremium
        ? decoration.color ??
            (isDarkMode ? AppTheme.darkCardColor : Colors.green.shade50)
        : (isDarkMode
            ? const Color(0xFF423000).withOpacity(0.7)
            : Colors.amber.shade50);

    final Color textColor = isPremium
        ? (isDarkMode ? AppTheme.premiumDarkColor : AppTheme.primaryColor)
        : (isDarkMode ? Colors.amber : Colors.amber.shade800);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: cardBgColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isPremium ? Icons.verified : Icons.star_border,
                  color: textColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isPremium ? 'Suscripción Premium' : 'Versión Gratuita',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isPremium) ...[
              if (_currentUser.subscription.plan != null)
                _buildInfoRow(
                  'Plan',
                  _getPlanName(_currentUser.subscription.plan!),
                ),
              if (expirationDate != null)
                _buildInfoRow(
                  'Expira',
                  DateFormat('dd/MM/yyyy').format(expirationDate),
                ),
              const SizedBox(height: 8),
              Text(
                'Disfruta de todas las funciones premium sin límites.',
                style: TextStyle(
                  color: isPremium
                      ? (isDarkMode
                          ? AppTheme.selectedTextDark
                          : AppTheme.primaryColor)
                      : textColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ] else ...[
              _buildInfoRow(
                'Límite diario',
                '20 tiros por día',
              ),
              _buildInfoRow(
                'Función de partidos',
                'No disponible',
              ),
              _buildInfoRow(
                'Exportación',
                'No disponible',
              ),
              const SizedBox(height: 8),
              Text(
                'Actualiza a Premium para desbloquear todas las funciones.',
                style: TextStyle(
                  color: textColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (!_connectivityService.isConnected) {
                    _connectivityService.showConnectivitySnackBar(context);
                    return;
                  }

                  // Registrar evento en analytics
                  _analyticsService.logEvent(name: isPremium
                      ? 'manage_subscription_click'
                      : 'upgrade_premium_click');

                  await _navigateToSubscriptionPage();
                },
                icon: Icon(isPremium ? Icons.refresh : Icons.star),
                label: Text(isPremium
                    ? 'Gestionar Suscripción'
                    : 'Actualizar a Premium'),
                style: AppTheme.premiumButtonStyle(isDarkMode),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToSubscriptionPage() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BlocProvider.value(
            value: widget.authBloc,
            child: SubscriptionPage(user: _currentUser),
          ),
        ),
      );

      // Si se recibió un usuario actualizado como resultado
      if (result != null && result is UserModel) {
        final wasUpgraded = !_currentUser.subscription.isPremium &&
            result.subscription.isPremium;

        // Actualizar el estado local
        setState(() {
          _currentUser = result;
          _settings = _currentUser.settings;
        });

        // Registrar evento en analytics
        if (wasUpgraded) {
          _analyticsService.logEvent(name: 'subscription_upgraded', parameters: {
            'plan': _currentUser.subscription.plan ?? '',
          });
        } else {
          _analyticsService.logEvent(name: 'subscription_updated');
        }

        // Notificar al padre a través del callback si existe
        if (widget.onUserUpdated != null) {
          widget.onUserUpdated!(_currentUser);
        }

        // Actualizar datos en Crashlytics
        _crashlyticsService.setUserData(
          userId: _currentUser.id,
          email: _currentUser.email,
          isPremium: _currentUser.subscription.isPremium,
          subscriptionPlan: _currentUser.subscription.plan,
        );

        // Mostrar confirmación
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_currentUser.subscription.isPremium
                ? 'Suscripción premium activada correctamente'
                : 'Estado de suscripción actualizado'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
      }
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'Error en navegación a pantalla de suscripción',
        fatal: false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              const Text('Ha ocurrido un error. Intenta de nuevo más tarde.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Widget _buildSettingsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
          child: Text(
            'Configuración',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: theme.colorScheme.onBackground,
            ),
          ),
        ),
        Card(
          elevation: 1,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Selector de idioma
              ListTile(
                leading: Icon(Icons.language, color: theme.colorScheme.primary),
                title: Text('Idioma',
                    style: TextStyle(color: theme.colorScheme.onSurface)),
                trailing: DropdownButton<String>(
                  value: _settings.language,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(
                      value: 'es',
                      child: Text('Español'),
                    ),
                    DropdownMenuItem(
                      value: 'en',
                      child: Text('English'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _settings = _settings.copyWith(language: value);
                      });
                      _updateUserSettings();

                      // Registrar evento en analytics
                      _analyticsService
                          .logEvent(name: 'language_changed', parameters: {
                        'language': value,
                      });
                    }
                  },
                ),
              ),

              // Notificaciones
              SwitchListTile(
                title: Text('Notificaciones',
                    style: TextStyle(color: theme.colorScheme.onSurface)),
                value: _settings.notificationsEnabled,
                secondary:
                    Icon(Icons.notifications, color: theme.colorScheme.primary),
                activeColor: theme.colorScheme.primary,
                onChanged: (value) {
                  setState(() {
                    _settings = _settings.copyWith(notificationsEnabled: value);
                  });
                  _updateUserSettings();

                  // Registrar evento en analytics
                  _analyticsService
                      .logEvent(name: 'notifications_setting_changed', parameters: {
                    'enabled': value.toString(),
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedOptionsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
          child: Text(
            'Opciones Avanzadas',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: theme.colorScheme.onBackground,
            ),
          ),
        ),
        Card(
          elevation: 1,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Exportar datos (solo premium)
              ListTile(
                leading: Icon(Icons.cloud_download,
                    color: theme.colorScheme.primary),
                title: Text('Exportar Datos',
                    style: TextStyle(color: theme.colorScheme.onSurface)),
                subtitle: Text(
                  _currentUser.subscription.isPremium
                      ? 'Descarga tus estadísticas y registros'
                      : 'Disponible solo para usuarios Premium',
                  style: TextStyle(
                    color: _currentUser.subscription.isPremium
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.error,
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: _currentUser.subscription.isPremium
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
                enabled: _currentUser.subscription.isPremium &&
                    _connectivityService.isConnected,
                onTap: () {
                  if (!_currentUser.subscription.isPremium) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Esta función requiere una suscripción Premium'),
                        backgroundColor: Colors.amber,
                      ),
                    );
                    return;
                  }

                  if (!_connectivityService.isConnected) {
                    _connectivityService.showConnectivitySnackBar(context);
                    return;
                  }

                  // Registrar evento en analytics
                  _analyticsService.logEvent(name: 'export_data_click');

                  // TODO: Implementar exportación de datos
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Función disponible próximamente'),
                    ),
                  );
                },
              ),

              // Sincronizar datos
              ListTile(
                leading: Icon(Icons.sync, color: theme.colorScheme.primary),
                title: Text('Sincronizar Datos',
                    style: TextStyle(color: theme.colorScheme.onSurface)),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 16,
                    color: _connectivityService.isConnected
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                enabled: _connectivityService.isConnected,
                onTap: () {
                  if (!_connectivityService.isConnected) {
                    _connectivityService.showConnectivitySnackBar(context);
                    return;
                  }

                  // Registrar evento en analytics
                  _analyticsService.logEvent(name: 'sync_data_click');

                  // TODO: Implementar sincronización manual
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sincronización iniciada'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppInfoSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
          child: Text(
            'Información',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: theme.colorScheme.onBackground,
            ),
          ),
        ),
        Card(
          elevation: 1,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Versión de la app
              if (_loadingPackageInfo)
                ListTile(
                  leading: Icon(Icons.info, color: theme.colorScheme.primary),
                  title: Text('Versión',
                      style: TextStyle(color: theme.colorScheme.onSurface)),
                  trailing: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                )
              else
                ListTile(
                  leading: Icon(Icons.info, color: theme.colorScheme.primary),
                  title: Text('Versión',
                      style: TextStyle(color: theme.colorScheme.onSurface)),
                  trailing: Text(
                    '${_packageInfo.version} (${_packageInfo.buildNumber})',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),

              // Privacidad
              ListTile(
                leading: Icon(Icons.security, color: theme.colorScheme.primary),
                title: Text('Política de Privacidad',
                    style: TextStyle(color: theme.colorScheme.onSurface)),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
                onTap: () {
                  _analyticsService.logEvent(name: 'privacy_policy_click');
                  _launchURL('https://example.com/privacy');
                },
              ),

              // Términos
              ListTile(
                leading:
                    Icon(Icons.description, color: theme.colorScheme.primary),
                title: Text('Términos de Servicio',
                    style: TextStyle(color: theme.colorScheme.onSurface)),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
                onTap: () {
                  _analyticsService.logEvent(name: 'terms_of_service_click');
                  _launchURL('https://example.com/terms');
                },
              ),

              // Soporte
              ListTile(
                leading: Icon(Icons.help, color: theme.colorScheme.primary),
                title: Text('Ayuda y Soporte',
                    style: TextStyle(color: theme.colorScheme.onSurface)),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
                onTap: () {
                  _analyticsService.logEvent(name: 'support_click');
                  _launchURL('https://example.com/support');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onBackground,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(color: theme.colorScheme.onBackground),
          ),
        ],
      ),
    );
  }

  String _getPlanName(String planId) {
    switch (planId) {
      case 'monthly':
        return 'Mensual';
      case 'quarterly':
        return 'Trimestral';
      case 'biannual':
        return 'Semestral';
      case 'annual':
        return 'Anual';
      default:
        return planId;
    }
  }

  void _updateUserSettings() async {
    if (!_connectivityService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Sin conexión a internet. Las configuraciones se guardarán cuando vuelvas a conectarte.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Actualizar el usuario actual con los nuevos ajustes
      _currentUser = _currentUser.copyWith(settings: _settings);

      // Enviar evento para actualizar configuración
      widget.authBloc.add(UpdateUserSettingsEvent(_settings));

      // Notificar al padre del cambio si el callback existe
      if (widget.onUserUpdated != null) {
        widget.onUserUpdated!(_currentUser);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Configuración actualizada'),
          backgroundColor: Theme.of(context).colorScheme.secondary,
        ),
      );
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'Error al actualizar configuraciones de usuario',
        fatal: false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar configuración: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _confirmSignOut() {
    _analyticsService.logEvent(name: 'logout_click');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _signOut();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }

  void _signOut() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Registrar evento en analytics
      _analyticsService.logEvent(name: 'logout');

      // Limpiar datos de usuario en Crashlytics
      await _crashlyticsService.clearUserData();

      // Enviar evento de cierre de sesión
      widget.authBloc.add(SignOutEvent());

      // Navegar a la pantalla de inicio de sesión
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'Error al cerrar sesión',
        fatal: false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cerrar sesión: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _launchURL(String url) async {
    try {
      if (!await launchUrl(Uri.parse(url))) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir $url'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'Error al abrir URL: $url',
        fatal: false,
      );
    }
  }

  @override
  void dispose() {
    // No es necesario liberar los servicios aquí ya que son proporcionados por Provider
    super.dispose();
  }
}
