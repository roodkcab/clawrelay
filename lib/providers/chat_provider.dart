import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../models/api_types.dart';
import 'database_provider.dart';
import 'projects_provider.dart';
import 'settings_provider.dart';

class ChatState {
  final List<Message> messages;
  final bool isStreaming;
  final String streamingText;
  final List<String> streamingToolCalls;
  final String streamingThinking;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isStreaming = false,
    this.streamingText = '',
    this.streamingToolCalls = const [],
    this.streamingThinking = '',
    this.error,
  });

  ChatState copyWith({
    List<Message>? messages,
    bool? isStreaming,
    String? streamingText,
    List<String>? streamingToolCalls,
    String? streamingThinking,
    String? error,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        isStreaming: isStreaming ?? this.isStreaming,
        streamingText: streamingText ?? this.streamingText,
        streamingToolCalls: streamingToolCalls ?? this.streamingToolCalls,
        streamingThinking: streamingThinking ?? this.streamingThinking,
        error: error,
      );
}

class ChatNotifier extends FamilyAsyncNotifier<ChatState, int> {
  StreamSubscription<StreamEvent>? _streamSub;

  @override
  Future<ChatState> build(int arg) async {
    ref.onDispose(() => _streamSub?.cancel());
    final db = ref.read(databaseProvider);
    final msgs = await db.recentMessagesForProject(arg);
    return ChatState(messages: msgs);
  }

  int get _projectId => arg;
  AppDatabase get _db => ref.read(databaseProvider);

