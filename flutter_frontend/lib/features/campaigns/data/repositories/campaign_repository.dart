import 'package:dio/dio.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/dio_client.dart';
import '../../../../core/api/paginated_result.dart';
import '../models/campaign.dart';
import 'package:image_picker/image_picker.dart';
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
  Future<PaginatedResult<Campaign>> myCampaigns({
    String? status,
    int page = 1,
  }) async {
    try {
      final res = await _client.get(
        'my-campaigns/',
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

  /// GET /my-campaigns-detail/<pk>/
  ///
  /// Owner-scoped detail view. Works for any status — including DRAFT
  /// and PENDING_REVIEW which the public detail endpoint hides.
  Future<Campaign> myCampaignDetail(int id) async {
    try {
      final res = await _client.get('my-campaigns-detail/$id/');
      final body = res.data as Map<String, dynamic>;

      if (body['success'] != true || body['data'] is! Map) {
        throw const ApiException(
          message: 'Unexpected response from server.',
        );
      }

      return Campaign.fromJson(
        Map<String, dynamic>.from(body['data'] as Map),
      );
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// POST /campaigns/ — create a new campaign (owner becomes current user).
  ///
  /// Uses multipart/form-data because of the image. Dio detects the
  /// FormData type and sets the correct content-type automatically.
  Future<Campaign> createCampaign({
    required String title,
    required String description,
    required double targetAmount,
    XFile? image,
  }) async {
    try {
      final formData = FormData.fromMap({
        'title': title,
        'description': description,
        'target_amount': targetAmount.toStringAsFixed(2),
        if (image != null)
          'image': await MultipartFile.fromFile(
            image.path,
            filename: image.name,
          ),
      });

      final res = await _client.post('campaigns/', data: formData);

      return Campaign.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// PATCH /my-campaigns-detail/<id>/
  ///
  /// Only editable fields per status should be included:
  ///   DRAFT           → title, description, target_amount, image
  ///   ACTIVE          → target_amount only
  ///   others          → nothing (backend will reject)
  Future<Campaign> updateCampaign({
    required int id,
    String? title,
    String? description,
    double? targetAmount,
    XFile? image,
  }) async {
    try {
      final map = <String, dynamic>{};
      if (title != null) map['title'] = title;
      if (description != null) map['description'] = description;
      if (targetAmount != null) {
        map['target_amount'] = targetAmount.toStringAsFixed(2);
      }
      if (image != null) {
        map['image'] = await MultipartFile.fromFile(
          image.path,
          filename: image.name,
        );
      }

      final res = await _client.patch(
        'my-campaigns-detail/$id/',
        data: FormData.fromMap(map),
      );

      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true || body['data'] is! Map) {
        throw const ApiException(message: 'Unexpected response from server.');
      }
      return Campaign.fromJson(Map<String, dynamic>.from(body['data'] as Map));
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// POST /my-campaigns/<id>/submit-for-review/
  Future<Campaign> submitForReview(int id) =>
      _actionPost('my-campaigns/$id/submit-for-review/');

  /// POST /my-campaigns/<id>/cancel-review-submission/
  Future<Campaign> cancelSubmission(int id) =>
      _actionPost('my-campaigns/$id/cancel-review-submission/');

  /// POST /my-campaigns/<id>/mark-campaign-complete/
  Future<Campaign> markComplete(int id) =>
      _actionPost('my-campaigns/$id/mark-campaign-complete/');

  Future<Campaign> _actionPost(String path) async {
    try {
      final res = await _client.post(path);
      final body = res.data as Map<String, dynamic>;
      if (body['success'] != true || body['data'] is! Map) {
        throw const ApiException(message: 'Unexpected response from server.');
      }
      return Campaign.fromJson(Map<String, dynamic>.from(body['data'] as Map));
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  // Unwrap ApiException from DioException.error (set by DioClient)
  ApiException _unwrap(DioException e) {
    if (e.error is ApiException) {
      return e.error as ApiException;
    }
    return ApiException.unknown(e);
  }
}