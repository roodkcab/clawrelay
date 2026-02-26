import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

class MessageBubble extends StatelessWidget {
  final String role;
  final String content;
  final bool isStreaming;
  final List<String> toolCalls;
  final String streamingThinking;

  const MessageBubble({
    super.key,
    required this.role,
    required this.content,
    this.isStreaming = false,
    this.toolCalls = const [],
    this.streamingThinking = '',
  });

  bool get _isUser => role == 'user';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Align(
      alignment: _isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _isUser
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: _isUser ? const Radius.circular(4) : null,
            bottomLeft: !_isUser ? const Radius.circular(4) : null,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.smart_toy_outlined,
                        size: 14, color: colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Claude',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isStreaming) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            if (!_isUser && streamingThinking.isNotEmpty)
              _ThinkingPreview(thinking: streamingThinking),
            if (_isUser)
              _UserContent(content: content, colorScheme: colorScheme, theme: theme)
            else if (isStreaming)
              SelectableText(
                content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              )
            else
              MarkdownBody(
                data: content,
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                  code: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    backgroundColor: colorScheme.surfaceContainerLow,
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                builders: {
                  'pre': _CodeBlockBuilder(colorScheme: colorScheme),
                },
              ),
            if (toolCalls.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: toolCalls.map((name) {
                    return Chip(
                      avatar: Icon(Icons.build_outlined,
                          size: 12, color: colorScheme.onSecondaryContainer),
                      label: Text(
                        name,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                      backgroundColor: colorScheme.secondaryContainer,
                      padding: EdgeInsets.zero,
                      labelPadding:
                          const EdgeInsets.symmetric(horizontal: 6),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      side: BorderSide.none,
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Renders user message content: plain text OR multipart JSON (text + images).
class _UserContent extends StatelessWidget {
  final String content;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _UserContent({
    required this.content,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    // Try to parse as a JSON content array (messages with attached images)
    try {
      final decoded = jsonDecode(content);
      if (decoded is List) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final part in decoded)
              if ((part as Map)['type'] == 'text' && (part['text'] as String?)?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: SelectableText(
                    part['text'] as String,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                )
              else if (part['type'] == 'image_url')
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _InlineImage(dataUri: (part['image_url'] as Map)['url'] as String),
                ),
          ],
        );
      }
    } catch (_) {}

    // Plain text fallback
    return SelectableText(
      content,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: colorScheme.onPrimaryContainer,
      ),
    );
  }
}

/// Decodes a data URI and displays the image.
class _InlineImage extends StatelessWidget {
  final String dataUri;

  const _InlineImage({required this.dataUri});

  Uint8List? _decodeBytes() {
    try {
      final comma = dataUri.indexOf(',');
      if (comma < 0) return null;
      return base64Decode(dataUri.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeBytes();
    if (bytes == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320, maxHeight: 320),
        child: Image.memory(bytes, fit: BoxFit.contain),
      ),
    );
  }
}

class _ThinkingPreview extends StatefulWidget {
  final String thinking;
  const _ThinkingPreview({required this.thinking});

  @override
  State<_ThinkingPreview> createState() => _ThinkingPreviewState();
}

class _ThinkingPreviewState extends State<_ThinkingPreview> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Show last ~120 chars as collapsed preview
    final preview = widget.thinking.length > 120
        ? '...${widget.thinking.substring(widget.thinking.length - 120)}'
        : widget.thinking;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.outlineVariant,
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.psychology_outlined,
                      size: 12, color: colorScheme.tertiary),
                  const SizedBox(width: 4),
                  Text(
                    'Thinking',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.tertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SelectableText(
                _expanded ? widget.thinking : preview,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodeBlockBuilder extends MarkdownElementBuilder {
  final ColorScheme colorScheme;

  _CodeBlockBuilder({required this.colorScheme});

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final code = element.textContent;
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            code,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton(
            icon: const Icon(Icons.copy, size: 16),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied to clipboard'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            tooltip: 'Copy',
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(4),
              minimumSize: const Size(24, 24),
            ),
          ),
        ),
      ],
    );
  }
}
