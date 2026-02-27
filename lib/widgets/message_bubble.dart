import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

const _monoFont = 'JetBrains Mono'; // Falls back to system monospace

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
    final cs = theme.colorScheme;

    final bubbleColor = _isUser
        ? cs.primary.withValues(alpha: 0.12)
        : cs.surfaceContainerLow;

    final bubbleBorder = _isUser
        ? Border.all(color: cs.primary.withValues(alpha: 0.18), width: 0.5)
        : Border.all(color: cs.outlineVariant.withValues(alpha: 0.5), width: 0.5);

    return Align(
      alignment: _isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: EdgeInsets.only(
          left: _isUser ? 48 : 12,
          right: _isUser ? 12 : 48,
          top: 3,
          bottom: 3,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(14).copyWith(
            bottomRight: _isUser ? const Radius.circular(4) : null,
            bottomLeft: !_isUser ? const Radius.circular(4) : null,
          ),
          border: bubbleBorder,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Icon(Icons.auto_awesome, size: 11, color: cs.primary),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Claude',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (isStreaming) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: cs.primary.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            if (!_isUser && streamingThinking.isNotEmpty)
              _ThinkingPreview(thinking: streamingThinking),
            if (_isUser)
              _UserContent(content: content, colorScheme: cs, theme: theme)
            else if (isStreaming)
              SelectableText(
                content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface,
                  height: 1.5,
                ),
              )
            else
              MarkdownBody(
                data: content,
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                  p: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface,
                    height: 1.55,
                  ),
                  code: TextStyle(fontFamily: _monoFont,
                    fontSize: 12.5,
                    color: cs.primary,
                    backgroundColor: cs.primary.withValues(alpha: 0.08),
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                      width: 0.5,
                    ),
                  ),
                  blockquoteDecoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: cs.primary.withValues(alpha: 0.4), width: 3),
                    ),
                  ),
                  blockquotePadding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
                  h1: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                  h2: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                  h3: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                  listBullet: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                builders: {
                  'pre': _CodeBlockBuilder(colorScheme: cs, theme: theme),
                },
              ),
            if (toolCalls.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: toolCalls.map((name) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.5),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.build_outlined,
                              size: 11, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            name,
                            style: TextStyle(fontFamily: _monoFont,
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
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
    try {
      final decoded = jsonDecode(content);
      if (decoded is List) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final part in decoded)
              if ((part as Map)['type'] == 'text' &&
                  (part['text'] as String?)?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: SelectableText(
                    part['text'] as String,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      height: 1.5,
                    ),
                  ),
                )
              else if (part['type'] == 'image_url')
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _InlineImage(
                      dataUri: (part['image_url'] as Map)['url'] as String),
                ),
          ],
        );
      }
    } catch (_) {}

    return SelectableText(
      content,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurface,
        height: 1.5,
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
      borderRadius: BorderRadius.circular(10),
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
    final cs = theme.colorScheme;
    final preview = widget.thinking.length > 120
        ? '...${widget.thinking.substring(widget.thinking.length - 120)}'
        : widget.thinking;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: cs.tertiary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: cs.tertiary.withValues(alpha: 0.15),
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.psychology_outlined,
                      size: 13, color: cs.tertiary),
                  const SizedBox(width: 5),
                  Text(
                    'Thinking',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.tertiary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      size: 14,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              AnimatedCrossFade(
                firstChild: SelectableText(
                  preview,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                    height: 1.45,
                    fontSize: 12,
                  ),
                ),
                secondChild: SelectableText(
                  widget.thinking,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                    height: 1.45,
                    fontSize: 12,
                  ),
                ),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
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
  final ThemeData theme;

  _CodeBlockBuilder({required this.colorScheme, required this.theme});

  // flutter_markdown bug workaround: when a custom `pre` builder returns null
  // from visitText, the builder leaves a stale InlineElement in _inlines that
  // never gets flushed, triggering `assert(_inlines.isEmpty)` when the document
  // ends with a code block.  Returning a zero-size widget makes _inlines
  // non-empty so _addAnonymousBlockIfNeeded properly clears the stale entry.
  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) =>
      const SizedBox.shrink();

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final code = element.textContent;
    final cs = colorScheme;

    // Try to extract language from class attribute
    String? language;
    if (element.children?.isNotEmpty == true) {
      final firstChild = element.children!.first;
      if (firstChild is md.Element && firstChild.attributes.containsKey('class')) {
        language = firstChild.attributes['class']?.replaceFirst('language-', '');
      }
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header bar with language label and copy button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: cs.outlineVariant.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                if (language != null && language.isNotEmpty)
                  Text(
                    language,
                    style: TextStyle(fontFamily: _monoFont,
                      fontSize: 11,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const Spacer(),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copied to clipboard'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_rounded, size: 13, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                        const SizedBox(width: 4),
                        Text(
                          'Copy',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Code content
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              code,
              style: TextStyle(fontFamily: _monoFont,
                fontSize: 12.5,
                color: cs.onSurface,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
