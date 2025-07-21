import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/yaml_browser.dart';
import 'package:jsonschema/json_browser/browse_api.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget_state/widget_md_doc.dart';
import 'package:yaml/yaml.dart';
import 'package:collection/collection.dart';

class Node {
  double x, y, dx = 0, dy = 0;
  Node(this.x, this.y, this.name, this.info);
  double height = 100;
  double width = 200;
  String name;
  AttributInfo info;
  ModelSchema? model; // Added to allow assignment to node.model
}

class ApiNode extends Node {
  ApiNode(super.x, super.y, super.name, super.info);
}

class ModelNode extends Node {
  ModelNode(super.x, super.y, super.name, super.info);
  int nbRow = 3; // 3 par defaut
  List<Widget> listRowYaml = [];
}

class Edge {
  int from, to;
  Edge(this.from, this.to);
}

class PathNode {
  String path;
  Map<String, List<PathNode>> children = {};
  Node? node; // Optional reference to a Node if needed
  PathNode(this.path);
}

class PanModelGraph extends StatefulWidget {
  const PanModelGraph({super.key});

  @override
  State<PanModelGraph> createState() => _PanModelGraphState();
}

class _PanModelGraphState extends State<PanModelGraph> with WidgetModelHelper {
  final List<Node> nodes = [];
  final List<Edge> edges = [];

  PathNode? domainPath; // Tête de la liste chaînée des paths

  final double areaWidth = 5000;
  final double areaHeight = 5000;
  late Timer timer;

