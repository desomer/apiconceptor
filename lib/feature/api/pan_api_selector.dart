import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/pan_attribut_editor.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/tree_editor/pan_yaml_tree.dart';
import 'package:jsonschema/widget/tree_editor/tree_view.dart';
import 'package:jsonschema/widget/widget_version_state.dart';

// ignore: must_be_immutable
class PanAPISelector extends PanYamlTree {
  PanAPISelector({super.key, required super.getSchemaFct});

  @override
  void addRowWidget(
    TreeNodeData<NodeAttribut> node,
    ModelSchema schema,
    List<Widget> row,
    BuildContext context,
  ) {
    var info = node.data.info;
    if (info.type == 'ope') {
      row.add(
        CellEditor(
          inArray: true,
          key: ValueKey(info.numUpdateForKey),
          acces: ModelAccessorAttr(
            node: node.data,
            schema: schema,
            propName: 'summary',
          ),
        ),
      );

      row.add(SizedBox(width: 10));
      row.add(WidgetVersionState(margeVertical: 2));
      row.add(
        TextButton.icon(
          onPressed: () async {
            // await goToAPI(attr, 1, context: context);
          },
          label: Icon(Icons.remove_red_eye),
        ),
      );
      row.add(
        TextButton.icon(
          icon: Icon(Icons.import_export),
          onPressed: () async {
            // await goToAPI(attr, 1, subtabNumber: 2, context: context);
          },
          label: Text('Test fake API'),
        ),
      );
    }
  }

  @override
  Widget? getAttributProperties(BuildContext context) {
    return EditorProperties(
      typeAttr: TypeAttr.api,
      key: keyAttrEditor,
      getModel: () {
        return getSchema();
      },
    );
  }

  @override
  Future<void> onActionRow(
    TreeNodeData<NodeAttribut> node,
    BuildContext context,
  ) async {
    var attr = node.data;
    goToAPI(attr, context: context);
  }

  Future<void> goToAPI(
    NodeAttribut attr, {
    required BuildContext context,
  }) async {
    var sel = getSchema().nodeByMasterId[attr.info.masterID]!;

    if (sel.info.type == 'ope') {
      context.push(Pages.apiDetail.id(sel.info.masterID!));
    }
  }
}
