import 'package:flutter/material.dart';
import 'dart:math';

class SunnyEffect extends StatefulWidget {
  const SunnyEffect({super.key});

  @override
  _SunlightEffectState createState() => _SunlightEffectState();
}

class _SunlightEffectState extends State<SunnyEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                return Transform.rotate(
                  angle: _controller.value * 2 * pi, // dùng pi thay vì số tay
                  child: CustomPaint(
                    painter: SunPainter(),
                    size: const Size(200, 200),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
class SunPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Mặt trời
    final circlePaint = Paint()..color = Colors.yellow.withValues(alpha: 0.6);
    canvas.drawCircle(center, 60, circlePaint);

    // Tia nắng
    final rayPaint = Paint()
      ..color = Colors.yellow.withValues(alpha: 0.6)
      ..strokeWidth = 6;

    for (var i = 0; i < 8; i++) {
      final angle = (pi / 4) * i;
      final start = Offset(center.dx + 60 * cos(angle), center.dy + 60 * sin(angle));
      final end = Offset(center.dx + 100 * cos(angle), center.dy + 100 * sin(angle));
      canvas.drawLine(start, end, rayPaint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
