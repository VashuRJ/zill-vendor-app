import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../models/support_models.dart';
import '../viewmodel/support_viewmodel.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _timeFormat = DateFormat('hh:mm a');
  bool _sessionStarted = false;
  late final SupportViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = context.read<SupportViewModel>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startSession();
    });
  }

  Future<void> _startSession() async {
    final ok = await _vm.startChatSession();
    if (mounted && ok) {
      setState(() => _sessionStarted = true);
    }
  }

  @override
  void dispose() {
    _vm.clearChat();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    FocusScope.of(context).unfocus();
    await _vm.sendMessage(content: text);
  }

  Future<void> _sendQuickReply(QuickReply reply) async {
    await _vm.sendQuickReply(reply.id, reply.label);
  }

  Future<void> _submitRating(int rating) async {
    await _vm.rateSession(rating);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thanks for your feedback!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _endChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Chat'),
        content: const Text('Are you sure you want to end this chat session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End Chat', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    await _vm.endChatSession();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.smart_toy_rounded, size: 18, color: Colors.white),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Zill Support',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                Text(
                  'AI Assistant',
                  style: TextStyle(fontSize: 11, color: AppColors.textHint),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: AppColors.surface,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.error, size: 22),
            onPressed: _endChat,
            tooltip: 'End Chat',
          ),
        ],
      ),
      body: Consumer<SupportViewModel>(
        builder: (context, vm, _) {
          // Starting state
          if (vm.chatStatus == ChatStatus.starting) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text(
                    'Connecting to support...',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          // Error starting
          if (vm.chatStatus == ChatStatus.error && !_sessionStarted) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textHint),
                    const SizedBox(height: 16),
                    Text(
                      vm.chatError ?? 'Failed to connect',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _startSession,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Find last quick-reply index so older ones get disabled
          int lastQuickReplyIdx = -1;
          for (int i = vm.messages.length - 1; i >= 0; i--) {
            if (vm.messages[i].content is QuickReplyContent) {
              lastQuickReplyIdx = i;
              break;
            }
          }

          return Column(
            children: [
              // Error banner
              if (vm.chatError != null && _sessionStarted)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppColors.errorLight,
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          vm.chatError!,
                          style: const TextStyle(fontSize: 12, color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),

              // Messages — reverse: true keeps newest at bottom, no scroll mgmt needed
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  itemCount: vm.messages.length,
                  itemBuilder: (context, index) {
                    // reverse: true renders index 0 at bottom — map to last message
                    final msgIndex = vm.messages.length - 1 - index;
                    return _buildMessage(
                      vm.messages[msgIndex],
                      enableQuickReplies: vm.isChatActive && msgIndex == lastQuickReplyIdx,
                    );
                  },
                ),
              ),

              // Typing indicator
              if (vm.isSending)
                const Padding(
                  padding: EdgeInsets.only(left: 20, bottom: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textHint,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Thinking...',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),

              // Input bar or "Chat ended" footer
              if (vm.isChatActive)
                _buildInputBar(vm)
              else if (vm.activeSession != null)
                _buildChatEndedFooter(vm),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Message bubble dispatcher
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMessage(ChatMessage msg, {bool enableQuickReplies = false}) {
    final content = msg.content;

    return switch (content) {
      TextContent() => _TextBubble(msg: msg, content: content, timeFormat: _timeFormat),
      QuickReplyContent() => _QuickReplyBubble(
          msg: msg,
          content: content,
          timeFormat: _timeFormat,
          onReply: enableQuickReplies ? _sendQuickReply : null,
        ),
      CardContent() => _CardBubble(msg: msg, content: content, timeFormat: _timeFormat),
      CarouselContent() => _CarouselBubble(msg: msg, content: content),
      ImageContent() => _ImageBubble(msg: msg, content: content, timeFormat: _timeFormat),
      ActionResultContent() => _ActionResultBubble(msg: msg, content: content, timeFormat: _timeFormat),
      RatingRequestContent() => _RatingBubble(content: content, onRate: _submitRating),
      EscalationNoticeContent() => _EscalationBubble(content: content),
      SystemNoticeContent() => _SystemNoticeBubble(content: content),
      AgentJoinedContent() => _AgentJoinedBubble(content: content),
      FormContent() => _FormBubble(msg: msg, content: content),
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Input bar
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildChatEndedFooter(SupportViewModel vm) {
    final isEscalated = vm.activeSession?.isEscalated ?? false;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          Icon(
            isEscalated ? Icons.support_agent_rounded : Icons.check_circle_rounded,
            size: 20,
            color: isEscalated ? AppColors.warning : AppColors.success,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isEscalated
                  ? 'Chat escalated to support agent. You\'ll be notified when they respond.'
                  : 'This chat session has ended.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(SupportViewModel vm) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        8,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                maxLines: 4,
                minLines: 1,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: AppColors.primary,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: vm.isSending ? null : _sendMessage,
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Text Bubble
// ═══════════════════════════════════════════════════════════════════════════════

class _TextBubble extends StatelessWidget {
  final ChatMessage msg;
  final TextContent content;
  final DateFormat timeFormat;

  const _TextBubble({
    required this.msg,
    required this.content,
    required this.timeFormat,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = msg.isUser;
    final isAgent = msg.isAgent;

    // Agent: left side, blue tint
    // Bot: left side, white
    // User: right side, primary
    final Color bubbleColor;
    final Color textColor;
    if (isUser) {
      bubbleColor = AppColors.primary;
      textColor = Colors.white;
    } else if (isAgent) {
      bubbleColor = AppColors.info.withAlpha(20);
      textColor = AppColors.textPrimary;
    } else {
      bubbleColor = AppColors.surface;
      textColor = AppColors.textPrimary;
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 8,
          left: isUser ? 48 : 0,
          right: isUser ? 0 : 48,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isAgent ? Border.all(color: AppColors.info.withAlpha(40)) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Agent name header
            if (isAgent && msg.senderName.isNotEmpty) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.support_agent_rounded, size: 13, color: AppColors.info),
                  const SizedBox(width: 4),
                  Text(
                    msg.senderName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.info,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Text(
              content.text,
              style: TextStyle(
                fontSize: 14,
                color: textColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeFormat.format(msg.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: isUser ? Colors.white.withAlpha(180) : AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Quick Reply Bubble
// ═══════════════════════════════════════════════════════════════════════════════

class _QuickReplyBubble extends StatelessWidget {
  final ChatMessage msg;
  final QuickReplyContent content;
  final DateFormat timeFormat;
  final Function(QuickReply)? onReply;

  const _QuickReplyBubble({
    required this.msg,
    required this.content,
    required this.timeFormat,
    this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TextBubble(
          msg: msg,
          content: TextContent(text: content.text),
          timeFormat: timeFormat,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: content.replies.map((reply) {
              final enabled = onReply != null;
              return ActionChip(
                label: Text(
                  reply.label,
                  style: TextStyle(
                    fontSize: 13,
                    color: enabled ? AppColors.primary : AppColors.textHint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: enabled
                    ? AppColors.primary.withAlpha(15)
                    : AppColors.background,
                side: BorderSide(
                  color: enabled ? AppColors.primary : AppColors.borderLight,
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onPressed: enabled ? () => onReply!(reply) : null,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Card Bubble
// ═══════════════════════════════════════════════════════════════════════════════

class _CardBubble extends StatelessWidget {
  final ChatMessage msg;
  final CardContent content;
  final DateFormat timeFormat;

  const _CardBubble({
    required this.msg,
    required this.content,
    required this.timeFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, right: 32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _cardIcon(content.type),
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _cardTitle(content.type),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...content.data.entries
                  .where((e) => e.value != null && e.value is! Map && e.value is! List)
                  .map((e) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatKey(e.key),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          '${e.value}',
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (content.actions.isNotEmpty) ...[
                const Divider(height: 16, color: AppColors.borderLight),
                Wrap(
                  spacing: 8,
                  children: content.actions.map((a) {
                    return TextButton(
                      onPressed: () {
                        // Send action as text — backend only handles text/quick_reply/form_submit/rating
                        context.read<SupportViewModel>().sendMessage(
                              content: a.action.isNotEmpty ? a.action : a.label,
                            );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text(a.label),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _cardIcon(String type) {
    if (type.contains('order')) return Icons.receipt_long_rounded;
    if (type.contains('subscription')) return Icons.card_membership_rounded;
    return Icons.article_rounded;
  }

  String _cardTitle(String type) {
    if (type.contains('order')) return 'Order Details';
    if (type.contains('subscription')) return 'Subscription';
    return 'Details';
  }

  String _formatKey(String key) {
    return key.replaceAll('_', ' ').split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Carousel Bubble
// ═══════════════════════════════════════════════════════════════════════════════

class _CarouselBubble extends StatelessWidget {
  final ChatMessage msg;
  final CarouselContent content;

  const _CarouselBubble({required this.msg, required this.content});

  @override
  Widget build(BuildContext context) {
    if (content.cards.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: content.cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return SizedBox(
            width: 220,
            child: _CardBubble(
              msg: msg,
              content: content.cards[index],
              timeFormat: DateFormat('hh:mm a'),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Image Bubble
// ═══════════════════════════════════════════════════════════════════════════════

class _ImageBubble extends StatelessWidget {
  final ChatMessage msg;
  final ImageContent content;
  final DateFormat timeFormat;

  const _ImageBubble({
    required this.msg,
    required this.content,
    required this.timeFormat,
  });

  @override
  Widget build(BuildContext context) {
    // Guard against empty URL — Image.network('') throws
    if (content.url.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8, right: 48),
          width: 200,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(Icons.broken_image, color: AppColors.textHint),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, right: 48),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 250),
            child: Image.network(
              content.url,
              width: 200,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 200,
                height: 100,
                color: AppColors.background,
                child: const Icon(Icons.broken_image, color: AppColors.textHint),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Action Result Bubble
// ═══════════════════════════════════════════════════════════════════════════════

class _ActionResultBubble extends StatelessWidget {
  final ChatMessage msg;
  final ActionResultContent content;
  final DateFormat timeFormat;

  const _ActionResultBubble({
    required this.msg,
    required this.content,
    required this.timeFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, right: 32),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.successLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success.withAlpha(40)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                content.text,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Rating Bubble
// ═══════════════════════════════════════════════════════════════════════════════

class _RatingBubble extends StatefulWidget {
  final RatingRequestContent content;
  final Function(int) onRate;

  const _RatingBubble({required this.content, required this.onRate});

  @override
  State<_RatingBubble> createState() => _RatingBubbleState();
}

class _RatingBubbleState extends State<_RatingBubble> {
  int _selectedRating = 0;

  @override
  Widget build(BuildContext context) {
    // Check ViewModel flag — prevents re-rating after widget rebuild
    final alreadyRated = context.watch<SupportViewModel>().hasRatedSession;
    final canRate = _selectedRating == 0 && !alreadyRated;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, right: 32),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.content.text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(widget.content.max, (i) {
                final star = i + 1;
                return GestureDetector(
                  onTap: canRate
                      ? () {
                          setState(() => _selectedRating = star);
                          widget.onRate(star);
                        }
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      star <= _selectedRating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: AppColors.ratingStar,
                      size: 32,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Escalation Notice Bubble
// ═══════════════════════════════════════════════════════════════════════════════

class _EscalationBubble extends StatelessWidget {
  final EscalationNoticeContent content;
  const _EscalationBubble({required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(Icons.support_agent_rounded, color: AppColors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              content.text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  System Notice Bubble
// ═══════════════════════════════════════════════════════════════════════════════

class _SystemNoticeBubble extends StatelessWidget {
  final SystemNoticeContent content;
  const _SystemNoticeBubble({required this.content});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.textHint.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          content.text,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Agent Joined Bubble (center-aligned system notice)
// ═══════════════════════════════════════════════════════════════════════════════

class _AgentJoinedBubble extends StatelessWidget {
  final AgentJoinedContent content;
  const _AgentJoinedBubble({required this.content});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.info.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.info.withAlpha(40)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.support_agent_rounded, size: 16, color: AppColors.info),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${content.agentName} joined the chat',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.info,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Form Bubble (simplified — renders fields as text prompts)
// ═══════════════════════════════════════════════════════════════════════════════

class _FormBubble extends StatelessWidget {
  final ChatMessage msg;
  final FormContent content;
  const _FormBubble({required this.msg, required this.content});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, right: 32),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.edit_note_rounded, size: 18, color: AppColors.primary),
                SizedBox(width: 6),
                Text(
                  'Please fill in:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...content.fields.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• ${f.label}${f.required ? ' *' : ''}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )),
            const SizedBox(height: 4),
            const Text(
              'Please type your responses in the chat.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textHint,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
