import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../models/api_types.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final Project project;
  final bool showBackButton;

  const ChatScreen({
    super.key,
    required this.project,
    this.showBackButton = false,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatAsync = ref.watch(chatProvider(widget.project.id));
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    ref.listen(chatProvider(widget.project.id), (prev, next) {
      if (prev?.isLoading == true && next.hasValue) {
        _scrollToBottom();
        return;
      }
      final prevLen = prev?.valueOrNull?.messages.length ?? 0;
      final nextLen = next.valueOrNull?.messages.length ?? 0;
      if (nextLen != prevLen) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.showBackButton,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.project.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(
            height: 0.5,
            color: cs.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_sweep_outlined, size: 20, color: cs.onSurfaceVariant),
            tooltip: 'Clear history',
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(8),
              minimumSize: const Size(36, 36),
            ),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear history?'),
                  content: const Text(
                      'This will delete all messages for this project.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                ref
                    .read(chatProvider(widget.project.id).notifier)
                    .clearHistory();
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: chatAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (chatState) => Column(
          children: [
            Expanded(
              child: chatState.messages.isEmpty && !chatState.isStreaming
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 24,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Start a conversation',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Scrollbar(
                      controller: _scrollController,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            for (final msg in chatState.messages)
                              MessageBubble(
                                key: ValueKey(msg.id),
                                role: msg.role,
                                content: msg.content,
                              ),
                            if (chatState.isStreaming)
                              MessageBubble(
                                key: const ValueKey('streaming'),
                                role: 'assistant',
                                content: chatState.streamingText.isEmpty
                                    ? '...'
                                    : chatState.streamingText,
                                isStreaming: true,
                                toolCalls: chatState.streamingToolCalls,
                                streamingThinking: chatState.streamingThinking,
                              ),
                          ],
                        ),
                      ),
                    ),
            ),
            if (chatState.error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: cs.error.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 16, color: cs.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        chatState.error!,
                        style: TextStyle(
                          color: cs.onErrorContainer,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (chatState.pendingQuestions != null &&
                chatState.pendingQuestions!.isNotEmpty)
              _AskUserQuestionPanel(
                questions: chatState.pendingQuestions!,
                onAnswer: (answer) {
                  ref
                      .read(chatProvider(widget.project.id).notifier)
                      .answerQuestion(answer);
                },
              ),
            ChatInput(
              enabled: !chatState.isStreaming &&
                  (chatState.pendingQuestions == null ||
                      chatState.pendingQuestions!.isEmpty),
              isStreaming: chatState.isStreaming,
              onStop: () => ref
                  .read(chatProvider(widget.project.id).notifier)
                  .cancelStream(),
              onSend: (text, images) {
                ref
                    .read(chatProvider(widget.project.id).notifier)
                    .sendMessage(text, images);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AskUserQuestionPanel extends StatefulWidget {
  final List<AskUserQuestion> questions;
  final ValueChanged<String> onAnswer;

  const _AskUserQuestionPanel({
    required this.questions,
    required this.onAnswer,
  });

  @override
  State<_AskUserQuestionPanel> createState() => _AskUserQuestionPanelState();
}

class _AskUserQuestionPanelState extends State<_AskUserQuestionPanel> {
  final _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final q in widget.questions) ...[
            Row(
              children: [
                Icon(Icons.help_outline_rounded, size: 16, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    q.question,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final opt in q.options)
                  Tooltip(
                    message: opt.description,
                    waitDuration: const Duration(milliseconds: 400),
                    child: OutlinedButton(
                      onPressed: () => widget.onAnswer(opt.label),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        side: BorderSide(
                          color: cs.outline.withValues(alpha: 0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        opt.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          // Free text input for custom answer
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customController,
                  style: theme.textTheme.bodySmall,
                  decoration: InputDecoration(
                    hintText: 'Or type a custom answer...',
                    hintStyle: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: cs.outline.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  onSubmitted: (text) {
                    if (text.trim().isNotEmpty) {
                      widget.onAnswer(text.trim());
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.send_rounded, size: 18, color: cs.primary),
                onPressed: () {
                  final text = _customController.text.trim();
                  if (text.isNotEmpty) {
                    widget.onAnswer(text);
                  }
                },
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(36, 36),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
