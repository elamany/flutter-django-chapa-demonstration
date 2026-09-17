import 'package:equatable/equatable.dart';

/// A campaign as returned by:
///   - GET /campaigns/          (public list)
///   - GET /campaigns/<pk>/     (public detail)
///   - GET /my-campaigns/       (owner list)
///   - GET /my-campaigns-detail/<pk>/
///   - POST/PATCH on campaigns
///
/// Django sends money fields as strings ("10000.00") and status as
/// uppercase enum strings ("ACTIVE", "DRAFT", etc.).
class Campaign extends Equatable {
  final int id;
  final String title;
  final String description;
  final double targetAmount;
  final String status;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Owner info (flattened by the serializer)
  final int ownerId;
  final String ownerUsername;
  final String ownerFirstName;
  final String ownerLastName;

  // Computed server-side
  final double raisedAmount;
  final int donationCount;
  final double progressPercent;

  const Campaign({
    required this.id,
    required this.title,
    required this.description,
    required this.targetAmount,
    required this.status,
    required this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.ownerId,
    required this.ownerUsername,
    required this.ownerFirstName,
    required this.ownerLastName,
    required this.raisedAmount,
    required this.donationCount,
    required this.progressPercent,
  });

  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      id: json['id'] as int,
      title: (json['title'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      targetAmount: _toDouble(json['target_amount']),
      status: (json['status'] ?? 'DRAFT') as String,
      imageUrl: _toImageUrl(json['image']),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      ownerId: (json['owner_id'] ?? 0) as int,
      ownerUsername: (json['owner_username'] ?? '') as String,
      ownerFirstName: (json['owner_first_name'] ?? '') as String,
      ownerLastName: (json['owner_last_name'] ?? '') as String,
      raisedAmount: _toDouble(json['raised_amount']),
      donationCount: (json['donation_count'] ?? 0) as int,
      progressPercent: _toDouble(json['progress_percent']),
    );
  }

  // ---------------------------------------------------------------------------
  // Derived getters — used by the UI. No extra API calls needed.
  // ---------------------------------------------------------------------------

  /// Full name from first+last, or username as fallback.
  String get ownerDisplayName {
    final full = '$ownerFirstName $ownerLastName'.trim();
    return full.isEmpty ? ownerUsername : full;
  }

  /// Progress as a 0.0–1.0 fraction, suitable for LinearProgressIndicator.
  double get progressFraction => (progressPercent / 100).clamp(0.0, 1.0);

  /// True when the campaign is accepting donations.
  bool get isActive => status == 'ACTIVE';

  /// True when the campaign has hit or passed its target.
  bool get isCompleted =>
      status == 'COMPLETED' || raisedAmount >= targetAmount;

  /// Human-friendly status for badges.
  String get statusLabel {
    switch (status) {
      case 'DRAFT':
        return 'Draft';
      case 'PENDING_REVIEW':
        return 'Pending review';
      case 'ACTIVE':
        return 'Active';
      case 'COMPLETED':
        return 'Completed';
      case 'REJECTED':
        return 'Rejected';
      default:
        return status;
    }
  }

  // ---------------------------------------------------------------------------
  // JSON parsing helpers
  // ---------------------------------------------------------------------------

  /// Django DecimalField serializes as string ("1000.00"), but
  /// progress_percent is already a float. Handle both.
  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  /// Django sends the image field as either null or a full URL
  /// (because DRF's ImageField returns a serialized URI when a
  /// request context is available). Keep it as-is.
  static String? _toImageUrl(dynamic value) {
    if (value == null) return null;
    if (value is String && value.isNotEmpty) return value;
    return null;
  }

  // ---------------------------------------------------------------------------
  // Equatable
  // ---------------------------------------------------------------------------
  @override
  List<Object?> get props => [
        id,
        title,
        description,
        targetAmount,
        status,
        imageUrl,
        createdAt,
        updatedAt,
        ownerId,
        ownerUsername,
        ownerFirstName,
        ownerLastName,
        raisedAmount,
        donationCount,
        progressPercent,
      ];
}