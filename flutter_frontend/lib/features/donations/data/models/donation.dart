import 'package:equatable/equatable.dart';

/// A donation as shown on the public donor wall.
/// Matches the shape of PublicDonationListSerializer.
class Donation extends Equatable {
  final int id;
  final String name;
  final double amount;
  final bool isAnonymous;
  final DateTime createdAt;

  const Donation({
    required this.id,
    required this.name,
    required this.amount,
    required this.isAnonymous,
    required this.createdAt,
  });

  factory Donation.fromJson(Map<String, dynamic> json) {
    return Donation(
      id: json['id'] as int,
      name: (json['name'] ?? 'Anonymous') as String,
      amount: _toDouble(json['amount']),
      isAnonymous: (json['is_anonymous'] ?? false) as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  List<Object?> get props => [id, name, amount, isAnonymous, createdAt];
}