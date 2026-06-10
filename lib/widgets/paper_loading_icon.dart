import 'package:flutter/material.dart';

class PaperLoadingIcon extends StatefulWidget {
  final double size;
  const PaperLoadingIcon({super.key, this.size = 100});

  @override
  State<PaperLoadingIcon> createState() => _PaperLoadingIconState();
}

class _PaperLoadingIconState extends State<PaperLoadingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final angle = _controller.value * 2 * 3.1415926535897932;
          final progress = Curves.easeInOut.transform(_controller.value);
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: widget.size,
                  height: widget.size * 0.72,
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(255, 255, 255, 0.96),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromRGBO(0, 0, 0, 0.2),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 14,
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 6,
                        width: widget.size * 0.3,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: CustomPaint(
                          painter: _PaperScribblePainter(progress),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PaperScribblePainter extends CustomPainter {
  final double progress;
  _PaperScribblePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueGrey.shade700
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, size.height * 0.18);
    path.cubicTo(
      size.width * 0.25,
      size.height * 0.23,
      size.width * 0.4,
      size.height * 0.14,
      size.width * 0.62,
      size.height * 0.25,
    );
    path.cubicTo(
      size.width * 0.78,
      size.height * 0.32,
      size.width * 0.85,
      size.height * 0.2,
      size.width,
      size.height * 0.22,
    );

    final metric = path.computeMetrics().first;
    final currentLength = metric.length * progress;
    final extract = metric.extractPath(0, currentLength);
    canvas.drawPath(extract, paint);

    final lowerPath = Path();
    lowerPath.moveTo(0, size.height * 0.45);
    lowerPath.cubicTo(
      size.width * 0.15,
      size.height * 0.55,
      size.width * 0.35,
      size.height * 0.35,
      size.width * 0.55,
      size.height * 0.5,
    );
    lowerPath.cubicTo(
      size.width * 0.7,
      size.height * 0.62,
      size.width * 0.88,
      size.height * 0.47,
      size.width,
      size.height * 0.52,
    );

    final lowerMetric = lowerPath.computeMetrics().first;
    final lowerCurrent = lowerMetric.length * (progress - 0.2).clamp(0.0, 1.0);
    if (lowerCurrent > 0) {
      canvas.drawPath(lowerMetric.extractPath(0, lowerCurrent), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PaperScribblePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
