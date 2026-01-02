import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/yaml_browser.dart';
import 'package:jsonschema/feature/graph/domain_painter.dart';
import 'package:jsonschema/feature/graph/edge_painter.dart';
import 'package:jsonschema/json_browser/browse_api.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_md_doc.dart';
import 'package:yaml/yaml.dart';
import 'package:collection/collection.dart';

import 'widget_graph_node.dart';



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

class _PanModelGraphState extends State<PanModelGraph> {
  final List<Node> nodes = [];
  final List<Edge> edges = [];

  PathNode? domainPath; // Tête de la liste chaînée des paths

  final double areaWidth = 5000;
  final double areaHeight = 5000;
  late Timer timer;

  @override
  void initState() {
    initGraph(currentCompany.listModel!);
    // initGraph(currentCompany.listComponent);
    // initGraph(currentCompany.listRequest);
    if (currentCompany.listAPI != null) {
      initGraph(currentCompany.listAPI!);
    }

    timer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      _applyForces();
    });

    super.initState();
  }

  void initGraph(ModelSchema model) {
    model.mapInfoByTreePath.forEach((key, value) {
      if (value.type == 'model') {
        _addModel(value);
      } else if (value.type == 'ope') {
        _addApi(value);
      }
    });

    //print( pathHead);
  }

  void _addModel(AttributInfo value) {
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
    _initApiLink(value, node, 'response/'); // les response
  }

  void _initModelLink(AttributInfo value, ModelNode node) {
    var key = value.properties![constMasterID];
    var model = ModelSchema(
      category: Category.model,
      infoManager: InfoManagerModel(typeMD: TypeMD.model),
      headerName: value.name,
      id: key,
      ref: currentCompany.listModel,
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
      ref: currentCompany.listModel,
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
                child: node.getWidget(),
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

}
