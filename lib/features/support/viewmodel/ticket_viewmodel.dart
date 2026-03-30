import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Model
// ─────────────────────────────────────────────────────────────────────────────

class SupportTicket {
  final int id;
  final String ticketNumber;
  final String subject;
  final String category;
  final String categoryDisplay;
  final String priority;
  final String priorityDisplay;
  final String status;
  final String statusDisplay;
  final int? relatedOrderId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final bool hasUnreadResponse;

  const SupportTicket({
    required this.id,
    required this.ticketNumber,
    required this.subject,
    required this.category,
    required this.categoryDisplay,
    required this.priority,
    required this.priorityDisplay,
    required this.status,
    required this.statusDisplay,
    this.relatedOrderId,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.hasUnreadResponse = false,
  });

  bool get isOpen =>
      status == 'open' ||
      status == 'assigned' ||
      status == 'in_progress' ||
      status == 'waiting_customer' ||
      status == 'waiting_vendor' ||
      status == 'waiting_internal' ||
      status == 'escalated' ||
      status == 'on_hold' ||
      status == 'reopened';

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: _safeInt(json['id']),
      ticketNumber: (json['ticket_number'] as String?) ?? '',
      subject: (json['subject'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'other',
      categoryDisplay: (json['category_display'] as String?) ?? 'Other',
      priority: (json['priority'] as String?) ?? 'medium',
      priorityDisplay: (json['priority_display'] as String?) ?? 'Medium',
      status: (json['status'] as String?) ?? 'open',
      statusDisplay: (json['status_display'] as String?) ?? 'Open',
      relatedOrderId: _safeIntOrNull(json['related_order_id']),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      resolvedAt: json['resolved_at'] != null
          ? _parseDate(json['resolved_at'])
          : null,
      hasUnreadResponse: (json['has_unread_response'] as bool?) ?? false,
    );
  }

  static DateTime _parseDate(dynamic v) {
    if (v is String && v.isNotEmpty) {
      return DateTime.tryParse(v) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static int _safeInt(dynamic v, [int fallback = 0]) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static int? _safeIntOrNull(dynamic v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Status
// ─────────────────────────────────────────────────────────────────────────────

enum TicketsStatus { idle, fetching, error }

// ─────────────────────────────────────────────────────────────────────────────
//  ViewModel
// ─────────────────────────────────────────────────────────────────────────────

class TicketViewModel extends ChangeNotifier {
  final ApiService _apiService;
  bool _isDisposed = false;

  TicketViewModel({required ApiService apiService})
      : _apiService = apiService;

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  // ── State ────────────────────────────────────────────────────────────────
  TicketsStatus _status = TicketsStatus.idle;
  List<SupportTicket> _tickets = [];
  String? _errorMessage;
  bool _isBusy = false;

  // ── Getters ──────────────────────────────────────────────────────────────
  TicketsStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get hasData => _tickets.isNotEmpty;
  bool get isBusy => _isBusy;

  List<SupportTicket> get all => List.unmodifiable(_tickets);
  List<SupportTicket> get open => _tickets.where((t) => t.isOpen).toList();
  List<SupportTicket> get resolved =>
      _tickets.where((t) => !t.isOpen).toList();
  int get openCount => open.length;
  int get resolvedCount => resolved.length;

  // ── Fetch ────────────────────────────────────────────────────────────────
  Future<void> fetchTickets() async {
    _status = TicketsStatus.fetching;
    _errorMessage = null;
    _notify();

    try {
      final resp = await _apiService.get(ApiEndpoints.supportTickets);
      final data = resp.data;
      final List<dynamic> rawList;
      if (data is Map<String, dynamic>) {
        rawList = (data['tickets'] as List<dynamic>?) ??
            (data['results'] as List<dynamic>?) ??
            [];
      } else if (data is List) {
        rawList = data;
      } else {
        rawList = [];
      }
      _tickets = rawList
          .whereType<Map<String, dynamic>>()
          .map(SupportTicket.fromJson)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _status = TicketsStatus.idle;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return;
      _errorMessage = _parseDioError(e);
      _status = TicketsStatus.error;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred.';
      _status = TicketsStatus.error;
      debugPrint('[TicketVM] fetchTickets: $e');
    }
    _notify();
  }

  // ── Create ───────────────────────────────────────────────────────────────
  Future<bool> createTicket({
    required String subject,
    required String description,
    required String category,
  }) async {
    _isBusy = true;
    _errorMessage = null;
    _notify();

    final data = <String, dynamic>{
      'subject': subject,
      'description': description,
      'category': category,
      'priority': 'medium',
      'source_channel': 'app',
    };

    debugPrint('[TicketVM] Creating ticket: $data');

    try {
      final resp = await _apiService.post(
        ApiEndpoints.supportTicketCreate,
        data: data,
      );
      debugPrint('[TicketVM] Ticket created: ${resp.statusCode}');
      await fetchTickets();
      _isBusy = false;
      _notify();
      return true;
    } on DioException catch (e) {
      debugPrint('[TicketVM] DioError: ${e.type} — ${e.message}');
      debugPrint('[TicketVM] Response: ${e.response?.statusCode} ${e.response?.data}');
      _errorMessage = _parseDioError(e);
      _isBusy = false;
      _notify();
      return false;
    } catch (e) {
      debugPrint('[TicketVM] Unexpected: $e');
      _errorMessage = 'Failed to create ticket. Please try again.';
      _isBusy = false;
      _notify();
      return false;
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _parseDioError(DioException e) {
    final statusCode = e.response?.statusCode;
    final data = e.response?.data;

    // Try extracting message from response body (any Map shape)
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      // Nested: {"error": {"message": "..."}}
      final error = map['error'];
      if (error is Map) {
        final msg = error['message'];
        if (msg is String && msg.isNotEmpty) return msg;
      }
      if (error is String && error.isNotEmpty) return error;
      if (map['message'] is String) return map['message'] as String;
      if (map['detail'] is String) return map['detail'] as String;
      // Field-level errors: {"field_name": ["error message"]}
      for (final val in map.values) {
        if (val is List && val.isNotEmpty) return val.first.toString();
      }
    }

    if (statusCode == 429) {
      return 'Too many requests. Please wait a few minutes.';
    }
    if (statusCode == 401) {
      return 'Session expired. Please login again.';
    }
    if (statusCode == 403) return 'Access denied.';
    if (statusCode == 404) return 'Not found.';
    if ((statusCode ?? 0) >= 500) {
      return 'Server error. Try again later.';
    }
    return e.message ?? 'Network error. Please check your connection.';
  }
}
