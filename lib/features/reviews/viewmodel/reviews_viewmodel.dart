import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────
//  Models — keys match the Django response EXACTLY
// ─────────────────────────────────────────────────────────────────────

class ReviewStats {
  final int totalReviews;
  final double averageRating;
  final double averageFoodRating;
  final double averageDeliveryRating;

  /// Map of "1"–"5" → count
  final Map<String, int> ratingDistribution;
  final int unrepliedCount;

  const ReviewStats({
    required this.totalReviews,
    required this.averageRating,
    required this.averageFoodRating,
    required this.averageDeliveryRating,
    required this.ratingDistribution,
    required this.unrepliedCount,
  });

  factory ReviewStats.empty() => const ReviewStats(
    totalReviews: 0,
    averageRating: 0,
    averageFoodRating: 0,
    averageDeliveryRating: 0,
    ratingDistribution: {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0},
    unrepliedCount: 0,
  );

  factory ReviewStats.fromJson(Map<String, dynamic> j) {
    final dist = <String, int>{};
    final rawDist = j['rating_distribution'];
    if (rawDist is Map) {
      for (final k in ['1', '2', '3', '4', '5']) {
        dist[k] = (rawDist[k] as num?)?.toInt() ?? 0;
      }
    } else {
      for (final k in ['1', '2', '3', '4', '5']) {
        dist[k] = 0;
      }
    }
    return ReviewStats(
      totalReviews: (j['total_reviews'] as num?)?.toInt() ?? 0,
      averageRating: _d(j['average_rating']),
      averageFoodRating: _d(j['average_food_rating']),
      averageDeliveryRating: _d(j['average_delivery_rating']),
      ratingDistribution: dist,
      unrepliedCount: (j['unreplied_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class VendorReview {
  final int id;
  final int orderId;
  final String orderNumber;
  final String customerName;

  /// 1–5
  final int rating;
  final int foodRating;
  final int deliveryRating;
  final String comment;
  final String orderItems;

  /// Empty string means no reply yet — matches backend behaviour exactly.
  String reply;
  String? repliedAt;
  final String createdAt;

  /// Up to 3 photo URLs; nulls filtered out.
  final List<String> photos;

  VendorReview({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.customerName,
    required this.rating,
    required this.foodRating,
    required this.deliveryRating,
    required this.comment,
    required this.orderItems,
    required this.reply,
    required this.repliedAt,
    required this.createdAt,
    required this.photos,
  });

  bool get hasReply => reply.isNotEmpty;

  factory VendorReview.fromJson(Map<String, dynamic> j) {
    final rawPhotos = j['photos'];
    final photos = <String>[];
    if (rawPhotos is List) {
      for (final p in rawPhotos) {
        if (p != null && p.toString().isNotEmpty) photos.add(p.toString());
      }
    }
    return VendorReview(
      id: (j['id'] as num?)?.toInt() ?? 0,
      orderId: (j['order_id'] as num?)?.toInt() ?? 0,
      orderNumber: j['order_number']?.toString() ?? '',
      customerName: j['customer_name']?.toString() ?? 'Customer',
      rating: (j['rating'] as num?)?.toInt() ?? 0,
      foodRating: (j['food_rating'] as num?)?.toInt() ?? 0,
      deliveryRating: (j['delivery_rating'] as num?)?.toInt() ?? 0,
      comment: j['comment']?.toString() ?? '',
      orderItems: j['order_items']?.toString() ?? '',
      // Backend always returns a string; empty = no reply
      reply: j['reply']?.toString() ?? '',
      repliedAt: j['replied_at']?.toString(),
      createdAt: j['created_at']?.toString() ?? '',
      photos: photos,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Enum
// ─────────────────────────────────────────────────────────────────────

enum ReviewsStatus { fetching, idle, error }

// ─────────────────────────────────────────────────────────────────────
//  ViewModel
// ─────────────────────────────────────────────────────────────────────

class ReviewsViewModel extends ChangeNotifier {
  final ApiService _apiService;

  ReviewsViewModel({required ApiService apiService}) : _apiService = apiService;

  // ── State ──────────────────────────────────────────────────────────
  ReviewsStatus _status = ReviewsStatus.fetching;
  ReviewStats _stats = ReviewStats.empty();
  List<VendorReview> _reviews = [];
  String? _errorMessage;

  /// Map of review id → bool; true = POST in flight for that review.
  final Map<int, bool> _submitting = {};

  /// Map of review id → error string shown under that reply textarea.
  final Map<int, String> _replyErrors = {};

  // ── Getters ────────────────────────────────────────────────────────
  ReviewsStatus get status => _status;
  ReviewStats get stats => _stats;
  List<VendorReview> get reviews => List.unmodifiable(_reviews);
  String? get errorMessage => _errorMessage;
  bool get hasData => _reviews.isNotEmpty || _status == ReviewsStatus.idle;

  bool isSubmitting(int reviewId) => _submitting[reviewId] ?? false;
  String? replyError(int reviewId) => _replyErrors[reviewId];

  // ── Fetch ──────────────────────────────────────────────────────────
  Future<void> fetchReviews() async {
    _status = ReviewsStatus.fetching;
    _errorMessage = null;
    notifyListeners();

    try {
      final resp = await _apiService.get(ApiEndpoints.vendorReviews);
      final body = resp.data as Map<String, dynamic>;
      _stats = ReviewStats.fromJson(
        (body['stats'] as Map<String, dynamic>?) ?? {},
      );
      final rawList = (body['reviews'] as List<dynamic>?) ?? [];
      _reviews = rawList
          .map((e) => VendorReview.fromJson(e as Map<String, dynamic>))
          .toList();
      _status = ReviewsStatus.idle;
    } on DioException catch (e) {
      _errorMessage = _parseDioError(e);
      _status = ReviewsStatus.error;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred. Please try again.';
      _status = ReviewsStatus.error;
      debugPrint('[ReviewsViewModel] fetchReviews: $e');
    }
    notifyListeners();
  }

  // ── Reply ──────────────────────────────────────────────────────────
  Future<bool> submitReply(int reviewId, String replyText) async {
    final trimmed = replyText.trim();
    if (trimmed.isEmpty) {
      _replyErrors[reviewId] = 'Reply cannot be empty.';
      notifyListeners();
      return false;
    }

    _submitting[reviewId] = true;
    _replyErrors.remove(reviewId);
    notifyListeners();

    try {
      final resp = await _apiService.post(
        ApiEndpoints.vendorReviewReply(reviewId),
        data: {'reply': trimmed},
      );
      final body = resp.data as Map<String, dynamic>;

      // Mutate the in-memory review in-place — no refetch needed.
      final idx = _reviews.indexWhere((r) => r.id == reviewId);
      if (idx != -1) {
        _reviews[idx].reply = body['reply']?.toString() ?? trimmed;
        _reviews[idx].repliedAt = body['replied_at']?.toString();
      }

      // Update unreplied count in stats.
      final newUnreplied = (_stats.unrepliedCount - 1).clamp(0, 9999);
      _stats = ReviewStats(
        totalReviews: _stats.totalReviews,
        averageRating: _stats.averageRating,
        averageFoodRating: _stats.averageFoodRating,
        averageDeliveryRating: _stats.averageDeliveryRating,
        ratingDistribution: _stats.ratingDistribution,
        unrepliedCount: newUnreplied,
      );

      _submitting[reviewId] = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _replyErrors[reviewId] = _parseDioError(e);
      _submitting[reviewId] = false;
      notifyListeners();
      return false;
    } catch (e) {
      _replyErrors[reviewId] = 'Failed to submit reply. Please try again.';
      _submitting[reviewId] = false;
      debugPrint('[ReviewsViewModel] submitReply: $e');
      notifyListeners();
      return false;
    }
  }

  // ── Refresh ────────────────────────────────────────────────────────
  Future<void> refresh() => fetchReviews();

  // ── Helper ─────────────────────────────────────────────────────────
  String _parseDioError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      return data['error']?.toString() ??
          data['detail']?.toString() ??
          data['message']?.toString() ??
          'Server error (${e.response?.statusCode})';
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Check your network and try again.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Please check your network.';
      default:
        return 'Network error. Please try again.';
    }
  }
}

double _d(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}
