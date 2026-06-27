import 'package:flutter/material.dart';

class InflectionHandleWidget extends StatelessWidget {
  final double left;
  final double top;
  final double radius;
  final Color color;
  final Color borderColor;
  final Color shadowColor;
  final GestureTapDownCallback? onTapDown;
  final GestureTapDownCallback? onSecondaryTapDown;
  final GestureDragStartCallback? onPanStart;
  final GestureDragUpdateCallback? onPanUpdate;
  final GestureDragEndCallback? onPanEnd;

  const InflectionHandleWidget({
    super.key,
    required this.left,
    required this.top,
    required this.radius,
    required this.color,
    required this.borderColor,
    required this.shadowColor,
    this.onTapDown,
    this.onSecondaryTapDown,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: MouseRegion(
        cursor: SystemMouseCursors.move,
        child: GestureDetector(
          onTapDown: onTapDown,
          onSecondaryTapDown: onSecondaryTapDown,
          onPanStart: onPanStart,
          onPanUpdate: onPanUpdate,
          onPanEnd: onPanEnd,
          child: Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
