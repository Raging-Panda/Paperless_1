import 'package:flutter/material.dart';

/// A looping paper animation:
///   0.00 – 0.32  paper enters from below (ease-out), edges bow from drag
///   0.32 – 0.44  paper decelerates, settles at centre
///   0.44 – 0.74  receipt lines draw left-to-right one by one
///   0.74 – 1.00  paper exits upward (ease-in), edges bow from drag,
///                restarts blank from below
class PaperLoadingIcon extends StatefulWidget {
  final double size;
  const PaperLoadingIcon({super.key, this.size = 100});

  @override
  State<PaperLoadingIcon> createState() => _PaperLoadingIconState();
}

class _PaperLoadingIconState extends State<PaperLoadingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _PaperLoopPainter(_ctrl.value),
        ),
      ),
    );
  }
}

class _PaperLoopPainter extends CustomPainter {
  final double t; // 0.0 – 1.0

  _PaperLoopPainter(this.t);

  // ── Phase boundaries ──────────────────────────────────────────────────────
  static const _kEnterEnd    = 0.32; // finished entering
  static const _kPauseEnd    = 0.44; // pause before scribble
  static const _kScribbleEnd = 0.74; // finished scribbling → exit starts

  // ── Y position ───────────────────────────────────────────────────────────
  // Fraction of canvas height offset from centre. + = below, − = above.
  double get _yFrac {
    if (t < _kEnterEnd) {
      // Ease out: 1.55 → 0
      return 1.55 * (1.0 - Curves.easeOut.transform(t / _kEnterEnd));
    } else if (t < _kScribbleEnd) {
      return 0.0;
    } else {
      // Ease in: 0 → −1.55
      return -1.55 *
          Curves.easeIn.transform((t - _kScribbleEnd) / (1.0 - _kScribbleEnd));
    }
  }

  // ── Bend amount ───────────────────────────────────────────────────────────
  // Peaks in the middle of each movement phase (parabolic), zero when still.
  double get _bendFrac {
    if (t < _kEnterEnd) {
      final p = t / _kEnterEnd; // 0 → 1
      return 4.0 * p * (1.0 - p); // parabola, peak = 1 at p = 0.5
    }
    if (t > _kScribbleEnd) {
      final p = (t - _kScribbleEnd) / (1.0 - _kScribbleEnd);
      return 4.0 * p * (1.0 - p);
    }
    return 0.0;
  }

  // ── Scribble progress ─────────────────────────────────────────────────────
  double get _scribble {
    if (t <= _kPauseEnd) return 0.0;
    if (t >= _kScribbleEnd) return 1.0;
    return (t - _kPauseEnd) / (_kScribbleEnd - _kPauseEnd);
  }

  // ── Paint ─────────────────────────────────────────────────────────────────
  @override
  void paint(Canvas canvas, Size size) {
    // Clip so paper slides in/out cleanly.
    canvas.clipRect(Offset.zero & size);

    final w = size.width;
    final h = size.height;

    final pw = w * 0.62; // paper width
    final ph = h * 0.74; // paper height
    final pl = (w - pw) / 2; // left edge
    final cx = w / 2;
    final cy = h / 2 + _yFrac * h;
    final pt = cy - ph / 2; // top edge
    final pb = cy + ph / 2; // bottom edge

    // Bend: when moving upward the trailing (bottom) edge lags, so both
    // top and bottom bow slightly inward (toward paper centre) giving a
    // gentle wave/curl that peaks in the middle of each movement phase.
    final bendPx = _bendFrac * h * 0.072;

    // ── Shadow ──────────────────────────────────────────────────────────────
    canvas.drawShadow(
      Path()
        ..addRRect(RRect.fromLTRBR(
            pl + 2, pt + 2, pl + pw + 2, pb + 2, const Radius.circular(4))),
      Colors.black,
      6.0,
      false,
    );

    // ── Paper body ───────────────────────────────────────────────────────────
    // Top edge bows downward (toward paper centre) during movement.
    // Bottom edge bows upward (toward paper centre) — symmetric wave.
    final paper = Path()
      ..moveTo(pl, pt)
      ..quadraticBezierTo(cx, pt + bendPx, pl + pw, pt) // top edge
      ..lineTo(pl + pw, pb)
      ..quadraticBezierTo(cx, pb - bendPx, pl, pb) // bottom edge
      ..close();

    canvas.drawPath(paper, Paint()..color = const Color(0xFFF9F8F5));
    canvas.drawPath(
      paper,
      Paint()
        ..color = const Color(0xFFDDDDDD)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // ── Header rule line (always present) ───────────────────────────────────
    canvas.drawLine(
      Offset(pl + pw * 0.12, pt + ph * 0.10),
      Offset(pl + pw * 0.88, pt + ph * 0.10),
      Paint()
        ..color = const Color(0xFFCCCCCC)
        ..strokeWidth = 1.2,
    );

    // ── Receipt scribble lines ───────────────────────────────────────────────
    if (_scribble > 0) {
      final ink = Paint()
        ..color = const Color(0xFF546E7A)
        ..strokeWidth = ph * 0.026
        ..strokeCap = StrokeCap.round;

      //             yFrac  widthFrac  delay
      _line(canvas, pl, pw, ph, cx, pt, ink, 0.22, 0.70, 0.00);
      _line(canvas, pl, pw, ph, cx, pt, ink, 0.34, 0.50, 0.14);
      _line(canvas, pl, pw, ph, cx, pt, ink, 0.46, 0.63, 0.26);
      _line(canvas, pl, pw, ph, cx, pt, ink, 0.57, 0.43, 0.40);
      _line(canvas, pl, pw, ph, cx, pt, ink, 0.68, 0.56, 0.54);
      _line(canvas, pl, pw, ph, cx, pt, ink, 0.79, 0.36, 0.68);
    }
  }

  /// Draws one receipt line, appearing left-to-right with a staggered delay.
  void _line(
    Canvas canvas,
    double pl, double pw, double ph, double cx, double pt,
    Paint paint,
    double yFrac,
    double widthFrac,
    double delay,
  ) {
    final progress =
        (((_scribble - delay) / (1.0 - delay)).clamp(0.0, 1.0));
    if (progress <= 0) return;

    final lineY = pt + ph * yFrac;
    final half = pw * widthFrac / 2;
    final endX = cx - half + (pw * widthFrac) * progress;

    canvas.drawLine(
      Offset(cx - half, lineY),
      Offset(endX, lineY),
      paint,
    );
  }

  @override
  bool shouldRepaint(_PaperLoopPainter old) => old.t != t;
}
