import 'package:flutter/material.dart';
import 'dart:math' as math;

class CustomLoadingIndicator extends StatefulWidget {
  final double size;
  final Color color;
  final double strokeWidth;

  const CustomLoadingIndicator({
    super.key,
    this.size = 50,
    this.color = const Color(0xFF1976D2),
    this.strokeWidth = 3,
  });

  @override
  State<CustomLoadingIndicator> createState() => _CustomLoadingIndicatorState();
}

class _CustomLoadingIndicatorState extends State<CustomLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
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
      child: CustomPaint(
        painter: _LoadingPainter(
          animation: _controller,
          color: widget.color,
          strokeWidth: widget.strokeWidth,
        ),
      ),
    );
  }
}

class _LoadingPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;
  final double strokeWidth;

  _LoadingPainter({
    required this.animation,
    required this.color,
    required this.strokeWidth,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth;

    // Draw rotating arc
    final sweepAngle = 2 * math.pi * 0.75;
    final startAngle = 2 * math.pi * animation.value;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );

    // Draw dots
    for (int i = 0; i < 3; i++) {
      final dotAngle = startAngle + (i * math.pi / 4);
      final dotX = center.dx + radius * math.cos(dotAngle);
      final dotY = center.dy + radius * math.sin(dotAngle);

      final dotPaint = Paint()
        ..color = color.withOpacity(1.0 - (i * 0.3))
        ..style = PaintingStyle.fill;

      final dotSize = (strokeWidth + 1) - i;
      canvas.drawCircle(Offset(dotX, dotY), dotSize, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_LoadingPainter oldDelegate) => true;
}
