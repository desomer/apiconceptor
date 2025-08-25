import 'package:animated_tree_view/tree_view/tree_node.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/repaint_manager.dart';
import 'package:jsonschema/feature/api/api_widget_request_helper.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/tree_editor/pan_yaml_tree.dart';
import 'package:jsonschema/widget/tree_editor/tree_view.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/widget/widget_overflow.dart';
import 'package:jsonschema/widget/widget_version_state.dart';

enum ModeExample { design, browse }

class ExampleConfig {
  final ModeExample mode;
  final Function onSelect;

  ExampleConfig({required this.onSelect, required this.mode});
}

// ignore: must_be_immutable
class PanApiExample extends PanYamlTree {
  PanApiExample({
    required this.config,
    required this.requesthelper,
    super.key,
    required super.getSchemaFct,
  });
  final WidgetRequestHelper requesthelper;
  final ExampleConfig config;

  @override
  bool withEditor() {
    return config.mode == ModeExample.design;
  }

  @override
  void onInit(BuildContext context) {
    repaintManager.addTag(ChangeTag.apichange, "PanApiExample", null, () {
      return false;
    });
  }

  @override
  void addRowWidget(
    TreeNodeData<NodeAttribut> node,
    ModelSchema schema,
    List<Widget> row,
    BuildContext context,
  ) {
    var info = node.data.info;
    if (info.type == 'example') {
      row.add(
        CellEditor(
          inArray: true,
          key: ValueKey(info.numUpdateForKey),
          acces: ModelAccessorAttr(
            node: node.data,
            schema: schema,
            propName: 'summary',
            editable: config.mode == ModeExample.design,
          ),
        ),
      );

      if (config.mode == ModeExample.design) {
        row.add(SizedBox(width: 10));
        row.add(WidgetVersionState(margeVertical: 2));
        row.add(
          TextButton.icon(
            icon: Icon(Icons.import_export),
            onPressed: () async {
              // await goToAPI(attr, 1, subtabNumber: 2, context: context);
            },
            label: Text('Test API'),
          ),
        );
      }
    }
  }

  @override
  Future<void> onActionRow(
    TreeNodeData<NodeAttribut> node,
    BuildContext context,
  ) async {
    var attr = node.data;
    requesthelper.apiCallInfo.selectedExample = attr.info;
    var jsonParam = await bddStorage.getAPIParam(
      requesthelper.apiCallInfo.currentAPIRequest!,
      attr.info.masterID!,
    );

    requesthelper.apiCallInfo.clearRequest();

    if (jsonParam != null) {
      requesthelper.apiCallInfo.initWithParamJson(jsonParam);
    }
    repaintManager.doRepaint(ChangeTag.apiparam);

    config.onSelect();

    requesthelper.changeUrl.value++;
    requesthelper.changeScript.value++;
  }
}

class InfoManagerApiExample extends InfoManager with WidgetHelper {
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
  Widget getRowHeader(TreeNodeData<NodeAttribut> node) {
    Widget? icon;
    var isRoot = node.isRoot;
    var isFolder = node.data.info.type == 'folder';
    var iExample = node.data.info.type == 'example';

    String name = node.data.info.name;

    if (isRoot) {
      icon = Icon(Icons.business);
      name = getKeyParamFromYaml(node.data.yamlNode.key);
    } else if (isFolder) {
      icon = Icon(Icons.folder);
    } else if (iExample) {
      icon = Icon(Icons.dataset_linked);
    }

    return NoOverflowErrorFlex(
      direction: Axis.horizontal,
      children: [
        if (icon != null)
          Padding(padding: const EdgeInsets.fromLTRB(0, 0, 5, 0), child: icon),

        Expanded(
          child: InkWell(
            onTap: () {
              node.doTapHeader();
            },
            child: NoOverflowErrorFlex(
              direction: Axis.horizontal,
              children: [
                Text(name),
                Spacer(),
                getWidgetType(node.data, iExample, isRoot),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget getWidgetType(NodeAttribut attr, bool iExample, bool isRoot) {
    if (isRoot) return Container();

    bool hasError = attr.info.error?[EnumErrorType.errorRef] != null;
    hasError = hasError || attr.info.error?[EnumErrorType.errorType] != null;
    String msg = hasError ? 'string\nnumber\nboolean\n\$type' : '';

    return Tooltip(
      message: msg,
      child: getChip(
        iExample
            ? Row(
              spacing: 5,
              children: [
                Text(attr.info.type),
                Icon(Icons.arrow_forward_ios, size: 10),
              ],
            )
            : Text(attr.info.type),
        color: hasError ? Colors.redAccent : (iExample ? Colors.blue : null),
      ),
    );
  }
}
