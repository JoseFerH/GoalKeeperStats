import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:goalkeeper_stats/data/models/subscription_info.dart';
import 'package:goalkeeper_stats/data/models/user_settings.dart';

/// Modelo de Usuario que representa a un portero en la aplicación
class UserModel {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final String? team;
  final SubscriptionInfo subscription;
  final UserSettings settings;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    this.team,
    required this.subscription,
    required this.settings,
  });

  // Método para crear un nuevo usuario desde Firestore
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel.fromMap({
      ...data,
      'id': doc.id, // Asegurar que el ID del documento se incluya
    });
  }

  // Método para crear un nuevo usuario con valores por defecto
  factory UserModel.newUser({
    required String id,
    required String name,
    required String email,
    String? photoUrl,
    String? team,
  }) {
    return UserModel(
      id: id,
      name: name,
      email: email,
      photoUrl: photoUrl,
      team: team,
      subscription: SubscriptionInfo.free(),
      settings: UserSettings.defaultSettings(),
    );
  }

  // Método para crear desde un Map (usado en fromFirestore)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'],
      team: map['team'],
      subscription: SubscriptionInfo.fromMap(map['subscription'] ?? {}),
      settings: UserSettings.fromMap(map['settings'] ?? {}),
    );
  }

  // Convertir a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'team': team,
      'subscription': subscription.toMap(),
      'settings': settings.toMap(),
      'updatedAt': FieldValue.serverTimestamp(), // Usar timestamp del servidor
    };
  }

  // Método para copiar con nuevos valores
  UserModel copyWith({
    String? name,
    String? email,
    String? photoUrl,
    String? team,
    SubscriptionInfo? subscription,
    UserSettings? settings,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      team: team ?? this.team,
      subscription: subscription ?? this.subscription,
      settings: settings ?? this.settings,
    );
  }
}
