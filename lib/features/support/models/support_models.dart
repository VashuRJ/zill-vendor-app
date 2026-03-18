// ═══════════════════════════════════════════════════════════════════════════════
//  Support Models — Polymorphic Chat Messages + Tickets + Knowledge Base
// ═══════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────────────
//  Chat Session
// ─────────────────────────────────────────────────────────────────────────────

class ChatSession {
  final String sessionId;
  final String status; // active, resolved, escalated, abandoned, expired
  final String platform;
  final String? currentState;
  final String? currentIntent;
  final int? satisfactionRating;
  final String? languageDetected;
  final int messageCount;
  final DateTime startedAt;
  final DateTime? endedAt;
  final List<ChatMessage> messages;

  const ChatSession({
    required this.sessionId,
    required this.status,
    this.platform = 'vendor_app',
    this.currentState,
    this.currentIntent,
    this.satisfactionRating,
    this.languageDetected,
    this.messageCount = 0,
    required this.startedAt,
    this.endedAt,
    this.messages = const [],
  });

  bool get isActive => status == 'active' || status == 'escalated';
  bool get isEscalated => status == 'escalated';
  bool get isEnded =>
      status == 'resolved' ||
      status == 'abandoned' ||
      status == 'expired';

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'] as List<dynamic>? ?? [];
    return ChatSession(
      sessionId: (json['session_id'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'active',
      platform: (json['platform'] as String?) ?? 'vendor_app',
      currentState: json['current_state'] as String?,
      currentIntent: json['current_intent'] as String?,
      satisfactionRating: _safeIntOrNull(json['satisfaction_rating']),
      languageDetected: json['language_detected'] as String?,
      messageCount: _safeInt(json['message_count']),
      startedAt: _parseDate(json['started_at']),
      endedAt: json['ended_at'] != null ? _parseDate(json['ended_at']) : null,
      messages: rawMessages
          .map((e) {
            if (e is Map<String, dynamic>) return e;
            if (e is Map) return Map<String, dynamic>.from(e);
            return null;
          })
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Chat Message  (polymorphic content based on message_type)
// ─────────────────────────────────────────────────────────────────────────────

class ChatMessage {
  final int id;
  final String rawId; // Original UUID string from backend
  final String senderType; // user, bot, system, agent
  final String messageType;
  final MessageContent content;
  final DateTime createdAt;
  final String senderName;

  const ChatMessage({
    required this.id,
    this.rawId = '',
    required this.senderType,
    required this.messageType,
    required this.content,
    required this.createdAt,
    this.senderName = '',
  });

  bool get isUser => senderType == 'user';
  bool get isBot => senderType == 'bot';
  bool get isSystem => senderType == 'system' || messageType == 'agent_joined';
  bool get isAgent => senderType == 'agent';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final type = (json['message_type'] as String?) ?? 'text';
    final rawContent = json['content'];
    final Map<String, dynamic> contentMap;
    if (rawContent is Map<String, dynamic>) {
      contentMap = rawContent;
    } else if (rawContent is Map) {
      contentMap = Map<String, dynamic>.from(rawContent);
    } else if (rawContent is String) {
      contentMap = {'text': rawContent};
    } else {
      contentMap = {};
    }

    return ChatMessage(
      id: _safeInt(json['id']),
      rawId: json['id']?.toString() ?? '',
      senderType: (json['sender_type'] as String?) ?? 'bot',
      messageType: type,
      content: MessageContent.parse(type, contentMap),
      createdAt: _parseDate(json['created_at']),
      senderName: (json['sender_name'] as String?) ?? '',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MessageContent — Base class + Polymorphic factory
// ─────────────────────────────────────────────────────────────────────────────

sealed class MessageContent {
  const MessageContent();

  /// Polymorphic parser — unknown types fallback to TextContent.
  factory MessageContent.parse(String type, Map<String, dynamic> json) {
    switch (type) {
      case 'text':
        return TextContent.fromJson(json);
      case 'quick_replies':
        return QuickReplyContent.fromJson(json);
      case 'card':
        return CardContent.fromJson(json);
      case 'carousel':
        return CarouselContent.fromJson(json);
      case 'image':
        return ImageContent.fromJson(json);
      case 'action_result':
        return ActionResultContent.fromJson(json);
      case 'form':
        return FormContent.fromJson(json);
      case 'rating_request':
        return RatingRequestContent.fromJson(json);
      case 'escalation_notice':
        return EscalationNoticeContent.fromJson(json);
      case 'system_notice':
        return SystemNoticeContent.fromJson(json);
      case 'agent_joined':
        return AgentJoinedContent.fromJson(json);
      default:
        // Defensive fallback — unknown type rendered as plain text
        return TextContent(text: json['text']?.toString() ?? '');
    }
  }
}

// ── Text ────────────────────────────────────────────────────────────────────

class TextContent extends MessageContent {
  final String text;
  const TextContent({required this.text});

  factory TextContent.fromJson(Map<String, dynamic> json) {
    return TextContent(text: (json['text'] as String?) ?? '');
  }
}

// ── Quick Replies ───────────────────────────────────────────────────────────

class QuickReply {
  final String id;
  final String label;
  const QuickReply({required this.id, required this.label});

  factory QuickReply.fromJson(Map<String, dynamic> json) {
    return QuickReply(
      id: json['id']?.toString() ?? '',
      label: (json['label'] as String?) ?? '',
    );
  }
}

class QuickReplyContent extends MessageContent {
  final String text;
  final List<QuickReply> replies;
  const QuickReplyContent({required this.text, required this.replies});

  factory QuickReplyContent.fromJson(Map<String, dynamic> json) {
    final rawReplies = json['replies'] as List<dynamic>? ?? [];
    return QuickReplyContent(
      text: (json['text'] as String?) ?? '',
      replies: rawReplies
          .whereType<Map<String, dynamic>>()
          .map(QuickReply.fromJson)
          .toList(),
    );
  }
}

// ── Card ────────────────────────────────────────────────────────────────────

class CardAction {
  final String label;
  final String action;
  final Map<String, dynamic> params;
  const CardAction({
    required this.label,
    required this.action,
    this.params = const {},
  });

  factory CardAction.fromJson(Map<String, dynamic> json) {
    return CardAction(
      label: (json['label'] as String?) ?? '',
      action: (json['action'] as String?) ?? '',
      params: json['params'] as Map<String, dynamic>? ?? {},
    );
  }
}

class CardContent extends MessageContent {
  final String type; // e.g. order_card, subscription_card
  final Map<String, dynamic> data;
  final List<CardAction> actions;
  const CardContent({
    required this.type,
    required this.data,
    this.actions = const [],
  });

  factory CardContent.fromJson(Map<String, dynamic> json) {
    final rawActions = json['actions'] as List<dynamic>? ?? [];
    return CardContent(
      type: (json['type'] as String?) ?? '',
      data: json['data'] as Map<String, dynamic>? ?? {},
      actions: rawActions
          .whereType<Map<String, dynamic>>()
          .map(CardAction.fromJson)
          .toList(),
    );
  }
}

// ── Carousel ────────────────────────────────────────────────────────────────

class CarouselContent extends MessageContent {
  final List<CardContent> cards;
  const CarouselContent({required this.cards});

  factory CarouselContent.fromJson(Map<String, dynamic> json) {
    final rawCards = json['cards'] as List<dynamic>? ?? [];
    return CarouselContent(
      cards: rawCards
          .whereType<Map<String, dynamic>>()
          .map(CardContent.fromJson)
          .toList(),
    );
  }
}

// ── Image ───────────────────────────────────────────────────────────────────

class ImageContent extends MessageContent {
  final String url;
  final String altText;
  const ImageContent({required this.url, this.altText = ''});

  factory ImageContent.fromJson(Map<String, dynamic> json) {
    return ImageContent(
      url: (json['url'] as String?) ?? '',
      altText: (json['alt_text'] as String?) ?? '',
    );
  }
}

// ── Action Result ───────────────────────────────────────────────────────────

class ActionResultContent extends MessageContent {
  final String action;
  final String text;
  final Map<String, dynamic> details;
  const ActionResultContent({
    required this.action,
    required this.text,
    this.details = const {},
  });

  factory ActionResultContent.fromJson(Map<String, dynamic> json) {
    return ActionResultContent(
      action: (json['action'] as String?) ?? '',
      text: (json['text'] as String?) ?? '',
      details: json['details'] as Map<String, dynamic>? ?? {},
    );
  }
}

// ── Form ────────────────────────────────────────────────────────────────────

class FormField {
  final String name;
  final String label;
  final String type; // text, number, date, select, textarea
  final bool required;
  final List<String> options;
  const FormField({
    required this.name,
    required this.label,
    this.type = 'text',
    this.required = false,
    this.options = const [],
  });

  factory FormField.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List<dynamic>? ?? [];
    return FormField(
      name: (json['name'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'text',
      required: (json['required'] as bool?) ?? false,
      options: rawOptions.map((e) => e.toString()).toList(),
    );
  }
}

class FormContent extends MessageContent {
  final List<FormField> fields;
  final String submitLabel;
  const FormContent({required this.fields, this.submitLabel = 'Submit'});

  factory FormContent.fromJson(Map<String, dynamic> json) {
    final rawFields = json['fields'] as List<dynamic>? ?? [];
    return FormContent(
      fields: rawFields
          .whereType<Map<String, dynamic>>()
          .map(FormField.fromJson)
          .toList(),
      submitLabel: (json['submit_label'] as String?) ?? 'Submit',
    );
  }
}

// ── Rating Request ──────────────────────────────────────────────────────────

class RatingRequestContent extends MessageContent {
  final String text;
  final int max;
  const RatingRequestContent({required this.text, this.max = 5});

  factory RatingRequestContent.fromJson(Map<String, dynamic> json) {
    return RatingRequestContent(
      text: (json['text'] as String?) ?? '',
      max: _safeInt(json['max'], 5),
    );
  }
}

// ── Escalation Notice ───────────────────────────────────────────────────────

class EscalationNoticeContent extends MessageContent {
  final String text;
  final String? ticketId;
  const EscalationNoticeContent({required this.text, this.ticketId});

  factory EscalationNoticeContent.fromJson(Map<String, dynamic> json) {
    return EscalationNoticeContent(
      text: (json['text'] as String?) ?? '',
      ticketId: json['ticket_id']?.toString(),
    );
  }
}

// ── System Notice ───────────────────────────────────────────────────────────

class SystemNoticeContent extends MessageContent {
  final String text;
  const SystemNoticeContent({required this.text});

  factory SystemNoticeContent.fromJson(Map<String, dynamic> json) {
    return SystemNoticeContent(text: (json['text'] as String?) ?? '');
  }
}

// ── Agent Joined ────────────────────────────────────────────────────────────

class AgentJoinedContent extends MessageContent {
  final String text;
  final String agentName;
  final String agentId;
  const AgentJoinedContent({
    required this.text,
    required this.agentName,
    this.agentId = '',
  });

  factory AgentJoinedContent.fromJson(Map<String, dynamic> json) {
    return AgentJoinedContent(
      text: (json['text'] as String?) ?? 'An agent has joined the chat.',
      agentName: (json['agent_name'] as String?) ?? 'Support Agent',
      agentId: (json['agent_id']?.toString()) ?? '',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Ticket Message (for ticket detail / reply thread)
// ─────────────────────────────────────────────────────────────────────────────

class TicketMessage {
  final int id;
  final String messageType; // text, image, system_log, auto_response, etc.
  final String senderRole; // vendor, admin, system
  final String senderName;
  final String content;
  final bool isInternal;
  final List<String> attachments;
  final DateTime createdAt;

  final bool isStaff;

  const TicketMessage({
    required this.id,
    required this.messageType,
    required this.senderRole,
    this.senderName = '',
    required this.content,
    this.isInternal = false,
    this.attachments = const [],
    required this.createdAt,
    this.isStaff = false,
  });

  /// Vendor messages (right side) — vendor sent this
  /// Agent/Admin (left side) — support staff sent this
  bool get isVendor => senderRole == 'vendor' || senderRole == 'customer' || senderRole == 'delivery';
  bool get isAgent => senderRole == 'agent' || senderRole == 'admin';
  bool get isSystem =>
      senderRole == 'system' ||
      messageType == 'system_log' ||
      messageType == 'auto_response';

  factory TicketMessage.fromJson(Map<String, dynamic> json) {
    final rawAttachments = json['attachments'] as List<dynamic>? ?? [];
    return TicketMessage(
      id: _safeInt(json['id']),
      messageType: (json['message_type'] as String?) ?? 'text',
      senderRole: (json['sender_role'] as String?) ?? 'system',
      senderName: (json['sender_name'] as String?) ?? '',
      isStaff: (json['is_staff'] as bool?) ?? false,
      content: (json['message'] as String?) ??
          (json['content'] as String?) ??
          '',
      isInternal: (json['is_internal'] as bool?) ?? false,
      attachments: rawAttachments.map((e) => e.toString()).toList(),
      createdAt: _parseDate(json['created_at']),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Ticket Detail (extended SupportTicket with messages)
// ─────────────────────────────────────────────────────────────────────────────

class TicketDetail {
  final int id;
  final String ticketNumber;
  final String subject;
  final String description;
  final String category;
  final String categoryDisplay;
  final String priority;
  final String priorityDisplay;
  final String status;
  final String statusDisplay;
  final int? relatedOrderId;
  final String? assignedTo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final int? resolutionRating;
  final List<TicketMessage> messages;

  const TicketDetail({
    required this.id,
    required this.ticketNumber,
    required this.subject,
    this.description = '',
    required this.category,
    required this.categoryDisplay,
    required this.priority,
    required this.priorityDisplay,
    required this.status,
    required this.statusDisplay,
    this.relatedOrderId,
    this.assignedTo,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.resolutionRating,
    this.messages = const [],
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

  bool get isClosed => status == 'closed' || status == 'resolved';
  bool get canReply => !isClosed;
  bool get canRate => isClosed && resolutionRating == null;

  factory TicketDetail.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'] as List<dynamic>? ?? [];
    return TicketDetail(
      id: _safeInt(json['id']),
      ticketNumber: (json['ticket_number'] as String?) ?? '',
      subject: (json['subject'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'other',
      categoryDisplay: (json['category_display'] as String?) ?? 'Other',
      priority: (json['priority'] as String?) ?? 'medium',
      priorityDisplay: (json['priority_display'] as String?) ?? 'Medium',
      status: (json['status'] as String?) ?? 'open',
      statusDisplay: (json['status_display'] as String?) ?? 'Open',
      relatedOrderId: _safeIntOrNull(json['related_order_id']),
      assignedTo: json['assigned_to']?.toString(),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      resolvedAt: json['resolved_at'] != null
          ? _parseDate(json['resolved_at'])
          : null,
      resolutionRating: _safeIntOrNull(json['resolution_rating']),
      messages: rawMessages
          .whereType<Map<String, dynamic>>()
          .map(TicketMessage.fromJson)
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Knowledge Base Article (FAQs from backend)
// ─────────────────────────────────────────────────────────────────────────────

class KnowledgeBaseArticle {
  final int id;
  final String title;
  final String content;
  final String category;
  final int viewCount;

  const KnowledgeBaseArticle({
    required this.id,
    required this.title,
    required this.content,
    this.category = '',
    this.viewCount = 0,
  });

  factory KnowledgeBaseArticle.fromJson(Map<String, dynamic> json) {
    return KnowledgeBaseArticle(
      id: _safeInt(json['id']),
      title: (json['title'] as String?) ?? '',
      content: (json['content'] as String?) ?? '',
      category: (json['category'] as String?) ?? '',
      viewCount: _safeInt(json['view_count']),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

DateTime _parseDate(dynamic v) {
  if (v is String && v.isNotEmpty) {
    return DateTime.tryParse(v) ?? DateTime.now();
  }
  return DateTime.now();
}

/// Safely parse any dynamic value to int — handles int, double, and String.
int _safeInt(dynamic v, [int fallback = 0]) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

/// Safely parse any dynamic value to nullable int.
int? _safeIntOrNull(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}
