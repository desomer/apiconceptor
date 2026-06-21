import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/start_core.dart';

class WidgetMenuBtn extends StatefulWidget {
  const WidgetMenuBtn({
    super.key,
    this.route,
    required this.label,
    required this.icon,
  });
  final Pages? route;
  final String label;
  final IconData icon;

  @override
  State<WidgetMenuBtn> createState() => _WidgetMenuBtnState();
}

class _WidgetMenuBtnState extends State<WidgetMenuBtn> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    scale = zoom.value / 100.0;
    final isInteractive = widget.route != null;
    final showHoverStyle = isInteractive && _isHovered;

    return InkWell(
      mouseCursor: isInteractive
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onHover: (value) {
        if (!isInteractive) {
          if (_isHovered) {
            setState(() => _isHovered = false);
          }
          return;
        }
        setState(() => _isHovered = value);
      },
      onTap: () {
        if (widget.route != null) {
          widget.route!.goto(context);
        }
      },
      child: Container(
        width: 230,
        height: 60 * scale,
        margin: const EdgeInsets.all(5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: showHoverStyle
                    ? Colors.orange.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: showHoverStyle
                      ? Colors.orange
                      : Colors.white.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.25),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    widget.icon,
                    size: 32,
                    color: widget.route != null ? Colors.white : Colors.grey,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 15,
                        color: widget.route != null
                            ? Colors.white
                            : Colors.grey,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 2)],
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
