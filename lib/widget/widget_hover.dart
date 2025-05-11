import 'package:flutter/material.dart';

class HoverableCard extends StatefulWidget {
  const HoverableCard({
    super.key,
    required this.child,
    required this.isSelected,
  });
  final Widget child;
  final Function isSelected;

  @override
  State<HoverableCard> createState() => _HoverableCardState();
}

class _HoverableCardState extends State<HoverableCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (context) => setState(() => _isHovered = true),
      onExit: (context) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        transform:
            _isHovered ? (Matrix4.identity()..scale(1.03)) : Matrix4.identity(),
        // transform: _isHovered
        //     ? (Matrix4.identity()
        //       ..scale(1.1)
        //       ..rotateZ(0.1))
        //     : Matrix4.identity(),
        decoration: BoxDecoration(
          //color: _isHovered ? Colors.blueAccent : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow:
              _isHovered
                  ? [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.5),
                      offset: const Offset(0, 8),
                      blurRadius: 20,
                    ),
                  ]
                  : widget.isSelected(this) == true
                  ? [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.5),
                      offset: Offset(0, 5),
                      blurRadius: 20,
                    ),
                  ]
                  : [
                    const BoxShadow(
                      color: Colors.black12,
                      offset: Offset(0, 4),
                      blurRadius: 10,
                    ),
                  ],
        ),
        child: widget.child,
      ),
    );
  }
}
