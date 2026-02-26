import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/api_types.dart';

class ClaudeApi {
  final String baseUrl;

  ClaudeApi({required this.baseUrl});

  String get _cleanBase => baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

  /// Streams chat completion events (text deltas and tool-use starts).
  Stream<StreamEvent> streamChat(ChatCompletionRequest request) async* {
    final client = http.Client();
    // Track which tool IDs we've already emitted to avoid duplicates.
    final seenToolIds = <String>{};
    try {
      final uri = Uri.parse('$_cleanBase/v1/chat/completions');
      final httpRequest = http.Request('POST', uri);
      httpRequest.headers['Content-Type'] = 'application/json';
      httpRequest.body = jsonEncode(request.toJson());

      final response = await client.send(httpRequest);

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw ApiException(response.statusCode, body);
      }

      final lineStream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lineStream) {
        // Skip keepalive / comment lines
        if (line.startsWith(':')) continue;

        // Skip empty lines (SSE delimiter)
        if (line.isEmpty) continue;

        // SSE data line
        if (line.startsWith('data: ')) {
          final data = line.substring(6).trim();

          // End of stream
          if (data == '[DONE]') {
            debugPrint('[SSE] received DONE');
            return;
          }

          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final choices = json['choices'] as List?;
            if (choices != null && choices.isNotEmpty) {
              final delta = choices[0]['delta'] as Map<String, dynamic>?;
              if (delta != null) {
                final hasThinking = delta.containsKey('thinking') && delta['thinking'] != null;
                final hasToolCalls = delta.containsKey('tool_calls') && delta['tool_calls'] != null;
                if (hasThinking || hasToolCalls) {
                  debugPrint('[SSE] delta keys=${delta.keys.toList()} hasThinking=$hasThinking hasToolCalls=$hasToolCalls');
                }
                // Text content
                final content = delta['content'] as String?;
                if (content != null && content.isNotEmpty) {
                  yield TextDelta(content);
                }

                // Thinking content (custom extension field)
                final thinking = delta['thinking'] as String?;
                if (thinking != null && thinking.isNotEmpty) {
                  debugPrint('[SSE] ThinkingDelta len=${thinking.length}');
                  yield ThinkingDelta(thinking);
                }

                // Tool calls (OpenAI format: delta.tool_calls[])
                final toolCalls = delta['tool_calls'] as List?;
                if (toolCalls != null) {
                  debugPrint('[SSE] tool_calls count=${toolCalls.length}');
                  for (final tc in toolCalls) {
                    final tcMap = tc as Map<String, dynamic>?;
                    if (tcMap == null) continue;
                    final id = tcMap['id'] as String?;
                    final name =
                        (tcMap['function'] as Map<String, dynamic>?)?['name']
                            as String?;
                    debugPrint('[SSE] tool id=$id name=$name');
                    if (name != null && name.isNotEmpty) {
                      final key = id ?? name;
                      if (seenToolIds.add(key)) {
                        debugPrint('[SSE] yield ToolUseStart($name)');
                        yield ToolUseStart(name);
                      }
                    }
                  }
                }
              }
            }
          } catch (e, st) {
            debugPrint('[SSE] parse error: $e\n$st');
          }
        }
      }
    } finally {
      client.close();
    }
  }

  /// Fetches available models.
  Future<ModelsResponse> fetchModels() async {
    final response =
        await http.get(Uri.parse('$_cleanBase/v1/models'));
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    return ModelsResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Fetches usage stats.
  Future<StatsResponse> fetchStats() async {
    final response =
        await http.get(Uri.parse('$_cleanBase/v1/stats'));
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    return StatsResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String body;

  ApiException(this.statusCode, this.body);

  @override
  String toString() => 'ApiException($statusCode): $body';
}
