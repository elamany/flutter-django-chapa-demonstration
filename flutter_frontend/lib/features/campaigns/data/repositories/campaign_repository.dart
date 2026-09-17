import 'package:dio/dio.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/dio_client.dart';
import '../../../../core/api/paginated_result.dart';
import '../../../auth/data/models/campaign.dart';

/// All campaign-related HTTP calls.
///
/// Public endpoints (list, detail) work for guests and authenticated users.
/// Owner endpoints (myCampaigns) require a valid access token, which the
/// DioClient interceptor attaches automatically.
class CampaignRepository {
  CampaignRepository({DioClient? client})
      : _client = client ?? DioClient.instance;

  final DioClient _client;

  // ---------------------------------------------------------------------------
  // Public list — GET /campaigns/
  // ---------------------------------------------------------------------------
  /// [status] is optional: 'ACTIVE' or 'COMPLETED'. Anything else → 400.
  /// [page] is 1-based. Server page size is 10.
  Future<PaginatedResult<Campaign>> list({
    String? status,
    int page = 1,
  }) async {
    try {
      final res = await _client.get(
        'campaigns/',
        query: {
          'status': ?status,
          'page': page,
        },
      );

      return PaginatedResult.fromJson(
        res.data as Map<String, dynamic>,
        (json) => Campaign.fromJson(json),
      );
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Public detail — GET /campaigns/<pk>/
  // ---------------------------------------------------------------------------
  Future<Campaign> detail(int id) async {
    try {
      final res = await _client.get('campaigns/$id/');
      return Campaign.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Owner list — GET /my-campaigns/
  // ---------------------------------------------------------------------------
  /// Requires authentication. Returns every campaign owned by the current user,
  /// across all statuses (DRAFT, PENDING_REVIEW, ACTIVE, COMPLETED, REJECTED).
  Future<PaginatedResult<Campaign>> myCampaigns({int page = 1}) async {
    try {
      final res = await _client.get(
        'my-campaigns/',
        query: {'page': page},
      );

      return PaginatedResult.fromJson(
        res.data as Map<String, dynamic>,
        (json) => Campaign.fromJson(json),
      );
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Unwrap ApiException from DioException.error (set by DioClient)
  // ---------------------------------------------------------------------------
  ApiException _unwrap(DioException e) {
    if (e.error is ApiException) {
      return e.error as ApiException;
    }
    return ApiException.unknown(e);
  }
}