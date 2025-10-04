import 'package:flutter/material.dart';
import 'dart:math';

import 'package:flutter_svg/svg.dart';

class CloudyEffect extends StatefulWidget {
  const CloudyEffect({super.key});

  @override
  _CloudyEffectState createState() => _CloudyEffectState();
}

class _CloudyEffectState extends State<CloudyEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _move;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    _move = Tween<double>(begin: -250, end: 500).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: AnimatedBuilder(
        animation: _move,
        builder: (_, __) {
          return Stack(
            children: [
              // Mây 1
              Positioned(
                top: 40,
                left: _move.value,
                child: _cloud(),
              ),
              // Mây 2 (lệch chút)
              Positioned(
                top: 120,
                left: _move.value - 200,
                child: _cloud(size: 180, opacity: 0.75),
              ),
              // Mây 3 (to hơn)
              Positioned(
                top: 200,
                left: _move.value + 150,
                child: _cloud(size: 260, opacity: 0.85),
              ),
              // Mây 4 (thấp hơn)
              Positioned(
                top: 280,
                left: _move.value - 100,
                child: _cloud(size: 200, opacity: 0.7),
              ),
            ],
          );
        },
      ),
    );
  }

// Hàm dựng mây tái sử dụng
  Widget _cloud({double size = 400, double opacity = 0.8}) {
    return Opacity(
      opacity: opacity,
      child: Image.asset(
        "assets/images/cloud-effect.png",
        width: size,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
