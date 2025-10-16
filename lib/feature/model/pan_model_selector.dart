import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/model/pan_model_import_dialog.dart';
import 'package:jsonschema/feature/pan_attribut_editor.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/widget/tree_editor/pan_yaml_tree.dart';
import 'package:jsonschema/widget/tree_editor/tree_view.dart';
import 'package:jsonschema/widget/widget_version_state.dart';

// ignore: must_be_immutable
class PanModelSelector extends PanYamlTree {
  PanModelSelector({super.key, required super.getSchemaFct});

  @override
  void addRowWidget(
    TreeNodeData<NodeAttribut> node,
    ModelSchema schema,
    List<Widget> row,
    BuildContext context,
  ) {
    var attr = node.data;

    if (attr.info.type == 'root') {
      row.add(Container(height: rowHeight));
      return;
    }

    // row.add(SizedBox(width: 10));
    row.add(
      CellEditor(
        inArray: true,
        key: ValueKey('${attr.info.name}%${attr.info.numUpdateForKey}'),
        acces: ModelAccessorAttr(node: attr, schema: schema, propName: 'title'),
      ),
    );

    //addWidgetMasterId(attr, row);

    if (attr.info.type == 'model') {
      row.add(SizedBox(width: 10));
      row.add(
        WidgetVersionState(
          margeVertical: 2,
          version: null,
          model: getSchema(),
          attr: attr,
        ),
      );
      row.add(
        Padding(
          padding: EdgeInsetsGeometry.fromLTRB(5, 0, 0, 0),
          child: getChip(
            Text(attr.info.properties?['#version'] ?? ''),
            color: null,
          ),
        ),
      );
      row.add(
        TextButton.icon(
          onPressed: () async {
            node.doTapHeader();
          },
          label: Icon(Icons.remove_red_eye),
        ),
      );
      row.add(
        TextButton.icon(
          icon: Icon(Icons.import_export),
          onPressed: () async {
            if (attr.info.type == 'model') {
              var key = attr.info.properties![constMasterID];

              // ignore: use_build_context_synchronously
              context.push(Pages.modelJsonSchema.id(key));
            }
          },
          label: Text('Json schemas'),
        ),
      );
    }
  }

  @override
  Future<void> onActionRow(
    TreeNodeData<NodeAttribut> node,
    BuildContext context,
  ) async {
    var attr = node.data;
    if (attr.info.type == 'model') {
      var key = attr.info.properties![constMasterID];

      // ignore: use_build_context_synchronously
      context.push(Pages.modelDetail.id(key));

      //context.push(Pages.modelDetail.url);
    } else {
      node.doToogleChild();
    }
  }

  @override
  Widget? getAttributProperties(BuildContext context) {
    return EditorProperties(
      typeAttr: TypeAttr.model,
      key: keyAttrEditor,
      getModel: () {
        return getSchema();
      },
    );
  }

  Future<void> showImportDialog(BuildContext ctx) async {
    return showDialog<void>(
      context: ctx,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return PanModelImportDialog(yamlEditorConfig: getYamlConfig());
      },
    );
  }
}
