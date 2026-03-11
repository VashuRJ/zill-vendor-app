import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../models/support_models.dart';
import '../viewmodel/support_viewmodel.dart';

class TicketDetailScreen extends StatefulWidget {
  final int ticketId;
  final String ticketNumber;

  const TicketDetailScreen({
    super.key,
    required this.ticketId,
    required this.ticketNumber,
  });

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
  int _lastMsgCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupportViewModel>().fetchTicketDetail(widget.ticketId);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendReply() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    FocusScope.of(context).unfocus();

    final vm = context.read<SupportViewModel>();
    final ok = await vm.replyToTicket(widget.ticketId, text);
    if (mounted) {
      if (ok) {
        _scrollToBottom();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(vm.ticketError ?? 'Failed to send reply'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          '#${widget.ticketNumber}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0.5,
      ),
      body: Consumer<SupportViewModel>(
        builder: (context, vm, _) {
          if (vm.isTicketLoading && vm.ticketDetail == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (vm.ticketDetailStatus == TicketDetailStatus.error &&
              vm.ticketDetail == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.textHint),
                    const SizedBox(height: 16),
                    Text(
                      vm.ticketError ?? 'Failed to load ticket',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => vm.fetchTicketDetail(widget.ticketId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final ticket = vm.ticketDetail;
          if (ticket == null) return const SizedBox.shrink();

          // Only auto-scroll when message count changes
          if (ticket.messages.length != _lastMsgCount) {
            _lastMsgCount = ticket.messages.length;
            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
          }

          return Column(
            children: [
              // Ticket info header
              _TicketInfoHeader(ticket: ticket, dateFormat: _dateFormat),

              // Messages
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => vm.fetchTicketDetail(widget.ticketId),
                  child: ticket.messages.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 80),
                            Center(
                              child: Text(
                                'No messages yet',
                                style: TextStyle(color: AppColors.textHint),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                          itemCount: ticket.messages.length,
                          itemBuilder: (context, index) {
                            return _MessageBubble(
                              message: ticket.messages[index],
                              dateFormat: _dateFormat,
                            );
                          },
                        ),
                ),
              ),

              // Rate resolution (shows for resolved/closed tickets without rating)
              if (ticket.canRate)
                _RateResolutionBar(
                  ticketId: widget.ticketId,
                ),

              // Reply bar
              if (ticket.canReply) _buildReplyBar(vm),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReplyBar(SupportViewModel vm) {
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
                onSubmitted: (_) => _sendReply(),
                maxLines: 4,
                minLines: 1,
                decoration: const InputDecoration(
                  hintText: 'Type a reply...',
                  hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: AppColors.primary,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: vm.isReplying ? null : _sendReply,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: vm.isReplying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Ticket Info Header
// ═══════════════════════════════════════════════════════════════════════════════

class _TicketInfoHeader extends StatelessWidget {
  final TicketDetail ticket;
  final DateFormat dateFormat;

  const _TicketInfoHeader({required this.ticket, required this.dateFormat});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ticket.subject,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _InfoChip(
                label: ticket.statusDisplay,
                color: _statusColor(ticket.status),
              ),
              _InfoChip(
                label: ticket.priorityDisplay,
                color: _priorityColor(ticket.priority),
              ),
              _InfoChip(
                label: ticket.categoryDisplay,
                color: AppColors.info,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Created ${dateFormat.format(ticket.createdAt)}',
            style: const TextStyle(fontSize: 11, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
      case 'reopened':
        return AppColors.warning;
      case 'assigned':
      case 'in_progress':
        return AppColors.info;
      case 'waiting_customer':
      case 'waiting_vendor':
        return AppColors.orange;
      case 'escalated':
        return AppColors.error;
      case 'resolved':
      case 'closed':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return AppColors.error;
      case 'high':
        return AppColors.orange;
      case 'medium':
        return AppColors.warning;
      case 'low':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Message Bubble
// ═══════════════════════════════════════════════════════════════════════════════

class _MessageBubble extends StatelessWidget {
  final TicketMessage message;
  final DateFormat dateFormat;

  const _MessageBubble({required this.message, required this.dateFormat});

  @override
  Widget build(BuildContext context) {
    // System messages
    if (message.isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.textHint.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            message.content,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    final isVendor = message.isVendor;
    return Align(
      alignment: isVendor ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 8,
          left: isVendor ? 48 : 0,
          right: isVendor ? 0 : 48,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isVendor ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isVendor ? 16 : 4),
            bottomRight: Radius.circular(isVendor ? 4 : 16),
          ),
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
              isVendor ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isVendor && message.senderName.isNotEmpty) ...[
              Text(
                message.senderName,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              message.content,
              style: TextStyle(
                fontSize: 14,
                color: isVendor ? Colors.white : AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              dateFormat.format(message.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: isVendor
                    ? Colors.white.withAlpha(180)
                    : AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Rate Resolution Bar
// ═══════════════════════════════════════════════════════════════════════════════

class _RateResolutionBar extends StatefulWidget {
  final int ticketId;
  const _RateResolutionBar({required this.ticketId});

  @override
  State<_RateResolutionBar> createState() => _RateResolutionBarState();
}

class _RateResolutionBarState extends State<_RateResolutionBar> {
  int _hoveredStar = 0;
  bool _submitted = false;

  Future<void> _submit(int rating) async {
    setState(() => _submitted = true);
    final vm = context.read<SupportViewModel>();
    final ok = await vm.rateTicket(widget.ticketId, rating);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Thanks for your feedback!' : 'Failed to submit rating'),
          backgroundColor: ok ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.borderLight)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'How was this resolution?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return GestureDetector(
                onTap: _submitted
                    ? null
                    : () {
                        setState(() => _hoveredStar = star);
                        _submit(star);
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    star <= _hoveredStar
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: AppColors.ratingStar,
                    size: 36,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
