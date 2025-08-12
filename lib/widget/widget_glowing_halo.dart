import 'package:flutter/material.dart';

class GlowingHalo extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double minRadius;
  final double maxRadius;
  final double minOpacity;
  final double maxOpacity;
  final Duration duration;

  const GlowingHalo({
    required this.child,
    this.glowColor = Colors.cyan,
    this.minRadius = 5.0,
    this.maxRadius = 15.0,
    this.minOpacity = 0.1,
    this.maxOpacity = 0.5,
    this.duration = const Duration(milliseconds: 800),
    super.key,
  });

  @override
  State<GlowingHalo> createState() => _GlowingHaloState();
}

class _GlowingHaloState extends State<GlowingHalo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _radiusAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);

    _radiusAnimation = Tween<double>(
      begin: widget.minRadius,
      end: widget.maxRadius,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: widget.minOpacity,
      end: widget.maxOpacity,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: _opacityAnimation.value),
                blurRadius: _radiusAnimation.value,
                spreadRadius: _radiusAnimation.value / 2,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}