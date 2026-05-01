// ─────────────────────────────────────────
// Zill Restaurant Partner — Vendor App
// Author: Vashu Mogha (@Its-vashu)
// ─────────────────────────────────────────
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

  StreamSubscription<void>? _sessionExpiredSub;

  SupportViewModel({required ApiService apiService})
      : _apiService = apiService {
    WidgetsBinding.instance.addObserver(this);
    _sessionExpiredSub = ApiService.onSessionExpired.listen((_) {
      clearSession();
    });
  }

  /// Wipe every vendor-scoped field so a logout + new login doesn't
  /// surface the previous vendor's support chat + past tickets.
  void clearSession() {
    _stopPolling();
    _chatStatus = ChatStatus.idle;
    _activeSession = null;
    _messages = [];
    _pastSessions = [];
    _faqs = [];
    _chatError = null;
    _replyIdLabels.clear();
    _seenMessageIds.clear();
    _lastMessageId = '';
    _ticketDetailStatus = TicketDetailStatus.idle;
    _ticketDetail = null;
    _ticketError = null;
    _wasPollingSuspended = false;
    notifyListeners();
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
  // Deduplication: track rendered message IDs to skip duplicates
  final Set<String> _seenMessageIds = {};
  // Last message UUID for poll?after= parameter
  String _lastMessageId = '';

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

    // Resume existing session if still in memory
    if (_activeSession != null && _activeSession!.isActive && _messages.isNotEmpty) {
      _chatStatus = ChatStatus.active;
      _startPolling();
      notifyListeners();
      return true;
    }

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
      // Seed deduplication set and last message ID
      _seenMessageIds.clear();
      for (final m in _messages) {
        if (m.rawId.isNotEmpty) _seenMessageIds.add(m.rawId);
      }
      _lastMessageId = '';
      _updateLastMessageId();
      _replyIdLabels.clear();
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

      // Server returns ONLY NEW bot responses — keep optimistic user msg, append bot msgs
      final rawMessages = data['messages'] as List<dynamic>? ?? [];
      final newMessages = rawMessages.map((e) {
        if (e is Map<String, dynamic>) return e;
        if (e is Map) return Map<String, dynamic>.from(e);
        return null;
      }).whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .where((m) => m.rawId.isNotEmpty && !_seenMessageIds.contains(m.rawId))
          .toList();

      // DON'T remove optimistic message — server only sends bot responses
      // If server returns the user message too, replace optimistic with it
      final serverUserMsg = newMessages.where((m) => m.isUser).firstOrNull;
      if (serverUserMsg != null) {
        _messages.removeWhere((m) => m.id == optimisticMsg.id);
      }

      // Append only new messages
      for (final m in newMessages) {
        if (m.rawId.isNotEmpty) _seenMessageIds.add(m.rawId);
        _messages.add(m);
      }
      _updateLastMessageId();

      // Update session status if returned
      if (data['session_status'] is String) {
        final newStatus = data['session_status'] as String;
        _activeSession = ChatSession(
          sessionId: _activeSession!.sessionId,
          status: newStatus,
          startedAt: _activeSession!.startedAt,
        );
        if (newStatus == 'escalated') {
          _startPolling();
        } else if (newStatus != 'active') {
          _stopPolling();
        }
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

      // Server now returns ONLY NEW bot responses — append, don't replace
      final rawMessages = data['messages'] as List<dynamic>? ?? [];
      final newMessages = rawMessages.map((e) {
        if (e is Map<String, dynamic>) return e;
        if (e is Map) return Map<String, dynamic>.from(e);
        return null;
      }).whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .where((m) => m.rawId.isNotEmpty && !_seenMessageIds.contains(m.rawId))
          .toList();

      // Keep optimistic message — server only sends bot responses
      final serverUserMsg = newMessages.where((m) => m.isUser).firstOrNull;
      if (serverUserMsg != null) {
        _messages.removeWhere((m) => m.id == optimisticMsg.id);
      }

      for (final m in newMessages) {
        if (m.rawId.isNotEmpty) _seenMessageIds.add(m.rawId);
        _messages.add(m);
      }
      _fixAllReplyDisplayTexts();
      _updateLastMessageId();

      if (data['session_status'] is String) {
        final newStatus = data['session_status'] as String;
        _activeSession = ChatSession(
          sessionId: _activeSession!.sessionId,
          status: newStatus,
          startedAt: _activeSession!.startedAt,
        );
        if (newStatus == 'escalated') {
          _startPolling();
        } else if (newStatus != 'active') {
          _stopPolling();
        }
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

      // Server returns ALL session messages — full replace only if non-empty
      final rawMessages = data['messages'] as List<dynamic>? ?? [];
      final serverMessages = rawMessages.map((e) {
        if (e is Map<String, dynamic>) return e;
        if (e is Map) return Map<String, dynamic>.from(e);
        return null;
      }).whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList();

      // Guard: never lose messages — only replace if server has data
      if (serverMessages.isNotEmpty) {
        _messages = serverMessages;
      }

      // Update session status if returned
      if (data['session_status'] is String) {
        final newStatus = data['session_status'] as String;
        _activeSession = ChatSession(
          sessionId: _activeSession!.sessionId,
          status: newStatus,
          startedAt: _activeSession!.startedAt,
        );
        if (newStatus != 'active') _stopPolling();
      }

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
      resetChat();
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

  /// Pause chat when navigating away — keep session alive for resume
  void clearChat() {
    _stopPolling();
    _chatError = null;
    // DON'T clear session/messages — they're needed when user comes back
  }

  /// Fully reset chat state (after explicit end/resolve)
  void resetChat() {
    _stopPolling();
    _activeSession = null;
    _messages = [];
    _chatStatus = ChatStatus.idle;
    _chatError = null;
    _hasRatedSession = false;
    _replyIdLabels.clear();
    _seenMessageIds.clear();
    _lastMessageId = '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
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
    if (_activeSession == null) {
      _stopPolling();
      return;
    }
    // Don't poll while sending — would overwrite optimistic messages
    if (_chatStatus == ChatStatus.sending) return;

    try {
      // Use new poll endpoint with after= for incremental fetch
      final endpoint = ApiEndpoints.chatSessionPoll(_activeSession!.sessionId);
      final response = await _apiService.get(
        endpoint,
        queryParameters: {'after': _lastMessageId.toString()},
      );
      final body = _asMap(response.data);
      final data = body['data'] as Map<String, dynamic>? ?? body;

      _pollFailures = 0; // Reset on success

      // Append only new messages (deduplication)
      final rawMessages = data['messages'] as List<dynamic>? ?? [];
      final newMessages = rawMessages.map((e) {
        if (e is Map<String, dynamic>) return e;
        if (e is Map) return Map<String, dynamic>.from(e);
        return null;
      }).whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .where((m) => m.rawId.isNotEmpty && !_seenMessageIds.contains(m.rawId))
          .toList();

      if (newMessages.isNotEmpty) {
        for (final m in newMessages) {
          if (m.rawId.isNotEmpty) _seenMessageIds.add(m.rawId);
          _messages.add(m);
        }
        _fixAllReplyDisplayTexts();
        _updateLastMessageId();
        _chatError = null;
        notifyListeners();
      }

      // Update session status
      final sessionStatus = data['session_status'] as String?;
      if (sessionStatus != null) {
        _activeSession = ChatSession(
          sessionId: _activeSession!.sessionId,
          status: sessionStatus,
          startedAt: _activeSession!.startedAt,
        );
        if (sessionStatus == 'resolved' || sessionStatus == 'expired' || sessionStatus == 'abandoned') {
          _stopPolling();
          notifyListeners();
        }
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
      final ticketJson = body['data'] as Map<String, dynamic>? ??
          body['ticket'] as Map<String, dynamic>? ??
          body;
      // Backend returns messages at root level, not inside 'ticket'
      if (body['messages'] is List && ticketJson['messages'] == null) {
        ticketJson['messages'] = body['messages'];
      }
      _ticketDetail = TicketDetail.fromJson(ticketJson);
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
        data: {'message': message},
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
    _sessionExpiredSub?.cancel();
    _stopPolling();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// Update _lastMessageId from the current message list.
  void _updateLastMessageId() {
    if (_messages.isNotEmpty) {
      // Use the rawId of the last real (non-optimistic) message
      final lastReal = _messages.lastWhere(
        (m) => m.rawId.isNotEmpty,
        orElse: () => _messages.last,
      );
      if (lastReal.rawId.isNotEmpty) {
        _lastMessageId = lastReal.rawId;
      }
    }
  }

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
          rawId: m.rawId,
          senderType: m.senderType,
          messageType: 'text',
          content: TextContent(text: label),
          createdAt: m.createdAt,
          senderName: m.senderName,
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