  @override
  void initState() {
    initGraph(currentCompany.listModel);
    initGraph(currentCompany.listComponent);
    initGraph(currentCompany.listRequest);
    initGraph(currentCompany.listAPI);

    timer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      _applyForces();
    });

    super.initState();
  }

  void initGraph(ModelSchema model) {
    model.mapInfoByTreePath.forEach((key, value) {
      if (value.type == 'model') {
        addModel(value);
      } else if (value.type == 'ope') {
        _addApi(value);
      }
    });

    //print( pathHead);
  }

  void addModel(AttributInfo value) {
    var node = ModelNode(
      100 + Random().nextDouble() * 800,
      100 + Random().nextDouble() * 500,
      value.name,
      value,
    );

    nodes.add(node);
    initDomain(value, node);
    _initModelLink(value, node);
  }

  void _addApi(AttributInfo value) {
    var paths = value.path.split('>');
    StringBuffer api = StringBuffer();
    paths.getRange(1, paths.length - 1).forEach((element) {
      if (api.length > 0) api.write('/');
      api.write(element);
    });

    var node = ApiNode(
      100 + Random().nextDouble() * 800,
      100 + Random().nextDouble() * 500,
      api.toString(),
      value,
    );

    nodes.add(node);
    node.height = 1;
    node.width = node.name.length * 9;
    _initApiLink(value, node, ''); // les requests
    _initApiLink(value, node, 'response/');
  }

  void _initModelLink(AttributInfo value, ModelNode node) {
    var key = value.properties![constMasterID];
    var model = ModelSchema(
      category: Category.model,
      infoManager: InfoManagerModel(typeMD: TypeMD.model),
      headerName: value.name,
      id: key,
    );
    node.model = model;
    model.loadYamlAndProperties(cache: false, withProperties: false).then((
      value,
    ) {
      YamlDoc docYaml = YamlDoc();
      YamlDocument doc = loadYamlDocument(model.modelYaml);
      docYaml.doAnalyse(doc, model.modelYaml);
      node.listRowYaml = docYaml.doPrettyPrint();

      node.nbRow = docYaml.listYamlLine.length;
      node.height = min(500, max(6, docYaml.listYamlLine.length) * 14.0);

      // ajoute les lien
      docYaml.refs.forEach((key, value) {
        var refNode = nodes.firstWhere((n) {
          if (n is ModelNode) return n.model?.headerName == key;
          return false;
        });
        edges.add(Edge(nodes.indexOf(node), nodes.indexOf(refNode)));
      });

      if (mounted) setState(() {});
    });
  }

  void _initApiLink(AttributInfo value, ApiNode node, String prefix) {
    var key = value.properties![constMasterID];
    var model = ModelSchema(
      category: Category.api,
      infoManager: InfoManagerAPI(),
      headerName: value.name,
      id: '$prefix$key',
    );
    node.model = model;
    model.loadYamlAndProperties(cache: false, withProperties: false).then((
      value,
    ) {
      YamlDoc docYaml = YamlDoc();
      YamlDocument doc = loadYamlDocument(model.modelYaml);
      docYaml.doAnalyse(doc, model.modelYaml);

      // // ajoute les lien
      for (var row in docYaml.listRoot) {
        var t = row.value.toString();
        if (t.startsWith('\$')) t = t.substring(1); //retire le $
        var refNode = nodes.firstWhereOrNull((n) {
          if (n is ModelNode) return n.model?.headerName == t;
          return false;
        });
        if (refNode != null) {
          edges.add(Edge(nodes.indexOf(node), nodes.indexOf(refNode)));
        }
      }

      if (mounted) setState(() {});
    });
  }

  void initDomain(AttributInfo value, Node node) {
    var paths = value.path.split('>');
    String current = '';
    PathNode? lastNode = domainPath;
    for (int i = 0; i < paths.length; i++) {
      current = current.isEmpty ? paths[i] : '$current>${paths[i]}';
      if (lastNode == null) {
        domainPath = PathNode(current);
        lastNode = domainPath;
      } else if (current != domainPath!.path) {
        if (!lastNode.children.containsKey(current)) {
          lastNode.children[current] = [];
        }
        var newNode = PathNode(current);
        lastNode.children[current]!.add(newNode);
        lastNode = newNode;
      }
      if (i == paths.length - 1) {
        lastNode!.node = node;
      }
    }
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  void _applyForces() {
    const double springLength = 300;
    const double k = 1000;
    const double damping = 0.8;

    for (var node in nodes) {
      node.dx = 0;
      node.dy = 0;
    }

    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        var dx =
            (nodes[j].x + (nodes[j].width / 2)) -
            (nodes[i].x + (nodes[i].width / 2));
        var dy =
            (nodes[j].y + (nodes[j].height / 2)) -
            (nodes[i].y + (nodes[i].height / 2));

        var dist = max(1.0, sqrt(dx * dx + dy * dy));
        var force = k / (dist * dist);
        var fx = (force * dx) / dist;
        var fy = (force * dy) / dist;

        nodes[i].dx -= fx;
        nodes[i].dy -= fy;
        nodes[j].dx += fx;
        nodes[j].dy += fy;
      }
    }

    for (var edge in edges) {
      var a = nodes[edge.from];
      var b = nodes[edge.to];
      var dx = (b.x + (b.width / 2)) - (a.x + (a.width / 2));
      var dy = (b.y + (b.height / 2)) - (a.y + (a.height / 2));
      var dx1 = dx.abs();
      var dy1 = dy.abs();
      var springLengthX = springLength;
      var springLengthY = springLength;

      if (dx1 < dy1) {
        // en dessous ou dessus
        if (dx1 < 100) {
          // proche du vertical
          springLengthX = ((a.height / 2) + (b.height / 2)) + 50;
        } else if (dx1 < 200) {
          // proche du vertical
          springLengthX = ((a.height / 2) + (b.height / 2)) + 100;
        } else {
          var w1 = a.width / 2;
          var h1 = a.height / 2;
          var d1c2r = sqrt(w1 * w1 + h1 * h1);
          var w2 = b.width / 2;
          var h2 = b.height / 2;
          var d2c2r = sqrt(w2 * w2 + h2 * h2);

          springLengthX = d1c2r + d2c2r + 20;
        }
        springLengthY = springLengthX;
      } else if (dx1 > dy1) {
        // a droite ou a gauche
        if (dy1 < 100) {
          // proche de l'horizontal
          springLengthX = ((a.width / 2) + (b.width / 2)) + 50;
        } else if (dy1 < 200) {
          // proche de l'horizontal
          springLengthX = ((a.width / 2) + (b.width / 2)) + 100;
        } else {
          var w1 = a.width / 2;
          var h1 = a.height / 2;
          var d1c2r = sqrt(w1 * w1 + h1 * h1);
          var w2 = b.width / 2;
          var h2 = b.height / 2;
          var d2c2r = sqrt(w2 * w2 + h2 * h2);

          springLengthX = d1c2r + d2c2r + 20;
        }
        springLengthY = springLengthX;
      } else {
        print("object");
      }

      var dist = max(1.0, sqrt(dx * dx + dy * dy));
      var forcex = (dist - springLengthX) * 0.05;
      var forcey = (dist - springLengthY) * 0.05;
      var fx = forcex * dx / dist;
      var fy = forcey * dy / dist;

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

  Widget? stack;
  bool scaleEnabled = true;

  @override
  Widget build(BuildContext context) {
    stack = Stack(
      children: [
        CustomPaint(
          painter: EdgePainter(nodes, edges),
          child: SizedBox(width: areaWidth, height: areaHeight),
        ),
        CustomPaint(
          painter: DomainPainter(pathHead: domainPath!),
          child: SizedBox(width: areaWidth, height: areaHeight),
        ),
        ...nodes.asMap().entries.map((entry) {
          // final i = entry.key;
          final node = entry.value;
          return AnimatedPositioned(
            duration: Duration(milliseconds: 30),
            left: node.x,
            top: node.y,
            child: MouseRegion(
              onEnter: (event) {
                setState(() {
                  scaleEnabled = false;
                });
              },
              onExit: (event) {
                setState(() {
                  scaleEnabled = true;
                });
              },
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    node.x = (node.x + details.delta.dx).clamp(0.0, areaWidth);
                    node.y = (node.y + details.delta.dy).clamp(0.0, areaHeight);
                  });
                },
                child:
                    node is ModelNode
                        ? getModel(node)
                        : getAPI(node as ApiNode),
              ),
            ),
          );
        }),
      ],
    );

    var interactiveViewer = InteractiveViewer(
      constrained: false,
      // reste dans le cadre
      // boundaryMargin: EdgeInsets.all(double.infinity),
      minScale: 0.1,
      maxScale: 5.0,
      scaleFactor: 5000,
      scaleEnabled: scaleEnabled,
      child: stack!,
    );
    return interactiveViewer;
  }

  Widget getAPI(ApiNode node) {
    var name = node.info.name;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.grey),
      ),
      child: Row(
        spacing: 5,
        children: [getHttpOpe(name) ?? Container(), Text(node.name)],
      ),
    );
  }

  Widget getModel(ModelNode node) {
    var scrollController = ScrollController();
    return Column(
      children: [
        Text(node.name, style: TextStyle(fontSize: 14)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(4),
          width: node.width,
          height: node.height,
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            border: Border.all(color: Colors.white, width: 1),
          ),
          alignment: Alignment.topLeft,
          child: Scrollbar(
            controller: scrollController,

            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: scrollController,
              child: ListView.builder(
                itemBuilder: (context, index) {
                  return node.listRowYaml.length > index
                      ? getOverflowHidden(node.listRowYaml[index])
                      : Container();
                },
                itemExtent: 19 * (zoom.value / 100),
                itemCount: node.nbRow,
                shrinkWrap: true,
                physics: const AlwaysScrollableScrollPhysics(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget getOverflowHidden(Widget child) {
    return SizedBox(
      height: 19 * (zoom.value / 100),
      child: OverflowBox(
        alignment: Alignment.topLeft,
        maxWidth: double.infinity,
        child: child,
      ),
    );
  }
}

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
