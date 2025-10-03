import 'dart:math';
import 'package:flutter/material.dart';

class ThunderStormEffect extends StatefulWidget {
  const ThunderStormEffect({super.key});

  @override
  _ThunderEffectState createState() => _ThunderEffectState();
}

class _ThunderEffectState extends State<ThunderStormEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _flash;
  final Random _random = Random();
  double _currentOpacity = 0;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController.unbounded(vsync: this)
      ..addListener(_randomFlash);
    _startRandomFlash();
  }

  void _startRandomFlash() {
    final nextDelay = Duration(milliseconds: 500 + _random.nextInt(2500));
    Future.delayed(nextDelay, () {
      if (!mounted) return;

      _flash = Tween<double>(begin: 0, end: 0.6).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOut,
        ),
      );

      _controller.animateTo(
        1,
        duration: Duration(milliseconds: 200 + _random.nextInt(200)),
      ).whenComplete(() {
        _controller.animateBack(
          0,
          duration: Duration(milliseconds: 300 + _random.nextInt(200)),
        ).whenComplete(_startRandomFlash);
      });
    });
  }

  void _randomFlash() {
    setState(() {
      _currentOpacity = _flash.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 50),
        opacity: _currentOpacity,
        child: Container(
          color: Colors.white.withOpacity(0.8),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
