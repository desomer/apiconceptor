import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:jsonschema/authorization_manager.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/yaml_browser.dart';
import 'package:jsonschema/feature/graph/domain_painter.dart';
import 'package:jsonschema/feature/graph/edge_painter.dart';
import 'package:jsonschema/json_browser/browse_api.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/widget_md_doc.dart';
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

  int _modelIndex = 0;
  int _apiIndex = 0;
  final Set<int> _pinnedNodeIndexes = {};
  Timer? _layoutDebounce;
  bool _userInteracted = false;
  bool _initialFitDone = false;

  final TransformationController _transformController =
      TransformationController();

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
    final entries = model.mapInfoByTreePath.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (final entry in entries) {
      final value = entry.value;
      if (value.type != 'folder') {
        _addModel(value);
      } else if (value.type == 'ope') {
        _addApi(value);
      }
    }

    //print( pathHead);
  }

  Offset _gridPosition({
    required int index,
    required double startX,
    required double startY,
    int columns = 7,
    double xStep = 320,
    double yStep = 220,
  }) {
    final col = index % columns;
    final row = index ~/ columns;
    return Offset(startX + col * xStep, startY + row * yStep);
  }

  void _addModel(AttributInfo value) {
    final defaultPos = _gridPosition(
      index: _modelIndex++,
      startX: 120,
      startY: 120,
    );
    final hasSavedPosition =
        value.properties?['#x'] != null && value.properties?['#y'] != null;
    var node = ModelNode(
      value.properties?['#x'] ?? defaultPos.dx,
      value.properties?['#y'] ?? defaultPos.dy,
      value.name,
      value,
    );

    nodes.add(node);
    if (hasSavedPosition) {
      _pinnedNodeIndexes.add(nodes.length - 1);
    }
    initDomain(value, node);
    _initModelLink(value, node);
  }

  void savePosition() {
    k = 0;
    final mapEntryEmpty = const MapEntry('', null);
    for (var node in nodes) {
      if (node is ModelNode && node.model != null) {
        var info = node.info;
        var accessor = ModelAccessorAttr(
          node: NodeAttribut(yamlNode: mapEntryEmpty, info: info, parent: null),
          schema: currentCompany.listModel!,
          propName: '#x',
        );
        accessor.set(node.x);
        accessor = ModelAccessorAttr(
          node: NodeAttribut(yamlNode: mapEntryEmpty, info: info, parent: null),
          schema: currentCompany.listModel!,
          propName: '#y',
        );
        accessor.set(node.y);
      }
    }
  }

  void _addApi(AttributInfo value) {
    var paths = value.path.split('>');
    StringBuffer api = StringBuffer();
    paths.getRange(1, paths.length - 1).forEach((element) {
      if (api.length > 0) api.write('/');
      api.write(element);
    });

    final defaultPos = _gridPosition(
      index: _apiIndex++,
      startX: 180,
      startY: 2200,
    );
    final hasSavedPosition =
        value.properties?['#x'] != null && value.properties?['#y'] != null;
    var node = ApiNode(
      value.properties?['#x'] ?? defaultPos.dx,
      value.properties?['#y'] ?? defaultPos.dy,
      api.toString(),
      value,
    );

    nodes.add(node);
    if (hasSavedPosition) {
      _pinnedNodeIndexes.add(nodes.length - 1);
    }
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
      refDomain: currentCompany.listModel,
    );
    node.model = model;
    model.loadYamlAndProperties(cache: false, withProperties: false).then((
      value,
    ) {
      YamlDoc docYaml = YamlDoc();
      docYaml.load(model.modelYaml);
      docYaml.doAnalyse();
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

      _scheduleConnectedLayout();
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
      refDomain: currentCompany.listModel,
    );
    node.model = model;
    model.loadYamlAndProperties(cache: false, withProperties: false).then((
      value,
    ) {
      YamlDoc docYaml = YamlDoc();
      docYaml.load(model.modelYaml);
      docYaml.doAnalyse();

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

      _scheduleConnectedLayout();
      if (mounted) setState(() {});
    });
  }

  void _scheduleConnectedLayout() {
    if (_userInteracted) return;

    _layoutDebounce?.cancel();
    _layoutDebounce = Timer(const Duration(milliseconds: 50), () {
      if (!mounted || _userInteracted) return;
      _layoutConnectedNodesOnGrid();
      if (!_initialFitDone) {
        _initialFitDone = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitToScreen());
      }
      if (mounted) setState(() {});
    });
  }

  void _layoutConnectedNodesOnGrid() {
    if (nodes.isEmpty) return;

    final adjacency = List.generate(nodes.length, (_) => <int>{});
    for (final edge in edges) {
      if (edge.from < 0 ||
          edge.from >= nodes.length ||
          edge.to < 0 ||
          edge.to >= nodes.length) {
        continue;
      }
      adjacency[edge.from].add(edge.to);
      adjacency[edge.to].add(edge.from);
    }

    final allMovable = List<int>.generate(nodes.length, (i) => i)
      ..removeWhere(_pinnedNodeIndexes.contains);
    if (allMovable.isEmpty) return;

    final unvisitedMovable = allMovable.toSet();
    final visitedAll = <int>{};
    final components = <({List<int> movable, List<int> pinned})>[];

    for (final start in allMovable) {
      if (!unvisitedMovable.contains(start)) continue;

      final queue = ListQueue<int>()..add(start);
      final componentAll = <int>{};

      while (queue.isNotEmpty) {
        final current = queue.removeFirst();
        if (visitedAll.contains(current)) continue;
        visitedAll.add(current);
        componentAll.add(current);

        for (final next in adjacency[current].toList()..sort()) {
          if (!visitedAll.contains(next)) queue.add(next);
        }
      }

      final compMovable =
          componentAll.where((i) => !_pinnedNodeIndexes.contains(i)).toList()
            ..sort();
      final compPinned =
          componentAll.where((i) => _pinnedNodeIndexes.contains(i)).toList()
            ..sort();

      if (compMovable.isNotEmpty) {
        unvisitedMovable.removeAll(compMovable);
        components.add((movable: compMovable, pinned: compPinned));
      }
    }

    var clusterRow = 0;
    var clusterCol = 0;
    const clustersPerRow = 4;
    const clusterStepX = 950.0;
    const clusterStepY = 700.0;
    const localStepX = 260.0;
    const localStepY = 180.0;

    for (final component in components) {
      final movable = component.movable;
      final pinned = component.pinned;
      final order = _buildComponentTraversalOrder(
        movable: movable,
        pinned: pinned,
        adjacency: adjacency,
      );

      Offset anchor;
      if (pinned.isNotEmpty) {
        var sumX = 0.0;
        var sumY = 0.0;
        for (final i in pinned) {
          sumX += nodes[i].x;
          sumY += nodes[i].y;
        }
        anchor = Offset(sumX / pinned.length, sumY / pinned.length + 180);
      } else {
        anchor = Offset(
          120 + clusterCol * clusterStepX,
          120 + clusterRow * clusterStepY,
        );
        clusterCol++;
        if (clusterCol >= clustersPerRow) {
          clusterCol = 0;
          clusterRow++;
        }
      }

      final colCount = max(2, sqrt(order.length).ceil());
      for (var i = 0; i < order.length; i++) {
        final idx = order[i];
        final col = i % colCount;
        final row = i ~/ colCount;
        final x = anchor.dx + (col - (colCount - 1) / 2) * localStepX;
        final y = anchor.dy + row * localStepY;
        nodes[idx].x = x.clamp(0.0, areaWidth);
        nodes[idx].y = y.clamp(0.0, areaHeight);
      }
    }
  }

  List<int> _buildComponentTraversalOrder({
    required List<int> movable,
    required List<int> pinned,
    required List<Set<int>> adjacency,
  }) {
    final componentSet = <int>{...movable, ...pinned};
    final movableSet = movable.toSet();
    final roots = pinned.isNotEmpty ? pinned.toList() : [movable.first];

    final visited = <int>{};
    final queue = ListQueue<int>();
    for (final root in roots) {
      if (componentSet.contains(root)) queue.add(root);
    }

    final ordered = <int>[];
    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (!visited.add(current)) continue;
      if (movableSet.contains(current)) {
        ordered.add(current);
      }

      final nextNodes = adjacency[current].where(componentSet.contains).toList()
        ..sort();
      for (final next in nextNodes) {
        if (!visited.contains(next)) queue.add(next);
      }
    }

    for (final idx in movable) {
      if (!ordered.contains(idx)) ordered.add(idx);
    }
    return ordered;
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

  void _fitToScreen() {
    if (!mounted || nodes.isEmpty) return;
    final size = (context.findRenderObject() as RenderBox?)?.size;
    if (size == null || size.isEmpty) return;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final node in nodes) {
      if (node.x < minX) minX = node.x;
      if (node.y < minY) minY = node.y;
      final nx = node.x + node.width;
      final ny = node.y + node.height;
      if (nx > maxX) maxX = nx;
      if (ny > maxY) maxY = ny;
    }

    const padding = 60.0;
    minX -= padding;
    minY -= padding;
    maxX += padding;
    maxY += padding;

    final contentW = maxX - minX;
    final contentH = maxY - minY;
    if (contentW <= 0 || contentH <= 0) return;

    final scale = min(
      size.width / contentW,
      size.height / contentH,
    ).clamp(0.1, 1.0);
    final translateX = padding - minX * scale;
    final translateY = padding - minY * scale;

    _transformController.value = Matrix4.identity()
      ..translate(translateX, translateY)
      ..scale(scale);
  }

  @override
  void dispose() {
    _layoutDebounce?.cancel();
    timer.cancel();
    _transformController.dispose();
    super.dispose();
  }

  double k = 5000; // Constante de force de répulsion

  void _applyForces() {
    const double springLength = 300; // Longueur naturelle des ressorts
    const double damping =
        0.6; // Amortissement réduit pour meilleure séparation

    for (var node in nodes) {
      node.dx = 0;
      node.dy = 0;
    }

    doReplusion(k);
    k = k * 0.98; // Diminue plus lentement la force de répulsion
    if (k < 100) {
      k = 100; // Maintient une répulsion minimale constante
    }

    for (var edge in edges) {
      springNode(edge, springLength);
    }

    for (var node in nodes) {
      node.x = (node.x + node.dx * damping).clamp(0.0, areaWidth);
      node.y = (node.y + node.dy * damping).clamp(0.0, areaHeight);
    }

    setState(() {});
  }

  void doReplusion(double k) {
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        var dx =
            (nodes[j].x + (nodes[j].width / 2)) -
            (nodes[i].x + (nodes[i].width / 2));
        var dy =
            (nodes[j].y + (nodes[j].height / 2)) -
            (nodes[i].y + (nodes[i].height / 2));

        // Calcule la distance minimale basée sur les dimensions des nœuds
        var minDist =
            (nodes[i].width / 2) +
            (nodes[j].width / 2) +
            (nodes[i].height / 2) +
            (nodes[j].height / 2);
        var dist = max(minDist + 50, sqrt(dx * dx + dy * dy));

        // Force plus importante si les nœuds sont trop proches
        var force = k / max(1.0, dist * dist * 0.5);
        var fx = (force * dx) / dist;
        var fy = (force * dy) / dist;

        nodes[i].dx -= fx;
        nodes[i].dy -= fy;
        nodes[j].dx += fx;
        nodes[j].dy += fy;
      }
    }
  }

  void springNode(Edge edge, double springLength) {
    Node a = nodes[edge.from];
    Node b = nodes[edge.to];
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
      //print("object");
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
                    _userInteracted = true;
                    k = 10000; // Augmente la force de répulsion pendant le déplacement
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
      minScale: 0.05,
      maxScale: 5.0,
      scaleFactor: 5000,
      scaleEnabled: scaleEnabled,
      transformationController: _transformController,
      child: stack!,
    );
    return Stack(
      children: [
        interactiveViewer,
        Positioned(
          left: 0,
          top: 0,
          child: ElevatedButton(
            onPressed: savePosition,
            child: Text('Save Positions'),
          ),
        ),
      ],
    );
  }
}
