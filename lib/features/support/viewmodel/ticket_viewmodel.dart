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
      status == 'in_progress' ||
      status == 'waiting_customer' ||
      status == 'waiting_vendor';

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'] as int,
      ticketNumber: (json['ticket_number'] as String?) ?? '',
      subject: (json['subject'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'other',
      categoryDisplay: (json['category_display'] as String?) ?? 'Other',
      priority: (json['priority'] as String?) ?? 'medium',
      priorityDisplay: (json['priority_display'] as String?) ?? 'Medium',
      status: (json['status'] as String?) ?? 'open',
      statusDisplay: (json['status_display'] as String?) ?? 'Open',
      relatedOrderId: json['related_order_id'] as int?,
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

  TicketViewModel({required ApiService apiService})
      : _apiService = apiService;

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
    notifyListeners();

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
          .map((e) => SupportTicket.fromJson(e as Map<String, dynamic>))
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
    notifyListeners();
  }

  // ── Create ───────────────────────────────────────────────────────────────
  Future<bool> createTicket({
    required String subject,
    required String description,
    required String category,
  }) async {
    _isBusy = true;
    notifyListeners();

    final data = <String, dynamic>{
      'subject': subject,
      'description': description,
      'category': category,
      'priority': 'medium',
    };

    try {
      await _apiService.post(ApiEndpoints.supportTicketCreate, data: data);
      await fetchTickets();
      return true;
    } on DioException catch (e) {
      _errorMessage = _parseDioError(e);
      _isBusy = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to create ticket.';
      _isBusy = false;
      notifyListeners();
      debugPrint('[TicketVM] createTicket: $e');
      return false;
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _parseDioError(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      for (final key in data.keys) {
        final val = data[key];
        if (val is List && val.isNotEmpty) return val.first.toString();
        if (val is String) return val;
      }
      if (data.containsKey('error')) return data['error'].toString();
      if (data.containsKey('detail')) return data['detail'].toString();
    }
    if (e.response?.statusCode == 401) {
      return 'Session expired. Please login again.';
    }
    if (e.response?.statusCode == 403) return 'Access denied.';
    if (e.response?.statusCode == 404) return 'Not found.';
    if ((e.response?.statusCode ?? 0) >= 500) {
      return 'Server error. Try again later.';
    }
    return e.message ?? 'Network error. Please check your connection.';
  }
}
