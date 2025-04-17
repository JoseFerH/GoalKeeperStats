/// Información de la suscripción del usuario
class SubscriptionInfo {
  final String type;
  final DateTime? expirationDate;
  final String? plan;

  SubscriptionInfo({
    required this.type,
    this.expirationDate,
    this.plan,
  });

  factory SubscriptionInfo.free() {
    return SubscriptionInfo(
      type: 'free',
      expirationDate: null,
      plan: null,
    );
  }

  factory SubscriptionInfo.premium({
    required DateTime expirationDate,
    required String plan,
  }) {
    return SubscriptionInfo(
      type: 'premium',
      expirationDate: expirationDate,
      plan: plan,
    );
  }

  factory SubscriptionInfo.fromMap(Map<String, dynamic> map) {
    return SubscriptionInfo(
      type: map['type'] ?? 'free',
      expirationDate: map['expirationDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['expirationDate'])
          : null,
      plan: map['plan'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'expirationDate': expirationDate?.millisecondsSinceEpoch,
      'plan': plan,
    };
  }

  bool get isPremium =>
      type == 'premium' &&
      (expirationDate == null || expirationDate!.isAfter(DateTime.now()));

  SubscriptionInfo copyWith({
    String? type,
    DateTime? expirationDate,
    String? plan,
  }) {
    return SubscriptionInfo(
      type: type ?? this.type,
      expirationDate: expirationDate ?? this.expirationDate,
      plan: plan ?? this.plan,
    );
  }
}
