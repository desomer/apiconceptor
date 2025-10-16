import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/api/pan_api_import.dart';
import 'package:jsonschema/feature/pan_attribut_editor.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/tree_editor/pan_yaml_tree.dart';
import 'package:jsonschema/widget/tree_editor/tree_view.dart';
import 'package:jsonschema/widget/widget_version_state.dart';

// ignore: must_be_immutable
class PanAPISelector extends PanYamlTree {
  PanAPISelector({
    required this.onSelModel,
    required this.browseOnly,
    super.key,
    required super.getSchemaFct,
  });

  final bool browseOnly;
  final Function? onSelModel;

  @override
  bool withEditor() {
    return !browseOnly;
  }

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
          key: ValueKey('${info.name}%${info.numUpdateForKey}'),
          acces: ModelAccessorAttr(
            node: node.data,
            schema: schema,
            propName: 'summary',
          ),
        ),
      );

      row.add(SizedBox(width: 10));
      row.add(
        WidgetVersionState(margeVertical: 2, version: null),
      );
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
      if (onSelModel != null) {
        onSelModel!(sel.info.masterID!);
      } else {
        context.push(Pages.apiDetail.id(sel.info.masterID!));
      }
    }
  }

  Future<void> showImportDialog(BuildContext ctx) async {
    return showDialog<void>(
      context: ctx,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return PanAPIImport(yamlEditorConfig: getYamlConfig());
      },
    );
  }
}
