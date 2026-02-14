import 'package:animated_tree_view/tree_view/tree_node.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/list_editor/widget_list_editor.dart';
import 'package:jsonschema/widget/tree_editor/tree_view.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';

class PanApiEnv extends StatelessWidget {
  const PanApiEnv({super.key});

  @override
  Widget build(BuildContext context) {
    return WidgetListEditor(model: currentCompany.listEnv, change: ValueNotifier(0));
  }
}

//-------------------------------------------------------------
class InfoManagerEnv extends InfoManager with WidgetHelper {
  @override
  void addRowWidget(
    NodeAttribut attr,
    ModelSchema schema,
    List<Widget> row,
    BuildContext context,
  ) {
    row.add(
      CellEditor(
        inArray: true,
        key: ValueKey(attr.info.numUpdateForKey),
        acces: ModelAccessorAttr(node: attr, schema: schema, propName: 'title'),
      ),
    );
  }

  @override
  Widget getAttributHeaderOLD(TreeNode<NodeAttribut> node) {
    throw UnimplementedError();
  }

  @override
  String getTypeTitle(NodeAttribut node, String name, dynamic type) {
    return type.toString();
  }

  @override
  InvalidInfo? isTypeValid(
    NodeAttribut nodeAttribut,
    String name,
    type,
    String typeTitle,
  ) {
    return null; // No specific validation for environment variables
  }

  @override
  Widget getRowHeader(TreeNodeData<NodeAttribut> node, BuildContext context) {
    // TODO: implement getRowHeader
    throw UnimplementedError();
  }
}
