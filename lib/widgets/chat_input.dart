import 'dart:io';
import 'dart:typed_data';

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
      // Ctrl+V: attempt image paste (async), let text paste through normally
      if (event.logicalKey == LogicalKeyboardKey.keyV &&
          HardwareKeyboard.instance.isControlPressed) {
        _pasteImageFromClipboard();
        return KeyEventResult.ignored;
      }
      // Enter (without Shift) sends the message
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

  /// Try to paste an image from the clipboard using xclip (X11) or wl-paste (Wayland).
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

  /// Interactive screen region capture using native system tools.
  /// These tools open their own fullscreen selection UI spanning all monitors.
  /// Returns PNG bytes of the selected region, or null if cancelled/unavailable.
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
      // flameshot: outputs raw PNG bytes to stdout
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
      // maim -s: interactive rubber-band selection, all monitors
      return await tryFile(['maim', '-s', path]) ??
          // scrot -s: fallback
          await tryFile(['scrot', '-s', path]);
    } else if (Platform.isMacOS) {
      // -i: interactive crosshair, works across all displays
      return await tryFile(['screencapture', '-i', path]);
    } else if (Platform.isWindows) {
      // Windows: capture virtual screen (all monitors) then use Snipping Tool via clipboard
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
    // Native tools open their own fullscreen selection UI across all monitors.
    // They return only the selected region — no overlay or cropping needed.
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
        setState(() => _pendingImages.add(ImageAttachment(bytes: bytes, mimeType: mime)));
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
    final cardColor = theme.colorScheme.surfaceContainerHighest;
    final borderColor = _isDragOver
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;

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
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: SafeArea(
          top: false,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: _isDragOver
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.18)
                  : cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderColor,
                width: _isDragOver ? 1.5 : 0.8,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Top toolbar row ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: Row(
                    children: [
                      // Attach button (flat)
                      IconButton(
                        onPressed: widget.enabled ? _pickImageFiles : null,
                        icon: const Icon(Icons.attach_file),
                        tooltip: 'Attach image',
                        iconSize: 20,
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(6),
                          minimumSize: const Size(32, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      // Screenshot button (flat)
                      IconButton(
                        onPressed: widget.enabled ? _takeScreenshot : null,
                        icon: const Icon(Icons.screenshot_monitor),
                        tooltip: 'Take screenshot',
                        iconSize: 20,
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(6),
                          minimumSize: const Size(32, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const Spacer(),
                      // Stop / Send button (flat)
                      if (widget.isStreaming)
                        IconButton(
                          onPressed: widget.onStop,
                          icon: const Icon(Icons.stop_circle_outlined),
                          tooltip: 'Stop',
                          iconSize: 20,
                          color: theme.colorScheme.error,
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(6),
                            minimumSize: const Size(32, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        )
                      else
                        IconButton(
                          onPressed: widget.enabled ? _submit : null,
                          icon: const Icon(Icons.arrow_upward_rounded),
                          tooltip: 'Send',
                          iconSize: 20,
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(6),
                            minimumSize: const Size(32, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Image thumbnail strip ─────────────────────────────
                if (_pendingImages.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    child: SizedBox(
                      height: 64,
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
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: -5,
                                right: -5,
                                child: GestureDetector(
                                  onTap: () => setState(
                                      () => _pendingImages.removeAt(index)),
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.error,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      size: 10,
                                      color: theme.colorScheme.onError,
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

                // ── Text area ────────────────────────────────────────
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  maxLines: 8,
                  minLines: 3,
                  textInputAction: TextInputAction.newline,
                  enabled: widget.enabled,
                  style: theme.textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Message Claude...',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
