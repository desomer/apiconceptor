import 'package:flutter/material.dart';
import 'package:jsonschema/feature/graph/pan_spring_graph.dart';
import 'package:jsonschema/feature/graph/widget_graph_node.dart';

class EdgePainter extends CustomPainter {
  final List<Node> nodes;
  final List<Edge> edges;

  EdgePainter(this.nodes, this.edges);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.grey.shade500
          ..strokeWidth = 2;

    for (var edge in edges) {
      final from = nodes[edge.from];
      final to = nodes[edge.to];
      canvas.drawLine(
        Offset(from.x + (from.width / 2), from.y + (from.height / 2) + 20),
        Offset(to.x + (to.width / 2), to.y + (to.height / 2) + 20),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
