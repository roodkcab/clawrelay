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
      // With reverse: true, offset 0 = bottom of conversation
      _scrollController.jumpTo(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatAsync = ref.watch(chatProvider(widget.project.id));

    // Scroll to bottom on initial load or when a new message is added
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
        title: Text(widget.project.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear history',
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
        ],
      ),
      body: chatAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (chatState) => Column(
          children: [
            Expanded(
              child: chatState.messages.isEmpty && !chatState.isStreaming
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 48,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                          const SizedBox(height: 12),
                          Text(
                            'Start a conversation',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    )
                  : Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        // reverse: true anchors offset 0 at the BOTTOM.
                        // New content (streaming bubble) lives at offset 0 and
                        // is always immediately visible. MarkdownBody settling in
                        // older messages grows maxScrollExtent upward — the user
                        // at offset 0 is unaffected and never jumps.
                        reverse: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            // With reverse: true the viewport anchors at the END
                            // of the column (last child = bottom of screen).
                            // Keep chronological order so oldest is at top and
                            // newest/streaming is at the bottom.
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Theme.of(context).colorScheme.errorContainer,
                child: Text(
                  chatState.error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ChatInput(
              enabled: !chatState.isStreaming,
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
