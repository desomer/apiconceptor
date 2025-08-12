import 'package:flutter/material.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/model/pan_model_editor.dart';
import 'package:jsonschema/feature/pan_attribut_editor_detail.dart';
import 'package:jsonschema/widget/tree_editor/tree_view.dart';

import '../../widget/tree_editor/pan_yaml_tree.dart';

// ignore: must_be_immutable
class PanRequestApi extends PanYamlTree with PanModelEditorHelper {
  PanRequestApi({super.key, required super.getSchemaFct});

  @override
  void addRowWidget(
    TreeNodeData<NodeAttribut> node,
    ModelSchema schema,
    List<Widget> row,
    BuildContext context,
  ) {
    if (node.data.level > 1) {
      addAttributWidget(row, node.data, schema);
    }
  }

  @override
  Future<void> onActionRow(
    TreeNodeData<NodeAttribut> node,
    BuildContext context,
  ) async {
    doShowAttrEditor(node.data);
  }

  @override
  Widget? getAttributProperties(BuildContext context) {
    return AttributProperties(
      typeAttr: TypeAttr.detailapi,
      key: keyAttrEditor,
      getModel: () {
        return getSchema();
      },
    );
  }
}
