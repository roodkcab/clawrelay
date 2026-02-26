import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/api_types.dart';

class ChatInput extends StatefulWidget {
  final void Function(String text, List<ImageAttachment> images) onSend;
  final bool enabled;
  final bool isStreaming;
  final VoidCallback? onStop;

  const ChatInput({
    super.key,
    required this.onSend,
    this.enabled = true,
    this.isStreaming = false,
    this.onStop,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final List<ImageAttachment> _pendingImages = [];
  bool _isDragOver = false;

  @override
  void initState() {
    super.initState();
    _focusNode.onKeyEvent = (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (event.logicalKey == LogicalKeyboardKey.keyV &&
          HardwareKeyboard.instance.isControlPressed) {
        _pasteImageFromClipboard();
        return KeyEventResult.ignored;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter &&
          !HardwareKeyboard.instance.isShiftPressed) {
        _submit();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
  }

  void _submit() {
    final text = _controller.text.trim();
    if ((text.isEmpty && _pendingImages.isEmpty) || !widget.enabled) return;
    widget.onSend(text, List.unmodifiable(_pendingImages));
    _controller.value = TextEditingValue.empty;
    setState(() => _pendingImages.clear());
    _focusNode.requestFocus();
  }

  Future<void> _pasteImageFromClipboard() async {
    for (final args in [
      ['xclip', '-selection', 'clipboard', '-t', 'image/png', '-o'],
      ['wl-paste', '--type', 'image/png'],
    ]) {
      try {
        final process = await Process.start(args[0], args.sublist(1));
        final chunks = <int>[];
        await for (final chunk in process.stdout) {
          chunks.addAll(chunk);
        }
        final exitCode = await process.exitCode;
        if (exitCode == 0 && chunks.isNotEmpty) {
          if (mounted) {
            setState(() => _pendingImages.add(
                  ImageAttachment(
                      bytes: Uint8List.fromList(chunks), mimeType: 'image/png'),
                ));
          }
          return;
        }
      } catch (_) {}
    }
  }

  Future<Uint8List?> _captureScreenRegion() async {
    final path =
        '/tmp/clawrelay_shot_${DateTime.now().millisecondsSinceEpoch}.png';

    Future<Uint8List?> tryFile(List<String> cmd) async {
      try {
        final r = await Process.run(cmd[0], cmd.sublist(1));
        if (r.exitCode == 0) {
          final f = File(path);
          if (await f.exists()) {
            final bytes = await f.readAsBytes();
            await f.delete();
            return bytes;
          }
        }
      } catch (_) {}
      return null;
    }

    if (Platform.isLinux) {
      try {
        final p = await Process.start('flameshot', ['gui', '--raw']);
        final chunks = <int>[];
        await for (final c in p.stdout) {
          chunks.addAll(c);
        }
        if (await p.exitCode == 0 && chunks.isNotEmpty) {
          return Uint8List.fromList(chunks);
        }
      } catch (_) {}
      return await tryFile(['maim', '-s', path]) ??
          await tryFile(['scrot', '-s', path]);
    } else if (Platform.isMacOS) {
      return await tryFile(['screencapture', '-i', path]);
    } else if (Platform.isWindows) {
      final winPath = path.replaceAll('/', '\\');
      return await tryFile([
        'powershell',
        '-NoProfile',
        '-Command',
        'Add-Type -Assembly System.Windows.Forms,System.Drawing;'
            r'$vb=[System.Windows.Forms.SystemInformation]::VirtualScreen;'
            r'$bmp=New-Object System.Drawing.Bitmap($vb.Width,$vb.Height);'
            r'$g=[System.Drawing.Graphics]::FromImage($bmp);'
            r'$g.CopyFromScreen($vb.Location,[System.Drawing.Point]::Empty,$vb.Size);'
            '\$bmp.Save("$winPath");'
            r'$g.Dispose();$bmp.Dispose()',
      ]);
    }
    return null;
  }

  Future<void> _takeScreenshot() async {
    if (!mounted) return;
    final bytes = await _captureScreenRegion();
    if (bytes == null || !mounted) return;
    setState(() => _pendingImages.add(
          ImageAttachment(bytes: bytes, mimeType: 'image/png'),
        ));
  }

  Future<void> _pickImageFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null || !mounted) return;
    for (final f in result.files) {
      if (f.path == null) continue;
      final bytes = await File(f.path!).readAsBytes();
      final ext = (f.extension ?? 'png').toLowerCase();
      final mime = ext == 'jpg' || ext == 'jpeg'
          ? 'image/jpeg'
          : ext == 'gif'
              ? 'image/gif'
              : ext == 'webp'
                  ? 'image/webp'
                  : 'image/png';
      if (mounted) {
        setState(
            () => _pendingImages.add(ImageAttachment(bytes: bytes, mimeType: mime)));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragOver = true),
      onDragExited: (_) => setState(() => _isDragOver = false),
      onDragDone: (details) async {
        setState(() => _isDragOver = false);
        for (final xfile in details.files) {
          final path = xfile.path;
          final ext = path.split('.').last.toLowerCase();
          if (!['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(ext)) continue;
          final bytes = await File(path).readAsBytes();
          final mime = ext == 'jpg' || ext == 'jpeg'
              ? 'image/jpeg'
              : ext == 'gif'
                  ? 'image/gif'
                  : ext == 'webp'
                      ? 'image/webp'
                      : 'image/png';
          if (mounted) {
            setState(() =>
                _pendingImages.add(ImageAttachment(bytes: bytes, mimeType: mime)));
          }
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: SafeArea(
          top: false,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isDragOver
                    ? cs.primary
                    : cs.outlineVariant.withValues(alpha: 0.6),
                width: _isDragOver ? 1.5 : 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Text area ────────────────────────────────────────
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  maxLines: 8,
                  minLines: 2,
                  textInputAction: TextInputAction.newline,
                  enabled: widget.enabled,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  decoration: InputDecoration(
                    hintText: 'Message Claude...',
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                  ),
                ),

                // ── Image thumbnail strip ─────────────────────────────
                if (_pendingImages.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                    child: SizedBox(
                      height: 60,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _pendingImages.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final img = _pendingImages[index];
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  img.bytes,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: -4,
                                right: -4,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () => setState(
                                        () => _pendingImages.removeAt(index)),
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: cs.error,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: cs.surfaceContainerLow,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        size: 9,
                                        color: cs.onError,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                // ── Bottom toolbar row ────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                  child: Row(
                    children: [
                      _ToolbarButton(
                        icon: Icons.attach_file_rounded,
                        tooltip: 'Attach image',
                        onPressed: widget.enabled ? _pickImageFiles : null,
                      ),
                      _ToolbarButton(
                        icon: Icons.screenshot_monitor_outlined,
                        tooltip: 'Take screenshot',
                        onPressed: widget.enabled ? _takeScreenshot : null,
                      ),
                      const Spacer(),
                      if (widget.isStreaming)
                        _ActionButton(
                          icon: Icons.stop_rounded,
                          tooltip: 'Stop',
                          onPressed: widget.onStop,
                          color: cs.error,
                        )
                      else
                        _ActionButton(
                          icon: Icons.arrow_upward_rounded,
                          tooltip: 'Send',
                          onPressed: widget.enabled ? _submit : null,
                          color: cs.primary,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      tooltip: tooltip,
      iconSize: 18,
      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
      disabledColor: cs.onSurfaceVariant.withValues(alpha: 0.2),
      style: IconButton.styleFrom(
        padding: const EdgeInsets.all(8),
        minimumSize: const Size(34, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color color;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isEnabled ? color : color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              size: 17,
              color: isEnabled
                  ? Colors.white
                  : color.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}
