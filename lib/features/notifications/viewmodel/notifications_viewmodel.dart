import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Notification model
// ─────────────────────────────────────────────────────────────────────────────

class AppNotification {
  final String id;
  final String type;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final String timeAgo;
  final String? actionUrl;
  final String priority;
  final int? orderId;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
    required this.timeAgo,
    this.actionUrl,
    this.priority = 'normal',
    this.orderId,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['created_at'] as String? ?? '');
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return AppNotification(
      id: json['id']?.toString() ?? '',
      type: json['notification_type'] as String? ?? 'system',
      title: json['title'] as String? ?? 'Notification',
      message: json['message'] as String? ?? '',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: parsedDate,
      timeAgo: json['time_ago'] as String? ?? '',
      actionUrl: json['action_url'] as String?,
      priority: json['priority'] as String? ?? 'normal',
      orderId: (json['order_id'] as num?)?.toInt(),
    );
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        type: type,
        title: title,
        message: message,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        timeAgo: timeAgo,
        actionUrl: actionUrl,
        priority: priority,
        orderId: orderId,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  ViewModel
// ─────────────────────────────────────────────────────────────────────────────

enum NotificationsStatus { initial, loading, loaded, error }

class NotificationsViewModel extends ChangeNotifier {
  final ApiService _apiService;

  NotificationsStatus _status = NotificationsStatus.initial;
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  int _totalCount = 0;
  String? _error;

  // Pagination
  int _currentPage = 1;
  static const int _pageSize = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  NotificationsViewModel({required ApiService apiService})
      : _apiService = apiService;

  // ── Getters ──────────────────────────────────────────────────────────────
  NotificationsStatus get status => _status;
  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;
  int get totalCount => _totalCount;
  String? get error => _error;
  bool get isLoading => _status == NotificationsStatus.loading;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasNotifications => _notifications.isNotEmpty;

  // ── Fetch first page ────────────────────────────────────────────────────
  Future<void> fetchNotifications() async {
    _status = NotificationsStatus.loading;
    _error = null;
    _currentPage = 1;
    _hasMore = true;
    notifyListeners();

    try {
      final resp = await _apiService.get(
        ApiEndpoints.notifications,
        queryParameters: {'page': 1, 'page_size': _pageSize},
      );
      final body = resp.data as Map<String, dynamic>;
      _parseResponse(body, replace: true);
      _status = NotificationsStatus.loaded;
    } on DioException catch (e) {
      _error = _parseDioError(e);
      _status = NotificationsStatus.error;
    } catch (e) {
      _error = 'Failed to load notifications.';
      _status = NotificationsStatus.error;
      debugPrint('[Notifications] fetch error: $e');
    }

    notifyListeners();
  }

  // ── Load more (pagination) ──────────────────────────────────────────────
  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      _currentPage++;
      final resp = await _apiService.get(
        ApiEndpoints.notifications,
        queryParameters: {'page': _currentPage, 'page_size': _pageSize},
      );
      final body = resp.data as Map<String, dynamic>;
      _parseResponse(body, replace: false);
    } catch (e) {
      _currentPage--;
      debugPrint('[Notifications] loadMore error: $e');
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  // ── Mark specific notifications as read ─────────────────────────────────
  Future<void> markAsRead(List<String> ids) async {
    if (ids.isEmpty) return;

    // Optimistic update
    int markedCount = 0;
    _notifications = _notifications.map((n) {
      if (ids.contains(n.id) && !n.isRead) {
        markedCount++;
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();
    _unreadCount = (_unreadCount - markedCount).clamp(0, _totalCount);
    notifyListeners();

    try {
      await _apiService.post(
        ApiEndpoints.notificationsMarkRead,
        data: {'notification_ids': ids},
      );
    } catch (e) {
      debugPrint('[Notifications] markAsRead error: $e');
      // Re-fetch to get correct state on failure
      await fetchNotifications();
    }
  }

  // ── Mark all as read → clear list (read = done, no need to show) ────────
  Future<void> markAllAsRead() async {
    _notifications = [];
    _unreadCount = 0;
    _totalCount = 0;
    notifyListeners();

    try {
      await _apiService.post(ApiEndpoints.notificationsMarkRead, data: {});
    } catch (e) {
      debugPrint('[Notifications] markAllAsRead error: $e');
    }
  }

  // ── Delete single notification ──────────────────────────────────────────
  Future<void> deleteNotification(String id) async {
    // Optimistic removal
    final removed =
        _notifications.where((n) => n.id == id).firstOrNull;
    _notifications = _notifications.where((n) => n.id != id).toList();
    _totalCount = (_totalCount - 1).clamp(0, _totalCount);
    if (removed != null && !removed.isRead) {
      _unreadCount = (_unreadCount - 1).clamp(0, _totalCount);
    }
    notifyListeners();

    try {
      await _apiService.delete(ApiEndpoints.notificationDelete(id));
    } catch (e) {
      debugPrint('[Notifications] delete error: $e');
      // Re-add on failure
      if (removed != null) {
        await fetchNotifications();
      }
    }
  }

  // ── Fetch just the unread count (for dashboard badge) ───────────────────
  Future<int> fetchUnreadCount() async {
    try {
      final resp = await _apiService.get(ApiEndpoints.notificationsStats);
      final body = resp.data as Map<String, dynamic>;
      _unreadCount = (body['unread'] as num?)?.toInt() ?? 0;
      return _unreadCount;
    } catch (e) {
      debugPrint('[Notifications] fetchUnreadCount error: $e');
      return _unreadCount;
    }
  }

  // ── Refresh ─────────────────────────────────────────────────────────────
  Future<void> refresh() => fetchNotifications();

  // ── Private helpers ─────────────────────────────────────────────────────
  void _parseResponse(Map<String, dynamic> body, {required bool replace}) {
    final rawList = body['notifications'] as List<dynamic>? ?? [];
    final parsed = rawList
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();

    // Only keep unread — read notifications are removed on tap anyway
    final unreadParsed = parsed.where((n) => !n.isRead).toList();
    if (replace) {
      _notifications = unreadParsed;
    } else {
      _notifications = [..._notifications, ...unreadParsed];
    }

    _unreadCount = (body['unread_count'] as num?)?.toInt() ?? _unreadCount;

    final pagination = body['pagination'] as Map<String, dynamic>?;
    if (pagination != null) {
      _totalCount = (pagination['total_count'] as num?)?.toInt() ?? 0;
      final totalPages = (pagination['total_pages'] as num?)?.toInt() ?? 1;
      _hasMore = _currentPage < totalPages;
    } else {
      _hasMore = false;
    }
  }

  String _parseDioError(DioException e) {
    if (e.response == null) {
      return e.type == DioExceptionType.connectionError
          ? 'No internet connection.'
          : 'Network error. Please try again.';
    }
    final data = e.response!.data;
    if (data is Map) {
      return data['message']?.toString() ??
          data['detail']?.toString() ??
          'Server error (${e.response?.statusCode})';
    }
    return 'Error ${e.response!.statusCode}. Please try again.';
  }
}
