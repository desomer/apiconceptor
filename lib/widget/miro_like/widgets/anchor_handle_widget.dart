import 'package:flutter/material.dart';

class AnchorHandleWidget extends StatelessWidget {
  final double left;
  final double top;
  final double radius;
  final Color color;
  final GestureTapDownCallback? onTapDown;
  final GestureTapDownCallback? onSecondaryTapDown;
  final GestureDragUpdateCallback? onPanUpdate;

  const AnchorHandleWidget({
    super.key,
    required this.left,
    required this.top,
    required this.radius,
    required this.color,
    this.onTapDown,
    this.onSecondaryTapDown,
    this.onPanUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: onTapDown,
          onSecondaryTapDown: onSecondaryTapDown,
          onPanUpdate: onPanUpdate,
          child: Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}