  Future<void> sendMessage(String text, [List<ImageAttachment> images = const []]) async {
    if (text.trim().isEmpty && images.isEmpty) return;

    final currentState = state.valueOrNull ?? const ChatState();
    if (currentState.isStreaming) return;

    // Build DB content: plain text if no images, JSON array if images attached
    final String dbContent;
    if (images.isEmpty) {
      dbContent = text;
    } else {
      final parts = <Map<String, dynamic>>[];
      if (text.isNotEmpty) parts.add({'type': 'text', 'text': text});
      for (final img in images) {
        parts.add({'type': 'image_url', 'image_url': {'url': img.dataUri}});
      }
      dbContent = jsonEncode(parts);
    }

    // Persist user message and get its DB id
    final insertedId = await _db.insertMessage(MessagesCompanion.insert(
      projectId: _projectId,
      role: 'user',
      content: dbContent,
    ));

    // Append to current display list — do NOT reload from DB here.
    // Reloading would apply the 50-message limit and drop the oldest
    // message from the top, shifting all content up and causing a scroll jump.
    final userMsg = Message(
      id: insertedId,
      projectId: _projectId,
      role: 'user',
      content: dbContent,
      createdAt: DateTime.now(),
    );
    state = AsyncValue.data(ChatState(
      messages: [...currentState.messages, userMsg],
      isStreaming: true,
    ));

    // Build API request with full history for context
    final project = await _db.getProject(_projectId);
    final allMsgs = await _db.messagesForProject(_projectId);
    final apiMessages = <ChatMessage>[];

    if (project.systemPrompt.isNotEmpty) {
      apiMessages.add(ChatMessage(role: 'system', content: project.systemPrompt));
    }

    for (final m in allMsgs) {
      // Detect JSON-encoded multipart content (messages with images stored as JSON array)
      String textContent = m.content;
      List<ImageAttachment>? imgs;
      try {
        final decoded = jsonDecode(m.content);
        if (decoded is List) {
          textContent = decoded
              .where((p) => (p as Map)['type'] == 'text')
              .map<String>((p) => (p as Map)['text'] as String? ?? '')
              .join('');
          final imgList = <ImageAttachment>[];
          for (final p in decoded) {
            if ((p as Map)['type'] != 'image_url') continue;
            final url = (p['image_url'] as Map?)?['url'] as String?;
            if (url == null || !url.startsWith('data:')) continue;
            final comma = url.indexOf(',');
            if (comma < 0) continue;
            final header = url.substring(5, comma);
            final mimeEnd = header.indexOf(';');
            final mimeType = mimeEnd >= 0 ? header.substring(0, mimeEnd) : 'image/png';
            try {
              final bytes = base64Decode(url.substring(comma + 1));
              imgList.add(ImageAttachment(bytes: bytes, mimeType: mimeType));
            } catch (_) {}
          }
          if (imgList.isNotEmpty) imgs = imgList;
        }
      } catch (_) {}
      apiMessages.add(ChatMessage(role: m.role, content: textContent, images: imgs));
    }

    final request = ChatCompletionRequest(
      model: project.model,
      messages: apiMessages,
      workingDir: project.workingDirectory.isNotEmpty ? project.workingDirectory : null,
    );

    final api = ref.read(claudeApiProvider);
    var accumulated = '';
    final toolCalls = <String>[];
    var thinkingAccumulated = '';

    try {
      final stream = api.streamChat(request);
      _streamSub = stream.listen(
        (event) {
          final s = state.valueOrNull;
          if (s == null) return;
          if (event is TextDelta) {
            accumulated += event.text;
            state = AsyncValue.data(s.copyWith(streamingText: accumulated));
          } else if (event is ToolUseStart) {
            debugPrint('[PROVIDER] ToolUseStart: ${event.name}');
            if (!toolCalls.contains(event.name)) {
              toolCalls.add(event.name);
            }
            state = AsyncValue.data(
                s.copyWith(streamingToolCalls: List.unmodifiable(toolCalls)));
            debugPrint('[PROVIDER] streamingToolCalls: $toolCalls');
          } else if (event is ThinkingDelta) {
            debugPrint('[PROVIDER] ThinkingDelta len=${event.text.length}');
            thinkingAccumulated += event.text;
            state = AsyncValue.data(s.copyWith(streamingThinking: thinkingAccumulated));
          }
        },
        onDone: () async {
          // Append assistant message to current display list — do NOT reload from DB.
          // Reloading applies the 50-message limit and drops the oldest message from
          // the top, shifting all content up and causing a visible scroll jump.
          final s = state.valueOrNull ?? const ChatState();
          if (accumulated.isNotEmpty) {
            final insertedId = await _db.insertMessage(MessagesCompanion.insert(
              projectId: _projectId,
              role: 'assistant',
              content: accumulated,
            ));
            final assistantMsg = Message(
              id: insertedId,
              projectId: _projectId,
              role: 'assistant',
              content: accumulated,
              createdAt: DateTime.now(),
            );
            state = AsyncValue.data(ChatState(
              messages: [...s.messages, assistantMsg],
            ));
          } else {
            state = AsyncValue.data(ChatState(messages: s.messages));
          }
          // Mark as unread if this project is not the currently focused one
          final selectedId = ref.read(selectedProjectIdProvider);
          if (selectedId != _projectId) {
            final unread = ref.read(unreadProjectIdsProvider);
            ref.read(unreadProjectIdsProvider.notifier).state = {...unread, _projectId};
          }
        },
        onError: (error) async {
          // Save partial response if any, then append to current list
          final s = state.valueOrNull ?? const ChatState();
          if (accumulated.isNotEmpty) {
            final insertedId = await _db.insertMessage(MessagesCompanion.insert(
              projectId: _projectId,
              role: 'assistant',
              content: accumulated,
            ));
            final assistantMsg = Message(
              id: insertedId,
              projectId: _projectId,
              role: 'assistant',
              content: accumulated,
              createdAt: DateTime.now(),
            );
            state = AsyncValue.data(ChatState(
              messages: [...s.messages, assistantMsg],
              error: error.toString(),
            ));
          } else {
            state = AsyncValue.data(ChatState(
              messages: s.messages,
              error: error.toString(),
            ));
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      final s = state.valueOrNull ?? const ChatState();
      state = AsyncValue.data(ChatState(
        messages: s.messages,
        error: e.toString(),
      ));
    }
  }

  void cancelStream() {
    _streamSub?.cancel();
    _streamSub = null;
    final s = state.valueOrNull;
    if (s != null) {
      state = AsyncValue.data(s.copyWith(isStreaming: false, streamingText: ''));
    }
  }

  Future<void> clearHistory() async {
    _streamSub?.cancel();
    await _db.deleteMessagesForProject(_projectId);
    state = const AsyncValue.data(ChatState());
  }
}

final chatProvider =
    AsyncNotifierProvider.family<ChatNotifier, ChatState, int>(
        ChatNotifier.new);
