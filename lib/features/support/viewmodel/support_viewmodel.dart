import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/app_logger.dart';
import '../models/support_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Status enums
// ─────────────────────────────────────────────────────────────────────────────

enum ChatStatus { idle, starting, active, sending, ending, error }
enum TicketDetailStatus { idle, loading, replying, error }

// ═══════════════════════════════════════════════════════════════════════════════
//  SupportViewModel — Chat + Ticket Detail state management
// ═══════════════════════════════════════════════════════════════════════════════

class SupportViewModel extends ChangeNotifier with WidgetsBindingObserver {
  final ApiService _apiService;
  bool _wasPollingSuspended = false;

  SupportViewModel({required ApiService apiService})
      : _apiService = apiService {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Suspend polling when app goes to background
      if (_pollTimer != null) {
        _wasPollingSuspended = true;
        _stopPolling();
      }
    } else if (state == AppLifecycleState.resumed) {
      // Resume polling when app comes back
      if (_wasPollingSuspended && _activeSession != null && _activeSession!.isActive) {
        _wasPollingSuspended = false;
        _pollMessages(); // Immediate catch-up poll
        _startPolling();
      }
    }
  }

  // ── Optimistic message ID — monotonic counter avoids collision ──────────
  int _nextOptimisticId = -1;

  // ── Chat State ────────────────────────────────────────────────────────────
  ChatStatus _chatStatus = ChatStatus.idle;
  ChatSession? _activeSession;
  List<ChatMessage> _messages = [];
  List<ChatSession> _pastSessions = [];
  List<KnowledgeBaseArticle> _faqs = [];
  String? _chatError;
  Timer? _pollTimer;
  int _pollFailures = 0;
  static const _maxPollFailures = 3;
  bool _hasRatedSession = false;
  // Map replyId → label so polling can fix display text persistently
  final Map<String, String> _replyIdLabels = {};

  // ── Ticket Detail State ───────────────────────────────────────────────────
  TicketDetailStatus _ticketDetailStatus = TicketDetailStatus.idle;
  TicketDetail? _ticketDetail;
  String? _ticketError;

  // ── Getters — Chat ────────────────────────────────────────────────────────
  ChatStatus get chatStatus => _chatStatus;
  ChatSession? get activeSession => _activeSession;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<ChatSession> get pastSessions => _pastSessions;
  List<KnowledgeBaseArticle> get faqs => _faqs;
  String? get chatError => _chatError;
  bool get isChatActive => _activeSession != null && _activeSession!.isActive;
  bool get isSending => _chatStatus == ChatStatus.sending;
  bool get hasRatedSession => _hasRatedSession;
  int get messageCount => _messages.length;

  // ── Getters — Ticket Detail ───────────────────────────────────────────────
  TicketDetailStatus get ticketDetailStatus => _ticketDetailStatus;
  TicketDetail? get ticketDetail => _ticketDetail;
  String? get ticketError => _ticketError;
  bool get isTicketLoading => _ticketDetailStatus == TicketDetailStatus.loading;
  bool get isReplying => _ticketDetailStatus == TicketDetailStatus.replying;

  // ═══════════════════════════════════════════════════════════════════════════
  //  CHAT — Start session
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> startChatSession() async {
    if (_chatStatus == ChatStatus.starting) return false; // double-tap guard
    _chatStatus = ChatStatus.starting;
    _chatError = null;
    notifyListeners();

    try {
      final response = await _apiService.post(
        ApiEndpoints.chatSessionStart,
        data: {'platform': 'vendor'},
      );
      final body = _asMap(response.data);
      final data = body['data'] as Map<String, dynamic>? ?? body;

      _activeSession = ChatSession.fromJson(data);
      _messages = List<ChatMessage>.from(_activeSession!.messages);
      _chatStatus = ChatStatus.active;
      _startPolling();
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _chatError = _parseDioError(e);
      _chatStatus = ChatStatus.error;
      notifyListeners();
      AppLogger.e('startChatSession failed', e);
      return false;
    } catch (e) {
      _chatError = 'Failed to start chat';
      _chatStatus = ChatStatus.error;
      notifyListeners();
      AppLogger.e('startChatSession unexpected', e);
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  CHAT — Send message
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> sendMessage({
    required String content,
    String type = 'text',
  }) async {
    if (_activeSession == null) return false;
    if (_chatStatus == ChatStatus.sending) return false; // double-tap guard

    _chatStatus = ChatStatus.sending;
    _chatError = null;

    // Optimistic: add user message immediately
    final optimisticMsg = ChatMessage(
      id: _nextOptimisticId--,
      senderType: 'user',
      messageType: 'text',
      content: TextContent(text: content),
      createdAt: DateTime.now(),
    );
    _messages.add(optimisticMsg);
    notifyListeners();

    try {
      final endpoint = ApiEndpoints.chatSessionMessage(_activeSession!.sessionId);
      final response = await _apiService.post(
        endpoint,
        data: {'type': type, 'content': content},
      );
      final body = _asMap(response.data);
      final data = body['data'] as Map<String, dynamic>? ?? body;

      // Server returns ALL session messages — full replace
      final rawMessages = data['messages'] as List<dynamic>? ?? [];
      _messages = rawMessages.map((e) {
        if (e is Map<String, dynamic>) return e;
        if (e is Map) return Map<String, dynamic>.from(e);
        return null;
      }).whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList();

      // Update session status if returned
      if (data['session_status'] is String) {
        _activeSession = ChatSession(
          sessionId: _activeSession!.sessionId,
          status: data['session_status'] as String,
          startedAt: _activeSession!.startedAt,
        );
      }

      _chatStatus = ChatStatus.active;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      // Remove optimistic message on failure
      _messages.removeWhere((m) => m.id == optimisticMsg.id);
      _chatError = _parseDioError(e);
      _chatStatus = ChatStatus.active; // stay active, just show error
      notifyListeners();
      AppLogger.e('sendMessage failed', e);
      return false;
    } catch (e) {
      _messages.removeWhere((m) => m.id == optimisticMsg.id);
      _chatError = 'Failed to send message';
      _chatStatus = ChatStatus.active;
      notifyListeners();
      AppLogger.e('sendMessage unexpected', e);
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  CHAT — Send quick reply
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> sendQuickReply(String replyId, String label) async {
    if (_activeSession == null) return false;
    if (_chatStatus == ChatStatus.sending) return false;

    _chatStatus = ChatStatus.sending;
    _chatError = null;

    // Store mapping so polls can also fix the display text
    _replyIdLabels[replyId] = label;

    // Optimistic: show the label as user message
    final optimisticMsg = ChatMessage(
      id: _nextOptimisticId--,
      senderType: 'user',
      messageType: 'text',
      content: TextContent(text: label),
      createdAt: DateTime.now(),
    );
    _messages.add(optimisticMsg);
    notifyListeners();

    try {
      final endpoint = ApiEndpoints.chatSessionMessage(_activeSession!.sessionId);
      final response = await _apiService.post(
        endpoint,
        data: {'type': 'quick_reply', 'content': replyId},
      );
      final body = _asMap(response.data);
      final data = body['data'] as Map<String, dynamic>? ?? body;

      // Server returns ALL session messages — full replace
      final rawMessages = data['messages'] as List<dynamic>? ?? [];
      _messages = rawMessages.map((e) {
        if (e is Map<String, dynamic>) return e;
        if (e is Map) return Map<String, dynamic>.from(e);
        return null;
      }).whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList();

      // Backend saves replyId as user message text — replace with label
      _fixAllReplyDisplayTexts();

      if (data['session_status'] is String) {
        _activeSession = ChatSession(
          sessionId: _activeSession!.sessionId,
          status: data['session_status'] as String,
          startedAt: _activeSession!.startedAt,
        );
      }

      _chatStatus = ChatStatus.active;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _messages.removeWhere((m) => m.id == optimisticMsg.id);
      _chatError = _parseDioError(e);
      _chatStatus = ChatStatus.active;
      notifyListeners();
      AppLogger.e('sendQuickReply failed', e);
      return false;
    } catch (e) {
      _messages.removeWhere((m) => m.id == optimisticMsg.id);
      _chatError = 'Failed to send reply';
      _chatStatus = ChatStatus.active;
      notifyListeners();
      AppLogger.e('sendQuickReply unexpected', e);
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  CHAT — Submit form
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> submitForm(Map<String, dynamic> formData) async {
    if (_activeSession == null) return false;
    if (_chatStatus == ChatStatus.sending) return false;

    _chatStatus = ChatStatus.sending;
    _chatError = null;
    notifyListeners();

    try {
      final endpoint = ApiEndpoints.chatSessionMessage(_activeSession!.sessionId);
      final response = await _apiService.post(
        endpoint,
        data: {'type': 'form_submit', 'content': formData},
      );
      final body = _asMap(response.data);
      final data = body['data'] as Map<String, dynamic>? ?? body;

      // Server returns ALL session messages — full replace
      final rawMessages = data['messages'] as List<dynamic>? ?? [];
      _messages = rawMessages.map((e) {
        if (e is Map<String, dynamic>) return e;
        if (e is Map) return Map<String, dynamic>.from(e);
        return null;
      }).whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList();

      _chatStatus = ChatStatus.active;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _chatError = _parseDioError(e);
      _chatStatus = ChatStatus.active;
      notifyListeners();
      AppLogger.e('submitForm failed', e);
      return false;
    } catch (e) {
      _chatError = 'Failed to submit form';
      _chatStatus = ChatStatus.active;
      notifyListeners();
      AppLogger.e('submitForm unexpected', e);
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  CHAT — Rate session
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> rateSession(int rating, {String feedback = ''}) async {
    if (_activeSession == null) return false;
    if (_hasRatedSession) return true; // Prevent double rating

    _hasRatedSession = true;
    try {
      final endpoint = ApiEndpoints.chatSessionRate(_activeSession!.sessionId);
      await _apiService.post(
        endpoint,
        data: {'rating': rating, 'feedback': feedback},
      );
      return true;
    } on DioException catch (e) {
      _hasRatedSession = false; // Allow retry on failure
      _chatError = _parseDioError(e);
      notifyListeners();
      AppLogger.e('rateSession failed', e);
      return false;
    } catch (e) {
      _hasRatedSession = false;
      AppLogger.e('rateSession unexpected', e);
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  CHAT — End session
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> endChatSession() async {
    if (_activeSession == null) return false;
    if (_chatStatus == ChatStatus.ending) return false;

    _chatStatus = ChatStatus.ending;
    notifyListeners();

    try {
      final endpoint = ApiEndpoints.chatSessionEnd(_activeSession!.sessionId);
      await _apiService.post(endpoint);
      _stopPolling();
      _chatStatus = ChatStatus.idle;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _chatError = _parseDioError(e);
      _chatStatus = ChatStatus.active;
      notifyListeners();
      AppLogger.e('endChatSession failed', e);
      return false;
    } catch (e) {
      _chatError = 'Failed to end chat';
      _chatStatus = ChatStatus.active;
      notifyListeners();
      AppLogger.e('endChatSession unexpected', e);
      return false;
    }
  }

  /// Clear chat state when navigating away
  void clearChat() {
    _stopPolling();
    _activeSession = null;
    _messages = [];
    _chatStatus = ChatStatus.idle;
    _chatError = null;
    _hasRatedSession = false;
    _replyIdLabels.clear();
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  CHAT — Polling for new messages
  // ═══════════════════════════════════════════════════════════════════════════

  void _startPolling() {
    _stopPolling();
    _pollFailures = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _pollMessages();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollMessages() async {
    if (_activeSession == null || !_activeSession!.isActive) {
      _stopPolling();
      return;
    }
    // Don't poll while sending — would overwrite optimistic messages
    if (_chatStatus == ChatStatus.sending) return;

    try {
      final endpoint = ApiEndpoints.chatSessionDetail(_activeSession!.sessionId);
      final response = await _apiService.get(endpoint);
      final body = _asMap(response.data);
      final data = body['data'] as Map<String, dynamic>? ?? body;

      final session = ChatSession.fromJson(data);
      _pollFailures = 0; // Reset on success

      // Replace local messages if server has more messages
      if (session.messages.length > _messages.length) {
        _messages = List<ChatMessage>.from(session.messages);
        _fixAllReplyDisplayTexts(); // Fix raw reply IDs from server
        _activeSession = session;
        _chatError = null; // Clear stale errors on new data
        notifyListeners();
      }
      // Stop polling if session ended
      if (!session.isActive) {
        _activeSession = session;
        _stopPolling();
        notifyListeners();
      }
    } catch (e) {
      _pollFailures++;
      AppLogger.e('Chat poll failed ($_pollFailures/$_maxPollFailures)', e);
      if (_pollFailures >= _maxPollFailures) {
        _stopPolling();
        _chatError = 'Connection lost. Pull down to refresh.';
        notifyListeners();
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  CHAT — Past sessions
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> fetchPastSessions() async {
    try {
      final response = await _apiService.get(ApiEndpoints.chatSessions);
      final body = _asMap(response.data);
      final rawList = body['data'] as List<dynamic>? ??
          body['results'] as List<dynamic>? ??
          [];
      _pastSessions = rawList
          .whereType<Map<String, dynamic>>()
          .map(ChatSession.fromJson)
          .toList();
      notifyListeners();
    } catch (e) {
      AppLogger.e('fetchPastSessions failed', e);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  FAQs / Knowledge Base
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> fetchFaqs() async {
    try {
      final response = await _apiService.get(ApiEndpoints.chatFaqs);
      final body = response.data;
      final List<dynamic> rawList;
      if (body is Map) {
        final map = Map<String, dynamic>.from(body);
        rawList = map['data'] as List<dynamic>? ??
            map['results'] as List<dynamic>? ??
            map['articles'] as List<dynamic>? ??
            [];
      } else if (body is List) {
        rawList = body;
      } else {
        rawList = [];
      }
      _faqs = rawList
          .whereType<Map<String, dynamic>>()
          .map(KnowledgeBaseArticle.fromJson)
          .toList();
      notifyListeners();
    } catch (e) {
      AppLogger.e('fetchFaqs failed', e);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  TICKET DETAIL — Fetch
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> fetchTicketDetail(int ticketId) async {
    _ticketDetail = null; // Clear stale data — prevents old ticket flash
    _ticketDetailStatus = TicketDetailStatus.loading;
    _ticketError = null;
    notifyListeners();

    try {
      final response = await _apiService.get(
        ApiEndpoints.supportTicketDetail(ticketId),
      );
      final body = _asMap(response.data);
      final data = body['data'] as Map<String, dynamic>? ??
          body['ticket'] as Map<String, dynamic>? ??
          body;
      _ticketDetail = TicketDetail.fromJson(data);
      _ticketDetailStatus = TicketDetailStatus.idle;
    } on DioException catch (e) {
      _ticketError = _parseDioError(e);
      _ticketDetailStatus = TicketDetailStatus.error;
      AppLogger.e('fetchTicketDetail failed', e);
    } catch (e) {
      _ticketError = 'Failed to load ticket';
      _ticketDetailStatus = TicketDetailStatus.error;
      AppLogger.e('fetchTicketDetail unexpected', e);
    }
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  TICKET DETAIL — Reply
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> replyToTicket(int ticketId, String message) async {
    if (_ticketDetailStatus == TicketDetailStatus.replying) return false;
    _ticketDetailStatus = TicketDetailStatus.replying;
    _ticketError = null;
    notifyListeners();

    try {
      await _apiService.post(
        ApiEndpoints.supportTicketReply(ticketId),
        data: {'content': message},
      );
      // Refresh ticket detail to get new message
      await fetchTicketDetail(ticketId);
      return true;
    } on DioException catch (e) {
      _ticketError = _parseDioError(e);
      _ticketDetailStatus = TicketDetailStatus.error;
      notifyListeners();
      AppLogger.e('replyToTicket failed', e);
      return false;
    } catch (e) {
      _ticketError = 'Failed to send reply';
      _ticketDetailStatus = TicketDetailStatus.error;
      notifyListeners();
      AppLogger.e('replyToTicket unexpected', e);
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  TICKET DETAIL — Rate resolution
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> rateTicket(int ticketId, int rating, {String feedback = ''}) async {
    try {
      await _apiService.post(
        ApiEndpoints.supportTicketRate(ticketId),
        data: {'rating': rating, 'feedback': feedback},
      );
      // Refresh ticket detail to get updated rating
      await fetchTicketDetail(ticketId);
      return true;
    } on DioException catch (e) {
      _ticketError = _parseDioError(e);
      notifyListeners();
      AppLogger.e('rateTicket failed', e);
      return false;
    } catch (e) {
      _ticketError = 'Failed to submit rating';
      notifyListeners();
      AppLogger.e('rateTicket unexpected', e);
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Cleanup
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// Replace raw reply IDs in user messages with human-readable labels.
  /// Backend stores "intent:order_status" as text — we replace with "Order Issue".
  /// Uses _replyIdLabels map so fixes persist across polls.
  void _fixAllReplyDisplayTexts() {
    if (_replyIdLabels.isEmpty) return;
    for (int i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      if (!m.isUser) continue;

      // Extract raw text from either TextContent or QuickReplyContent
      // (backend saves user quick replies as message_type: 'quick_replies')
      String? rawText;
      if (m.content is TextContent) {
        rawText = (m.content as TextContent).text;
      } else if (m.content is QuickReplyContent) {
        rawText = (m.content as QuickReplyContent).text;
      }
      if (rawText == null) continue;

      final label = _replyIdLabels[rawText];
      if (label != null) {
        _messages[i] = ChatMessage(
          id: m.id,
          senderType: m.senderType,
          messageType: 'text',
          content: TextContent(text: label),
          createdAt: m.createdAt,
        );
      }
    }
  }

  /// Safely cast response data to Map — avoids hard `as Map` crash.
  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  static String _parseDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Please try again.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection';
    }

    final statusCode = e.response?.statusCode;
    final data = e.response?.data;

    // Try extracting message from response body (any Map shape)
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      // Nested: {"error": {"message": "..."}} or {"error": {"code": ..., "message": "..."}}
      final error = map['error'];
      if (error is Map) {
        final msg = error['message'];
        if (msg is String && msg.isNotEmpty) return msg;
      }
      if (error is String && error.isNotEmpty) return error;
      if (map['message'] is String) return map['message'] as String;
      if (map['detail'] is String) return map['detail'] as String;
    }

    // Status-code specific fallbacks
    if (statusCode == 429) {
      return 'Too many requests. Please wait a few minutes and try again.';
    }
    if (statusCode == 401) {
      return 'Session expired. Please login again.';
    }
    if (statusCode == 403) {
      return 'You do not have permission for this action';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'Server error. Please try again later.';
    }
    return 'Something went wrong. Please try again.';
  }
}
