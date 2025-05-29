import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/presentation/blocs/auth/auth_bloc.dart';
import 'package:goalkeeper_stats/presentation/blocs/auth/auth_event.dart';
import 'package:goalkeeper_stats/presentation/pages/subscription/subscription_page.dart';
import 'package:goalkeeper_stats/services/purchase_service.dart';
import 'package:goalkeeper_stats/presentation/widgets/purchase_status_widget.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';

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

  @override
  void initState() {
    super.initState();
    _purchaseService = Provider.of<PurchaseService>(context, listen: false);
    _listenToPurchases();
    _checkCurrentSubscription();
  }

  void _listenToPurchases() {
    _purchaseService.purchaseStream.listen((purchaseInfo) {
      if (mounted) {
        setState(() {
          _lastPurchaseInfo = purchaseInfo;
        });

        // Si la compra fue exitosa, actualizar el usuario
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
      // Verificar el estado actual de la suscripción
      final subscription =
          await _purchaseService.verifyCurrentSubscription(widget.user.id);

      // Si cambió el estado de suscripción, actualizar
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
      // Disparar evento para actualizar el usuario
      widget.authBloc.add(RefreshUserDataEvent() as AuthEvent);
    } catch (e) {
      debugPrint('Error actualizando datos del usuario: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
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

              // Opciones de perfil
              _buildProfileOptions(),
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
        child: Row(
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

  Widget _buildProfileOptions() {
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
              'Opciones',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Editar Perfil'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navegar a editar perfil
            },
          ),
          if (widget.user.subscription.isPremium)
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Restaurar Compras'),
              trailing: const Icon(Icons.chevron_right),
              onTap: widget.isConnected ? _restorePurchases : null,
            ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Configuración'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navegar a configuración
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Ayuda y Soporte'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navegar a ayuda
            },
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

    // Si hubo cambios, actualizar datos
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
