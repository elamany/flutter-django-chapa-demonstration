import 'package:dio/dio.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/dio_client.dart';
import '../../../../core/api/paginated_result.dart';
import '../models/donation.dart';
import '../models/donation_initiation.dart';
import '../models/mobile_donation_initiation.dart';

class DonationRepository {
  DonationRepository({DioClient? client})
      : _client = client ?? DioClient.instance;

  final DioClient _client;

  /// POST /campaigns/<pk>/donate/
  /// No authentication required — guests can donate.
  /// If the caller has a token, DioClient attaches it, but the backend
  /// doesn't require it.
  /// Returns the initialised donation + the Chapa checkout URL.
  Future<DonationInitiation> initiateDonation({
    required int campaignId,
    required String name,
    required String email,
    required double amount,
    required bool isAnonymous,
  }) async {
    try {
      final res = await _client.post(
        'campaigns/$campaignId/donate/',
        data: {
          'name': name,
          'email': email,
          'amount': amount.toStringAsFixed(2),
          'is_anonymous': isAnonymous,
        },
      );

      final body = res.data as Map<String, dynamic>;

      if (body['success'] != true || body['data'] is! Map) {
        throw const ApiException(
          message: 'Unexpected response from server.',
        );
      }

      return DonationInitiation.fromJson(
        Map<String, dynamic>.from(body['data'] as Map),
      );
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// POST /campaigns/<pk>/donate/mobile/
  /// Mobile flow: Django creates the PENDING donation and returns the
  /// tx_ref + amount. The Flutter app then drives Chapa's native SDK.
  Future<MobileDonationInitiation> initiateMobileDonation({
    required int campaignId,
    required String name,
    required String email,
    required String phone,
    required double amount,
    required bool isAnonymous,
  }) async {
    try {
      final res = await _client.post(
        'campaigns/$campaignId/donate/mobile/',
        data: {
          'name': name,
          'email': email,
          'phone': phone,
          'amount': amount.toStringAsFixed(2),
          'is_anonymous': isAnonymous,
        },
      );

      final body = res.data as Map<String, dynamic>;

      if (body['success'] != true || body['data'] is! Map) {
        throw const ApiException(
          message: 'Unexpected response from server.',
        );
      }

      return MobileDonationInitiation.fromJson(
        Map<String, dynamic>.from(body['data'] as Map),
      );
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// GET /campaigns/<id>/donations/
  ///
  /// Public donor wall — only SUCCESS donations, ordered newest first.
  /// Works without authentication.
  Future<PaginatedResult<Donation>> listPublicDonations({
    required int campaignId,
    int page = 1,
  }) async {
    try {
      final res = await _client.get(
        'campaigns/$campaignId/donations/',
        query: {'page': page},
      );

      return PaginatedResult.fromJson(
        res.data as Map<String, dynamic>,
        (json) => Donation.fromJson(json),
      );
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  ApiException _unwrap(DioException e) {
    if (e.error is ApiException) {
      return e.error as ApiException;
    }
    return ApiException.unknown(e);
  }
}