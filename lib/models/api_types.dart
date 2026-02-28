import 'dart:convert';
import 'dart:typed_data';

/// An image attached to a user message.
class ImageAttachment {
  final Uint8List bytes;
  final String mimeType;

  const ImageAttachment({required this.bytes, required this.mimeType});

  String get dataUri => 'data:$mimeType;base64,${base64Encode(bytes)}';
}

/// Events emitted by the streaming API.
sealed class StreamEvent {}

class TextDelta extends StreamEvent {
  final String text;
  TextDelta(this.text);
}

class ToolUseStart extends StreamEvent {
  final String name;
  ToolUseStart(this.name);
}

class ThinkingDelta extends StreamEvent {
  final String text;
  ThinkingDelta(this.text);
}

/// Emitted when Claude asks the user a question with options.
class AskUserQuestionEvent extends StreamEvent {
  final List<AskUserQuestion> questions;
  AskUserQuestionEvent(this.questions);
}

class AskUserQuestion {
  final String question;
  final List<AskUserOption> options;
  final bool multiSelect;

  const AskUserQuestion({
    required this.question,
    required this.options,
    this.multiSelect = false,
  });

  factory AskUserQuestion.fromJson(Map<String, dynamic> json) {
    final opts = (json['options'] as List?)
            ?.map((o) => AskUserOption.fromJson(o as Map<String, dynamic>))
            .toList() ??
        [];
    return AskUserQuestion(
      question: json['question'] as String? ?? '',
      options: opts,
      multiSelect: json['multiSelect'] as bool? ?? false,
    );
  }
}

class AskUserOption {
  final String label;
  final String description;

  const AskUserOption({required this.label, this.description = ''});

  factory AskUserOption.fromJson(Map<String, dynamic> json) => AskUserOption(
        label: json['label'] as String? ?? '',
        description: json['description'] as String? ?? '',
      );
}

class ChatMessage {
  final String role;
  final String content;
  final List<ImageAttachment>? images;

  const ChatMessage({required this.role, required this.content, this.images});

  Map<String, dynamic> toJson() {
    if (images == null || images!.isEmpty) {
      return {'role': role, 'content': content};
    }
    // Build multipart content array for messages with images
    final parts = <Map<String, dynamic>>[];
    if (content.isNotEmpty) {
      parts.add({'type': 'text', 'text': content});
    }
    for (final img in images!) {
      parts.add({
        'type': 'image_url',
        'image_url': {'url': img.dataUri},
      });
    }
    return {'role': role, 'content': parts};
  }
}

class ChatCompletionRequest {
  final String model;
  final List<ChatMessage> messages;
  final bool stream;
  final double? temperature;
  final int? maxTokens;
  final String? workingDir;
  final int? maxTurns;
  final String? sessionId;
  final Map<String, String>? envVars;

  const ChatCompletionRequest({
    required this.model,
    required this.messages,
    this.stream = true,
    this.temperature,
    this.maxTokens,
    this.workingDir,
    this.maxTurns,
    this.sessionId,
    this.envVars,
  });

  Map<String, dynamic> toJson() => {
        'model': model,
        'messages': messages.map((m) => m.toJson()).toList(),
        'stream': stream,
        if (temperature != null) 'temperature': temperature,
        if (maxTokens != null) 'max_tokens': maxTokens,
        if (workingDir != null && workingDir!.isNotEmpty) 'working_dir': workingDir,
        if (maxTurns != null) 'max_turns': maxTurns,
        if (sessionId != null && sessionId!.isNotEmpty) 'session_id': sessionId,
        if (envVars != null && envVars!.isNotEmpty) 'env_vars': envVars,
      };
}

class ModelInfo {
  final String id;
  final String ownedBy;

  const ModelInfo({required this.id, this.ownedBy = ''});

  factory ModelInfo.fromJson(Map<String, dynamic> json) => ModelInfo(
        id: json['id'] as String,
        ownedBy: (json['owned_by'] as String?) ?? '',
      );
}

class ModelsResponse {
  final List<ModelInfo> data;

  const ModelsResponse({required this.data});

  factory ModelsResponse.fromJson(Map<String, dynamic> json) => ModelsResponse(
        data: (json['data'] as List)
            .map((e) => ModelInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class StatsResponse {
  final int totalInputTokens;
  final int totalOutputTokens;
  final int totalRequests;

  const StatsResponse({
    required this.totalInputTokens,
    required this.totalOutputTokens,
    required this.totalRequests,
  });

  factory StatsResponse.fromJson(Map<String, dynamic> json) => StatsResponse(
        totalInputTokens: json['total_input_tokens'] as int? ?? 0,
        totalOutputTokens: json['total_output_tokens'] as int? ?? 0,
        totalRequests: json['total_requests'] as int? ?? 0,
      );
}
