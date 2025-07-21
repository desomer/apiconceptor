import 'package:animated_tree_view/tree_view/tree_node.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/repaint_manager.dart';
import 'package:jsonschema/feature/api/pan_api_editor.dart';
import 'package:jsonschema/widget/json_editor/pan_yaml_tree.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/widget_state/state_api.dart';

// ignore: must_be_immutable
class PanApiExample extends PanYamlTree {
  PanApiExample({
    required this.apiCallInfo,
    super.key,
    required super.getSchemaFct,
  });
  final APICallInfo apiCallInfo;

  @override
  void onInit() {
    repaintManager.addTag(ChangeTag.apichange, "PanApiExample", null, () {
      return false;
    });
  }

  @override
  Future<void> goToModel(NodeAttribut attr, int tabNumber) async {
    apiCallInfo.selectedExample = attr;
    var jsonParam = await bddStorage.getAPIParam(
      apiCallInfo.currentAPI!,
      attr.info.masterID!,
    );
    apiCallInfo.params.clear();
    apiCallInfo.body;
    apiCallInfo.bodyStr = '';

    if (jsonParam != null) {
      apiCallInfo.initWithJson(jsonParam);
    }
    repaintManager.doRepaint(ChangeTag.apiparam);
    stateApi.tabSubApi.animateTo(2);
  }
}

class InfoManagerApiExample extends InfoManager with WidgetModelHelper {
  @override
  void getAttributRow(NodeAttribut attr, ModelSchema schema, List<Widget> row) {
    row.add(Text('link to call api'));
  }

  @override
  Widget getAttributHeader(TreeNode<NodeAttribut> node) {
    return getChip(Text(node.data!.info.name), color: null);
  }

  @override
  String getTypeTitle(NodeAttribut node, String name, type) {
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
}
