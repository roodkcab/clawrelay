import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen overlay for selecting a screenshot region.
///
/// Shows a semi-transparent dark overlay so the user can see the screen
/// content beneath and drag a rubber-band rectangle to select an area.
///
/// Returns the selected [Rect] in *logical pixel* coordinates (relative to
/// the window top-left), or null if the user cancelled (Esc or tiny drag).
class ScreenshotSelectorPage extends StatefulWidget {
  const ScreenshotSelectorPage({super.key});

  @override
  State<ScreenshotSelectorPage> createState() => _ScreenshotSelectorPageState();
}

class _ScreenshotSelectorPageState extends State<ScreenshotSelectorPage> {
  Offset? _start;
  Offset? _end;

  Rect? get _sel =>
      (_start != null && _end != null) ? Rect.fromPoints(_start!, _end!) : null;

  void _confirm() {
    final sel = _sel;
    if (sel == null || sel.width < 4 || sel.height < 4) {
      setState(() {
        _start = null;
        _end = null;
      });
      return;
    }
    Navigator.of(context).pop(sel);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Focus(
        autofocus: true,
        onKeyEvent: (_, e) {
          if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop(null);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            return GestureDetector(
              onPanStart: (d) => setState(() {
                _start = d.localPosition;
                _end = d.localPosition;
              }),
              onPanUpdate: (d) => setState(() => _end = d.localPosition),
              onPanEnd: (_) => _confirm(),
              child: Stack(children: [
                // ── Dark tint ────────────────────────────────────────
                Positioned.fill(
                  child: CustomPaint(painter: _OverlayPainter(_sel)),
                ),

                // ── Dimension label ──────────────────────────────────
                if (_sel != null)
                  Positioned(
                    left: _sel!.left.clamp(0, size.width - 90),
                    top: _sel!.top > 22
                        ? _sel!.top - 22
                        : _sel!.bottom + 4,
                    child: _chip(
                        '${_sel!.width.round()} × ${_sel!.height.round()}'),
                  ),

                // ── Instructions ─────────────────────────────────────
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _chip(
                      'Drag to select area  •  Esc to cancel',
                      fontSize: 13,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
              ]),
            );
          },
        ),
      ),
    );
  }

  Widget _chip(String text, {double fontSize = 11, EdgeInsets? padding}) =>
      Container(
        padding: padding ??
            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text,
            style: TextStyle(color: Colors.white, fontSize: fontSize)),
      );
}

// ── Painter ──────────────────────────────────────────────────────────────────

class _OverlayPainter extends CustomPainter {
  final Rect? sel;
  _OverlayPainter(this.sel);

  @override
  void paint(Canvas canvas, Size size) {
    final dark = Paint()..color = const Color(0x88000000);
    final r = sel;
    if (r == null || r.isEmpty) {
      canvas.drawRect(Offset.zero & size, dark);
      return;
    }
    // Four dark rectangles surrounding the selection hole
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, r.top), dark);
    canvas.drawRect(Rect.fromLTWH(0, r.top, r.left, r.height), dark);
    canvas.drawRect(
        Rect.fromLTWH(r.right, r.top, size.width - r.right, r.height), dark);
    canvas.drawRect(
        Rect.fromLTWH(0, r.bottom, size.width, size.height - r.bottom), dark);

    // Blue border
    canvas.drawRect(
        r,
        Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);

    // White corner handles
    const hs = 5.0;
    final hp = Paint()..color = Colors.white;
    for (final c in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
      canvas.drawRect(
          Rect.fromCenter(center: c, width: hs * 2, height: hs * 2), hp);
    }
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => sel != old.sel;
}
