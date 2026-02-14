import 'package:animated_tree_view/tree_view/tree_node.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/widget/tree_editor/tree_view.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';

import '../../widget/tree_editor/pan_yaml_tree.dart';

// ignore: must_be_immutable
class PanDestSelector extends PanYamlTree {
  PanDestSelector({super.key, required super.getSchemaFct, super.showable});

  @override
  bool isReadOnly() {
    return true;
  }

  @override
  bool withEditor() {
    return false;
  }
}

class InfoManagerDest extends InfoManager with WidgetHelper {
  @override
  void addRowWidget(
    NodeAttribut attr,
    ModelSchema schema,
    List<Widget> row,
    BuildContext context,
  ) {
    row.add(Text('link to call api'));
  }

  @override
  Widget getAttributHeaderOLD(TreeNode<NodeAttribut> node) {
    return getChip(Text(node.data!.info.name), color: null);
  }

  @override
  String getTypeTitle(NodeAttribut node, String name, type) {
    if (type is Map) {
      return 'object';
    }
    return '$type';
  }

  @override
  InvalidInfo? isTypeValid(
    NodeAttribut nodeAttribut,
    String name,
    type,
    String typeTitle,
  ) {
    return null;
  }

  @override
  Widget getRowHeader(TreeNodeData<NodeAttribut> node, BuildContext context) {
    // TODO: implement getRowHeader
    throw UnimplementedError();
  }
}
