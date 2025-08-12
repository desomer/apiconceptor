import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:jsonschema/pages/router_config.dart';

class WidgetMenuBtn extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (route != null) {
          //NavigationService.push(route!.url);
          route!.goto(context);
        }
      },
      child: Container(
        width: 230,
        height: 70,
        margin: EdgeInsets.all(5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
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
                    icon,
                    size: 32,
                    color: route != null ? Colors.white : Colors.grey,
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        color: route != null ? Colors.white : Colors.grey,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 2)],
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
