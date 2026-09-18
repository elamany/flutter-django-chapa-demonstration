import 'package:equatable/equatable.dart';

/// Response from `POST /campaigns/<pk>/donate/mobile/`.
///
/// Shape:
///   {
///     "success": true,
///     "data": {
///       "donation_id": 31,
///       "campaign_id": 2,
///       "tx_ref": "CAMP-2-...",
///       "amount": "100.00",
///       "currency": "ETB",
///       "campaign_title": "...",
///       "status": "PENDING"
///     }
///   }
///
/// Note: unlike the web flow, there is NO checkout_url here.
/// The Flutter app drives Chapa's SDK itself using this data.
class MobileDonationInitiation extends Equatable {
  final int donationId;
  final int campaignId;
  final String txRef;
  final String amount;
  final String currency;
  final String campaignTitle;
  final String status;

  const MobileDonationInitiation({
    required this.donationId,
    required this.campaignId,
    required this.txRef,
    required this.amount,
    required this.currency,
    required this.campaignTitle,
    required this.status,
  });

  factory MobileDonationInitiation.fromJson(Map<String, dynamic> json) {
    return MobileDonationInitiation(
      donationId: json['donation_id'] as int,
      campaignId: json['campaign_id'] as int,
      txRef: (json['tx_ref'] ?? '') as String,
      amount: (json['amount'] ?? '0.00').toString(),
      currency: (json['currency'] ?? 'ETB') as String,
      campaignTitle: (json['campaign_title'] ?? '') as String,
      status: (json['status'] ?? 'PENDING') as String,
    );
  }

  @override
  List<Object?> get props => [
        donationId,
        campaignId,
        txRef,
        amount,
        currency,
        campaignTitle,
        status,
      ];
}