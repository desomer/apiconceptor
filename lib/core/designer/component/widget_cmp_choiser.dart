import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/core/widget_drag_utils.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/start_core.dart';

class WidgetChoiser extends StatefulWidget {
  const WidgetChoiser({super.key});

  @override
  State<WidgetChoiser> createState() => _WidgetChoiserState();
}

class _WidgetChoiserState extends State<WidgetChoiser> {
  @override
  Widget build(BuildContext context) {
    final jsonData = [
      {
        "id": "Simple",
        "name": "Simple",
        "icon": Icons.folder,
        "children": [
          {"id": "input", "name": "Title, Label", "icon": Icons.title},
          {
            "id": "action",
            "name": "Button, Action, Link",
            "icon": Icons.smart_button_rounded,
          },
        ],
      },
      {
        "id": "Layout",
        "name": "Layout",
        "icon": Icons.folder,
        "children": [
          {
            "id": "container",
            "name": "Row, Column",
            "icon": Icons.grid_on_rounded,
          },
          {
            "id": "tabbar",
            "name": "Tab, NavBar, Button Bar",
            "icon": Icons.tab,
          },
          {"id": "menu", "name": "Menu, Popup Menu", "icon": Icons.menu},
        ],
      },
    ];

    var dataSource = loadDataSource("all", false);

    return FutureBuilder(
      future: dataSource,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data == null) {
          return const Center(child: Text('No data available'));
        } else {
          var ds = snapshot.data as ModelSchema;
          var b = BrowseSingle();
          b.browse(ds, false);
          var j = b.root;
          var listDataSource = <Map<String, dynamic>>[];
          for (var i = 0; i < j.length; i++) {
            listDataSource.add({ "id": "ds_${j[i].info.masterID}", "name": j[i].info.name, "icon": Icons.storage,});
          }
          jsonData.add({
            "id": "DataSource",
            "name": "Data Source",
            "icon": Icons.folder,
            "children": listDataSource,
          });
          final nodes = jsonData.map((e) => Node.fromJson(e)).toList();
          return NodeTree(nodes: nodes);
        }
      },
    );
  }
}

/// Modèle de noeud
class Node {
  final String id;
  final String name;
  final IconData icon;
  final List<Node> children;

  Node({
    required this.id,
    required this.name,
    required this.icon,
    this.children = const [],
  });

  /// Factory pour construire depuis un JSON
  factory Node.fromJson(Map<String, dynamic> json) {
    return Node(
      id: json['id'],
      name: json['name'],
      icon: json['icon'],
      children:
          (json['children'] as List<dynamic>? ?? [])
              .map((child) => Node.fromJson(child))
              .toList(),
    );
  }
}

/// Widget récursif
class NodeTree extends StatelessWidget {
  final List<Node> nodes;

  const NodeTree({super.key, required this.nodes});

  @override
  Widget build(BuildContext context) {
    return ListView(children: nodes.map((node) => _buildNode(node)).toList());
  }

  Widget _buildNode(Node node) {
    if (node.children.isEmpty) {
      return Draggable<DragNewComponentCtx>(
        data: DragNewComponentCtx(idComponent: node.id),
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: SizedBox(
          width: 250,
          height: 40,
          child: Material(
            child: ListTile(
              dense: true,
              leading: Icon(node.icon),
              title: Text(node.name),
            ),
          ),
        ),
        child: ListTile(
          dense: true,
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              Icon(Icons.drag_indicator, color: Colors.grey),
              Icon(node.icon),
            ],
          ),
          title: Text(node.name),
        ),
      );
    } else {
      return ExpansionTile(
        dense: true,
        initiallyExpanded: true,
        leading: Icon(node.icon),
        title: Text(node.name),
        children: node.children.map((child) => _buildNode(child)).toList(),
      );
    }
  }
}
