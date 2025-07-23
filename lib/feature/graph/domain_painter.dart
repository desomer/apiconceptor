import 'dart:math';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/feature/graph/pan_spring_graph.dart';

class DomainPainter extends CustomPainter {
  final PathNode pathHead;

  DomainPainter({required this.pathHead});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.grey.shade500
          ..strokeWidth = 1;

    for (var element in pathHead.children.entries) {
      String domain = element.key.substring('root>'.length);
      var nodes = element.value;

      Rectangle<double>? rect;

      // Draw the nodes
      for (var node in nodes) {
        var node2 = node.children.values.firstOrNull?.first.node;
        if (node2 != null) {
          var rec = Rectangle(node2.x, node2.y, node2.width, node2.height + 25);
          if (rect == null) {
            rect = rec;
          } else {
            // Manually compute the union of two rectangles
            double left = min(rect.left, rec.left);
            double top = min(rect.top, rec.top);
            double right = max(rect.right, rec.right);
            double bottom = max(rect.bottom, rec.bottom);
            rect = Rectangle(left, top, right - left, bottom - top);
          }
        }
      }
      if (rect != null) {
        final dashWidth = 4.0;
        final dashSpace = 4.0;
        final path = _createDashedRectPath(
          Rect.fromLTWH(
            rect.left - 20,
            rect.top - 20,
            rect.width + 40,
            rect.height + 40,
          ),
          dashWidth,
          dashSpace,
        );

        TextSpan span = TextSpan(
          style: TextStyle(color: Colors.blue[800]),
          text: domain,
        );
        TextPainter tp = TextPainter(
          text: span,
          textAlign: TextAlign.left,
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(canvas, Offset(rect.left - 20, rect.top - 20 - 20));

        canvas.drawPath(path, paint);
      }
    }
  }

  Path _createDashedRectPath(Rect rect, double dashWidth, double dashSpace) {
    final path = Path();
    // Top
    _addDashedLine(
      path,
      Offset(rect.left, rect.top),
      Offset(rect.right, rect.top),
      dashWidth,
      dashSpace,
    );
    // Right
    _addDashedLine(
      path,
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.bottom),
      dashWidth,
      dashSpace,
    );
    // Bottom
    _addDashedLine(
      path,
      Offset(rect.right, rect.bottom),
      Offset(rect.left, rect.bottom),
      dashWidth,
      dashSpace,
    );
    // Left
    _addDashedLine(
      path,
      Offset(rect.left, rect.bottom),
      Offset(rect.left, rect.top),
      dashWidth,
      dashSpace,
    );
    return path;
  }

  void _addDashedLine(
    Path path,
    Offset start,
    Offset end,
    double dashWidth,
    double dashSpace,
  ) {
    final totalLength = (end - start).distance;
    final direction = (end - start) / totalLength;
    double distance = 0.0;
    while (distance < totalLength) {
      final currentStart = start + direction * distance;
      final currentEnd =
          start + direction * min(distance + dashWidth, totalLength);
      path.moveTo(currentStart.dx, currentStart.dy);
      path.lineTo(currentEnd.dx, currentEnd.dy);
      distance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
