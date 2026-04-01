import 'package:flutter/material.dart';
import 'package:jsonschema/core/export/export2json_fake.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/transform/pan_response_mapper.dart';
import 'package:jsonschema/widget/tree_editor/tree_view.dart';

import '../../widget/tree_editor/pan_yaml_tree.dart';

// ignore: must_be_immutable
class PanDestSelector extends PanYamlTree with WidgetModelViewerHelper {
  PanDestSelector({
    super.key,
    required super.getSchemaFct,
    super.showable,
    this.onSelected,
    this.onMapping,
  });
  final Function(NodeAttribut)? onSelected;
  final Function(Map<String, dynamic>?)? onMapping;

  @override
  bool isReadOnly() {
    return true;
  }

  @override
  bool canDrag(TreeNodeData<NodeAttribut> node) {
    return true;
  }

  @override
  bool withEditor() {
    return false;
  }

  @override
  dynamic initSchema() {
    ModelSchema m = getSchemaFct();
    var exportFake = Export2FakeJson(
      modeArray: ModeArrayEnum.anyInstance,
      mode: ModeEnum.fake,
      propMode: PropertyRequiredEnum.all,
      config: BrowserConfig(isApi: m.readOnly != null),
    )..browse(m, false);
    jsonToDisplay = exportFake.json;
    onMapping?.call(jsonToDisplay);
    return m;
  }

  String lastJsonPath = '';
  int lastJsonSelectTime = 0;

  @override
  void doSelectedRow(NodeAttribut attr, bool withNode) {
    print("selected ${attr.info.name}");
    var jsonPath = attr.info.getJsonPath();
    var time = DateTime.now().millisecondsSinceEpoch;
    if (jsonPath == lastJsonPath) {
      if (time - lastJsonSelectTime < 500) {
        // double click
        print('double click on $jsonPath');
        onSelected?.call(attr);
      }
    }
    lastJsonSelectTime = time;
    lastJsonPath = jsonPath;
  }

  @override
  void addRowWidget(
    TreeNodeData<NodeAttribut> node,
    ModelSchema schema,
    List<Widget> row,
    BuildContext context,
  ) {
    var attr = node.data;
    return addViewWidget(attr, row);
  }
}

// class InfoManagerDest extends InfoManager with WidgetHelper {
//   @override
//   void addRowWidget(
//     NodeAttribut attr,
//     ModelSchema schema,
//     List<Widget> row,
//     BuildContext context,
//   ) {
//     row.add(Text('link to call api'));
//   }

//   @override
//   Widget getAttributHeaderOLD(TreeNode<NodeAttribut> node) {
//     return getChip(Text(node.data!.info.name), color: null);
//   }

//   @override
//   String getTypeTitle(NodeAttribut node, String name, type) {
//     if (type is Map) {
//       return 'object';
//     }
//     return '$type';
//   }

//   @override
//   InvalidInfo? isTypeValid(
//     NodeAttribut nodeAttribut,
//     String name,
//     type,
//     String typeTitle,
//   ) {
//     return null;
//   }

//   @override
//   Widget getRowHeader(TreeNodeData<NodeAttribut> node, BuildContext context) {
//     // TODO: implement getRowHeader
//     throw UnimplementedError();
//   }
// }
