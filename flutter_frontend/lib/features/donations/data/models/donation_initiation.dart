import 'package:equatable/equatable.dart';

/// Response from `POST /campaigns/<pk>/donate/`.
///
/// That endpoint uses Django's `success_response()` helper, so the shape is:
///   {
///     "success": true,
///     "data": {
///       "donation_id": 5,
///       "campaign_id": 2,
///       "tx_ref": "CAMP-2-abc...",
///       "status": "PENDING",
///       "checkout_url": "https://checkout.chapa.co/..."
///     }
///   }
///
/// This model holds just the `data` object.
class DonationInitiation extends Equatable {
  final int donationId;
  final int campaignId;
  final String txRef;
  final String status;
  final String checkoutUrl;

  const DonationInitiation({
    required this.donationId,
    required this.campaignId,
    required this.txRef,
    required this.status,
    required this.checkoutUrl,
  });

  factory DonationInitiation.fromJson(Map<String, dynamic> json) {
    return DonationInitiation(
      donationId: json['donation_id'] as int,
      campaignId: json['campaign_id'] as int,
      txRef: (json['tx_ref'] ?? '') as String,
      status: (json['status'] ?? 'PENDING') as String,
      checkoutUrl: (json['checkout_url'] ?? '') as String,
    );
  }

  @override
  List<Object?> get props => [
        donationId,
        campaignId,
        txRef,
        status,
        checkoutUrl,
      ];
}