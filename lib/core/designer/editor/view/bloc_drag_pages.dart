import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_drag_utils.dart';
import 'package:jsonschema/widget/tree_editor/tree_view.dart';

class WidgetPages extends StatefulWidget {
  const WidgetPages({super.key, required this.factory});
  final WidgetFactory factory;

  @override
  State<WidgetPages> createState() => _WidgetPagesState();
}

class _WidgetPagesState extends State<WidgetPages> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsGeometry.fromLTRB(5, 5, 0, 5),
      child: getTree(context),
    );
  }

  TreeNodeData<Map<String, dynamic>>? nodes;

  Widget getTree(BuildContext context) {
    return TreeView<Map<String, dynamic>>(
      key: widget.factory.keyPagesViewer,
      isSelected: (node, cur, old) {
        return node.data['selected'] == true;
      },
      onBuild: (state, ctx) {},
      getNodes: () {
        nodes = getNodes();
        return TreeViewData(nodes: [nodes!], headerSize: 100);
      },
      getHeader: (node) {
        Widget row;
        if (node.data['status'] == 'C') {
          row = Row(
            spacing: 10,
            children: [
              const Icon(Icons.drag_indicator, size: 18, color: Colors.grey),
              Expanded(child: getEmptyRouteWidget(node.data)),
            ],
          );
        } else {
          row = Row(
            spacing: 10,
            children: [
              if (node.data['icon'] != null) Icon(node.data['icon'], size: 18),
              if (node.data['dragType'] != null)
                const Icon(Icons.drag_indicator, size: 18, color: Colors.grey),
              Text(node.data['name'] ?? 'No id'),
            ],
          );
        }
        return Draggable<DragNewComponentCtx>(
          data: DragNewComponentCtx(
            idComponent: 'action',
            config: {
              'type': 'route',
              'path': node.data['path'],
              'data': node.data,
            },
          ),
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: SizedBox(
            height: 30,
            width: 200,
            child: Material(child: row),
          ),
          child: row,
        );
      },
      getDataRow: (node) {
        return InkWell(
          onTap: () {
            node.data['selected'] =
                node.data['selected'] == true ? false : true;

            int idcache = node.data['intCache'] ?? 0;
            node.data['intCache'] = idcache + 1;

            widget.factory.keyPagesViewer.currentState?.doTapHeader(node);
          },
          child: Text(node.data['status'] ?? '?'),
        );
      },
      onTapHeader: (node, ctx) async {
        print('tap on ${node.data['name']}');
      },
      isRowCached: (node) {
        return node.data['intCache'] ?? 0;
      },
    );
  }

  TreeNodeData<Map<String, dynamic>> getNodes() {
    var dialog = TreeNodeData<Map<String, dynamic>>(
      data: {
        'status': 'R',
        'name': 'Dialogs',
        'icon': Icons.contact_phone_outlined,
      },
      children: [getEmptyRoute(dragType: null)],
    );
    var documents = TreeNodeData<Map<String, dynamic>>(
      data: {'status': 'R', 'name': 'Documents', 'icon': Icons.picture_as_pdf},
      children: [
        TreeNodeData<Map<String, dynamic>>(
          data: {'status': 'R', 'name': 'Pdf', 'icon': Icons.picture_as_pdf},
        ),
        TreeNodeData<Map<String, dynamic>>(
          data: {'status': 'R', 'name': 'Mail (Html)', 'icon': Icons.mail},
        ),
      ],
    );

    Map<String, dynamic> listRoutes = widget.factory.appData[cwApp]![cwSlots];
    List<TreeNodeData<Map<String, dynamic>>> routeNodes = [];
    for (var routeEntry in listRoutes.entries) {
      var route = routeEntry.value;
      if (routeEntry.key == '/') {
        continue;
      }
      routeNodes.add(
        TreeNodeData<Map<String, dynamic>>(
          data: {
            'status': 'R',
            //'icon': Icons.route,
            'dragType': 'route',
            'name': route['name'],
            'path': route['path'],
            cwRouteId: route['uid'],
          },
        ),
      );
    }
    routeNodes.add(getEmptyRoute(dragType: null));

    var main = TreeNodeData<Map<String, dynamic>>(
      data: {'status': 'R', 'name': 'Application'},
      children: [
        TreeNodeData<Map<String, dynamic>>(
          data: {
            'status': 'R',
            'icon': Icons.pages,
            'dragType': 'page',

            cwRouteName: 'Home',
            cwRoutePath: '/',
            cwRouteId: '/',
          },
          children: routeNodes,
        ),
        dialog,
        documents,
      ],
    );
    return main;
  }

  Widget getEmptyRouteWidget(Map<String, dynamic> node) {
    return Row(
      children: [
        if (node['dragType'] != null) Icon(Icons.drag_indicator, size: 18),
        Container(
          width: 50,
          padding: EdgeInsets.all(3),
          child: DottedBorder(
            options: RectDottedBorderOptions(
              padding: EdgeInsets.zero,
              color: Colors.grey,
              dashPattern: [5, 5],
              strokeWidth: 1,
            ),
            child: Center(
              child: Text('+', style: TextStyle(color: Colors.grey)),
            ),
          ),
        ),
        Spacer(),
      ],
    );
  }

  TreeNodeData<Map<String, dynamic>> getEmptyRoute({String? dragType}) =>
      TreeNodeData<Map<String, dynamic>>(
        data: {'status': 'C', if (dragType != null) 'dragType': dragType},
      );
}
