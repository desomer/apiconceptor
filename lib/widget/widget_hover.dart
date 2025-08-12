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
  //  if (true) return widget.child;

    return MouseRegion(
      onEnter: (context) => setState(() => _isHovered = true),
      onExit: (context) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,

        // transform:
        //     _isHovered ? (Matrix4.identity()..scale(1.03)) : Matrix4.identity(),
            
        // transform: _isHovered
        //     ? (Matrix4.identity()
        //       ..scale(1.1)
        //       ..rotateZ(0.1))
        //     : Matrix4.identity(),
        
        decoration: BoxDecoration(
          //color: _isHovered ? Colors.blueAccent : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow:
              widget.isSelected(this) == true
                  ? [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.6),
                      offset: const Offset(0, 0),
                      blurRadius: 5,
                    ),
                  ]
                  : _isHovered
                  ? [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.3),
                      offset: Offset(5, 5),
                      blurRadius: 20,
                    ),
                  ]
                  :
                   [
                    const BoxShadow(
                      color: Colors.black12,
                      // offset: Offset(0, 4),
                      // blurRadius: 0,
                    ),
                  ],
        ),
        child: widget.child,
      ),
    );
  }
}
