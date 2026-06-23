import 'package:flutter/material.dart';

class LinkLabelHandleWidget extends StatelessWidget {
  final double left;
  final double top;
  final double width;
  final double height;
  final GestureTapDownCallback? onTapDown;
  final GestureDragUpdateCallback? onPanUpdate;

  const LinkLabelHandleWidget({
    super.key,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.onTapDown,
    this.onPanUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: MouseRegion(
        cursor: SystemMouseCursors.move,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: onTapDown,
          onPanUpdate: onPanUpdate,
          child: SizedBox(
            width: width,
            height: height,
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
      ),
    );
  }
}
