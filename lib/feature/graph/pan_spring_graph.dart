import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class Node {
  double x, y, dx = 0, dy = 0;
  Node(this.x, this.y);
  double height = 100;
  double width = 100;
}

class Edge {
  int from, to;
  Edge(this.from, this.to);
}

class PanModelGraph extends StatefulWidget {
  const PanModelGraph({super.key});

  @override
  State<PanModelGraph> createState() => _PanModelGraphState();
}

class _PanModelGraphState extends State<PanModelGraph> {
  final List<Node> nodes = List.generate(
    6,
    (i) => Node(
      100 + Random().nextDouble() * 800,
      100 + Random().nextDouble() * 500,
    ),
  );

  final List<Edge> edges = [
    Edge(0, 1),
    Edge(1, 2),
    //  Edge(2, 3),
    Edge(3, 4),
    Edge(4, 5),
    //Edge(5, 0),
    //   Edge(0, 3),
  ];

  final double areaWidth = 1000;
  final double areaHeight = 1000;
  late Timer timer;

  @override
  void initState() {
    super.initState();

    nodes[2].height = 200;
    nodes[5].height = 200;

    timer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      _applyForces();
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  void _applyForces() {
    const double springLength = 150;
    const double k = 1000;
    const double damping = 0.8;

    for (var node in nodes) {
      node.dx = 0;
      node.dy = 0;
    }

    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        var dx =
            (nodes[j].x - nodes[i].x) - (nodes[j].width - nodes[i].width).abs();
        var dy =
            (nodes[j].y - nodes[i].y) -
            (nodes[j].height - nodes[i].height).abs();

        var dist = max(1.0, sqrt(dx * dx + dy * dy));
        var force = k / (dist * dist);
        var fx = force * dx / dist;
        var fy = force * dy / dist;

        nodes[i].dx -= fx;
        nodes[i].dy -= fy;
        nodes[j].dx += fx;
        nodes[j].dy += fy;
      }
    }

    for (var edge in edges) {
      var a = nodes[edge.from];
      var b = nodes[edge.to];
      var dx = b.x - a.x;
      var dy = b.y - a.y;
      var dist = max(1.0, sqrt(dx * dx + dy * dy));
      var force = (dist - springLength) * 0.05;
      var fx = force * dx / dist;
      var fy = force * dy / dist;

      a.dx += fx;
      a.dy += fy;
      b.dx -= fx;
      b.dy -= fy;
    }

    for (var node in nodes) {
      node.x = (node.x + node.dx * damping).clamp(0.0, areaWidth);
      node.y = (node.y + node.dy * damping).clamp(0.0, areaHeight);
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      boundaryMargin: EdgeInsets.all(double.infinity),
      minScale: 0.1,
      maxScale: 5.0,
      scaleFactor: 1000,
      child: Stack(
        children: [
          CustomPaint(
            painter: EdgePainter(nodes, edges),
            child: SizedBox(width: areaWidth, height: areaHeight),
          ),
          ...nodes.asMap().entries.map((entry) {
            final i = entry.key;
            final node = entry.value;
            return AnimatedPositioned(
              duration: Duration(milliseconds: 30),
              left: node.x,
              top: node.y,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    node.x = (node.x + details.delta.dx).clamp(0.0, areaWidth);
                    node.y = (node.y + details.delta.dy).clamp(0.0, areaHeight);
                  });
                },
                child: getModel(node, i),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget getModel(Node node, int i)
  {
     return  Column(
                  children: [
                    Container(
                      width: node.width,
                      height: node.height,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        // borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 4),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$i',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Node $i', style: TextStyle(fontSize: 12)),
                  ],
                );
  }

}

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
        Offset(from.x + (from.width / 2), from.y + (from.height / 2)),
        Offset(to.x + (to.width / 2), to.y + (to.height / 2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
