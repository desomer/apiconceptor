import 'package:flutter/material.dart';

class HoverTextUnderline extends StatefulWidget {
  final String text;
  final TextStyle style;
  final TextOverflow overflow;
  final int maxLines;
  final VoidCallback? onTap;

  const HoverTextUnderline({
    super.key,
    required this.text,
    required this.style,
    required this.overflow,
    required this.maxLines,
    this.onTap,
  });

  @override
  State<HoverTextUnderline> createState() => _HoverTextUnderlineState();
}

class _HoverTextUnderlineState extends State<HoverTextUnderline> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.text,
          style: _hover
              ? widget.style.copyWith(
                  color: Colors.blue,
                  decorationColor: Colors.blue,
                  decoration: TextDecoration.underline,
                )
              : widget.style,
          overflow: widget.overflow,
          maxLines: widget.maxLines,
        ),
      ),
    );
  }
}
