import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/presentation/blocs/auth/auth_bloc.dart';
import 'package:goalkeeper_stats/presentation/blocs/auth/auth_event.dart';
import 'package:goalkeeper_stats/presentation/pages/subscription/subscription_page.dart';
import 'package:goalkeeper_stats/presentation/pages/auth/edit_profile_page.dart';
import 'package:goalkeeper_stats/services/purchase_service.dart';
import 'package:goalkeeper_stats/presentation/widgets/purchase_status_widget.dart';
import 'package:goalkeeper_stats/core/theme/theme_manager.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileTab extends StatefulWidget {
  final UserModel user;
  final AuthBloc authBloc;
  final Function(UserModel) onUserUpdated;
  final bool isConnected;

  const ProfileTab({
    super.key,
    required this.user,
    required this.authBloc,
    required this.onUserUpdated,
    this.isConnected = true,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late PurchaseService _purchaseService;
  PurchaseInfo? _lastPurchaseInfo;
  bool _isCheckingSubscription = false;
  late ThemeManager _themeManager;
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'es';

  @override
  void initState() {
    super.initState();
    _purchaseService = Provider.of<PurchaseService>(context, listen: false);
    _themeManager = ThemeManager.getInstance();
    _loadUserSettings();
    _listenToPurchases();
    _checkCurrentSubscription();
  }

  void _loadUserSettings() {
    // Cargar configuraciones del usuario desde UserModel o SharedPreferences
    _notificationsEnabled = widget.user.settings?.notificationsEnabled ?? true;
    _selectedLanguage = widget.user.settings?.language ?? 'es';
  }

  void _listenToPurchases() {
    _purchaseService.purchaseStream.listen((purchaseInfo) {
      if (mounted) {
        setState(() {
          _lastPurchaseInfo = purchaseInfo;
        });

        if (purchaseInfo.status == PurchaseStatus.purchased ||
            purchaseInfo.status == PurchaseStatus.restored) {
          _refreshUserData();
        }
      }
    });
  }

  Future<void> _checkCurrentSubscription() async {
    if (!widget.isConnected) return;

    setState(() {
      _isCheckingSubscription = true;
    });

    try {
      final subscription =
          await _purchaseService.verifyCurrentSubscription(widget.user.id);

      if (subscription.isPremium != widget.user.subscription.isPremium) {
        _refreshUserData();
      }
    } catch (e) {
      debugPrint('Error verificando suscripción: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingSubscription = false;
        });
      }
    }
  }

  Future<void> _refreshUserData() async {
    try {
      widget.authBloc.add(RefreshUserDataEvent() as AuthEvent);
    } catch (e) {
      debugPrint('Error actualizando datos del usuario: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        //title: const Text('Perfil y Configuración'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: widget.isConnected ? _checkCurrentSubscription : null,
            tooltip: widget.isConnected ? 'Actualizar' : 'Sin conexión',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (widget.isConnected) {
            await _checkCurrentSubscription();
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Información del usuario
              _buildUserInfoCard(),
              const SizedBox(height: 20),

              // Estado de la suscripción
              _buildSubscriptionStatusCard(),
              const SizedBox(height: 20),

              // Estado de la última compra
              if (_lastPurchaseInfo != null)
                Column(
                  children: [
                    PurchaseStatusWidget(
                      status: _lastPurchaseInfo!.status,
                      message: _lastPurchaseInfo!.message,
                      onRetry: _lastPurchaseInfo!.status == PurchaseStatus.error
                          ? () => _navigateToSubscription()
                          : null,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),

              // Configuración de la aplicación
              _buildAppSettingsCard(),
              const SizedBox(height: 20),

              // Opciones de cuenta
              _buildAccountOptionsCard(),
              const SizedBox(height: 20),

              // Información y soporte
              _buildSupportCard(),
              const SizedBox(height: 20),

              // Estado de conectividad
              if (!widget.isConnected) _buildConnectivityWarning(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: widget.user.photoUrl != null
                      ? NetworkImage(widget.user.photoUrl!)
                      : null,
                  child: widget.user.photoUrl == null
                      ? const Icon(Icons.person, size: 40)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.user.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.user.email,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (widget.user.team != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Equipo: ${widget.user.team}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _navigateToEditProfile,
                icon: const Icon(Icons.edit),
                label: const Text('Editar Perfil'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionStatusCard() {
    final isPremium = widget.user.subscription.isPremium;
    final expirationDate = widget.user.subscription.expirationDate;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isPremium
              ? LinearGradient(
                  colors: [Colors.amber.shade100, Colors.amber.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isPremium ? Icons.verified : Icons.info_outline,
                    color: isPremium ? Colors.amber.shade700 : Colors.grey,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPremium ? 'Premium Activo' : 'Versión Gratuita',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isPremium
                                ? Colors.amber.shade800
                                : Colors.grey.shade700,
                          ),
                        ),
                        if (isPremium && widget.user.subscription.plan != null)
                          Text(
                            'Plan ${widget.user.subscription.plan!.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.amber.shade700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_isCheckingSubscription)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              if (isPremium && expirationDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Válido hasta: ${DateFormat('dd/MM/yyyy').format(expirationDate)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.amber.shade700,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          widget.isConnected ? _navigateToSubscription : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isPremium ? Colors.amber.shade600 : Colors.green,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                      child: Text(
                        isPremium
                            ? 'Gestionar Suscripción'
                            : 'Actualizar a Premium',
                      ),
                    ),
                  ),
                  if (isPremium) ...[
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: widget.isConnected
                          ? () => _purchaseService.openSubscriptionSettings()
                          : null,
                      child: const Text('Config.'),
                    ),
                  ],
                ],
              ),
              if (isPremium)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextButton.icon(
                    onPressed: widget.isConnected ? _restorePurchases : null,
                    icon: const Icon(Icons.restore),
                    label: const Text('Restaurar Compras'),
                  ),
                ),
              if (!widget.isConnected)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Requiere conexión a internet',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppSettingsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configuración de la App',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Tema oscuro/claro
            ListTile(
              leading: Icon(
                _themeManager.darkMode ? Icons.dark_mode : Icons.light_mode,
              ),
              title: const Text('Tema Oscuro'),
              subtitle:
                  Text(_themeManager.darkMode ? 'Activado' : 'Desactivado'),
              trailing: Switch(
                value: _themeManager.darkMode,
                onChanged: (value) {
                  setState(() {
                    _themeManager.setDarkMode(value);
                  });
                },
              ),
            ),

            const Divider(),

            // Notificaciones
            ListTile(
              leading: Icon(
                _notificationsEnabled
                    ? Icons.notifications
                    : Icons.notifications_off,
              ),
              title: const Text('Notificaciones'),
              subtitle:
                  Text(_notificationsEnabled ? 'Activadas' : 'Desactivadas'),
              trailing: Switch(
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() {
                    _notificationsEnabled = value;
                    _updateUserSettings();
                  });
                },
              ),
            ),

            const Divider(),

            // Idioma
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Idioma'),
              subtitle: Text(_selectedLanguage == 'es' ? 'Español' : 'English'),
              trailing: DropdownButton<String>(
                value: _selectedLanguage,
                underline: Container(),
                items: const [
                  DropdownMenuItem(value: 'es', child: Text('Español')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedLanguage = value;
                      _updateUserSettings();
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountOptionsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Cuenta',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Exportar Datos'),
            subtitle: const Text('Exportar estadísticas a Google Sheets'),
            trailing: const Icon(Icons.chevron_right),
            onTap: widget.isConnected ? _exportData : null,
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacidad'),
            subtitle: const Text('Política de privacidad y términos'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showPrivacyPolicy,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Cerrar Sesión',
              style: TextStyle(color: Colors.red),
            ),
            onTap: _signOut,
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Ayuda y Soporte',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Preguntas Frecuentes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showFAQ,
          ),
          ListTile(
            leading: const Icon(Icons.email),
            title: const Text('Contactar Soporte'),
            subtitle: const Text('¿Tienes algún problema?'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _contactSupport,
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Acerca de la App'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showAbout,
          ),
        ],
      ),
    );
  }

  Widget _buildConnectivityWarning() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.cloud_off, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sin Conexión',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                  Text(
                    'Algunas funciones requieren conexión a internet',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Métodos de navegación y acciones
  Future<void> _navigateToEditProfile() async {
    final updatedUser = await Navigator.of(context).push<UserModel>(
      MaterialPageRoute(
        builder: (context) => EditProfilePage(user: widget.user),
      ),
    );

    if (updatedUser != null) {
      widget.onUserUpdated(updatedUser);
    }
  }

  Future<void> _navigateToSubscription() async {
    if (!widget.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Se requiere conexión a internet'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => SubscriptionPage(user: widget.user),
      ),
    );

    if (result == true) {
      _refreshUserData();
    }
  }

  Future<void> _restorePurchases() async {
    if (!widget.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Se requiere conexión a internet'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restaurando compras...'),
          duration: Duration(seconds: 2),
        ),
      );

      await _purchaseService.restorePurchases();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error restaurando compras: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _updateUserSettings() {
    // Aquí actualizarías las configuraciones del usuario
    // En una implementación real, esto se enviaría al servidor
    // Por ahora solo lo manejamos localmente
  }

  void _exportData() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Exportar Datos'),
          content: const Text(
            'Esta función permitirá exportar tus estadísticas a Google Sheets.\n\n'
            'Próximamente disponible.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Privacidad y Términos'),
          content: const SingleChildScrollView(
            child: Text(
              'Política de Privacidad\n\n'
              'Tu privacidad es importante para nosotros. Esta aplicación:\n\n'
              '• Solo recopila datos necesarios para su funcionamiento\n'
              '• No comparte información personal con terceros\n'
              '• Utiliza Firebase para almacenamiento seguro\n'
              '• Cumple con las regulaciones de protección de datos\n\n'
              'Para más información, visita nuestro sitio web.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  void _showFAQ() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Preguntas Frecuentes'),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '¿Cómo registro un tiro?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                    'Ve a la pestaña "Registrar" y toca en la portería donde fue el tiro.\n'),
                Text(
                  '¿Qué incluye la versión Premium?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                    'Tiros ilimitados, partidos, estadísticas avanzadas y exportación de datos.\n'),
                Text(
                  '¿Puedo usar la app sin internet?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                    'Sí, pero con funcionalidad limitada. Los datos se sincronizarán cuando tengas conexión.\n'),
                Text(
                  '¿Cómo cancelo mi suscripción?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                    'Desde la configuración de tu tienda (Google Play o App Store).'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  void _contactSupport() async {
    const email = 'soporte@goalkeeperStats.com';
    const subject = 'Soporte - Goalkeeper Stats App';
    const body = 'Hola, necesito ayuda con...';

    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=$subject&body=$body',
    );

    try {
      await launchUrl(emailUri);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el cliente de email'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Goalkeeper Stats',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.sports_soccer, size: 48),
      children: const [
        Text(
          'Una aplicación diseñada específicamente para porteros de fútbol que quieren mejorar su rendimiento mediante el análisis detallado de estadísticas.',
        ),
      ],
    );
  }

  void _signOut() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cerrar Sesión'),
          content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.authBloc.add(SignOutEvent());
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Cerrar Sesión'),
            ),
          ],
        );
      },
    );
  }
}

class RefreshUserDataEvent {}
