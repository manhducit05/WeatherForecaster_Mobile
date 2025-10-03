import 'package:flutter/material.dart';
import 'dart:math';

class RainyEffect extends StatefulWidget {
  const RainyEffect({super.key});

  @override
  _RainEffectState createState() => _RainEffectState();
}

class _RainEffectState extends State<RainyEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<RainDrop> _drops = List.generate(80, (_) => RainDrop());

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return SizedBox.expand(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          for (var drop in _drops) {
            drop.fall(size.height, size.width);
          }
          return CustomPaint(
            painter: RainPainter(_drops),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class RainDrop {
  static final Random _rand = Random();
  double x = _rand.nextDouble() * 400;
  double y = _rand.nextDouble() * 800;
  double speed = 12;

  void fall(double maxHeight, double maxWidth) {
    y += speed;
    if (y > maxHeight) {
      y = 0;
      x = _rand.nextDouble() * maxWidth;
    }
  }
}

class RainPainter extends CustomPainter {
  final List<RainDrop> drops;
  RainPainter(this.drops);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 2;

    for (var drop in drops) {
      canvas.drawLine(
        Offset(drop.x, drop.y),
        Offset(drop.x, drop.y + 12),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
