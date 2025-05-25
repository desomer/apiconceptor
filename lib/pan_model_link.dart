import 'package:flutter/material.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/widget/json_editor/widget_json_row.dart';
import 'package:jsonschema/widget/json_editor/widget_json_tree.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';

// ignore: must_be_immutable
class WidgetModelLink extends StatelessWidget with WidgetModelHelper {
  WidgetModelLink({super.key, required this.listModel});
  final ModelSchemaDetail listModel;

  final GlobalKey keyListModelInfo = GlobalKey();

  @override
  Widget build(BuildContext context) {
    getJsonYaml() {
      return listModel.modelYaml;
    }

    var config =
        JsonTreeConfig(
            textConfig: null,
            getModel: () => listModel,
            onTap: (NodeAttribut node) {
              listModel.changeSelected(node);
              print('tap ${node.hashCode}');
              if (node.info.type == 'model') {
                (listModel.lastJsonBrowser as JsonBrowserWidget).reloadAll(node);
              }
              return true;
            },
          )
          ..getJson = getJsonYaml
          ..getRow = _getJsonRow;

    var modelSelector = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: JsonEditor(key: keyListModelInfo, config: config)),
      ],
    );

    return modelSelector;
  }

  Widget _getJsonRow(NodeAttribut attr, ModelSchemaDetail schema) {
    return WidgetJsonRow(
      key: GlobalKey(),
      node: attr,
      schema: schema,
      fctGetRow: _getWidgetModelInfo,
    );
    // attr.info.cache = WidgetJsonRow(
    //   node: attr,
    //   schema: schema,
    //   fctGetRow: _getWidgetModelInfo,
    // );
    // return attr.info.cache!;
  }

  Widget _getWidgetModelInfo(NodeAttribut attr, ModelSchemaDetail schema) {
    if (attr.info.type == 'root') {
      return Container(height: rowHeight);
    }

    List<Widget> row = [SizedBox(width: 10)];

    if (!(attr.child.firstOrNull?.info.type == "model") &&
        attr.info.type != '\$ref') {
      row.add(
        SizedBox(
          height: 25,
          child: FittedBox(
            fit: BoxFit.fill,
            child: ModelSwitch(
              schema: schema,
              attr: attr,
            ),
          ),
        ),
      );
    }

    var ret = SizedBox(
      height: rowHeight,
      child: Card(margin: EdgeInsets.all(1), child: Row(children: row)),
    );
    return ret;
  }
}

class ModelSwitch extends StatefulWidget {
  const ModelSwitch({
    super.key,
    required this.attr,
    required this.schema,
  });
  final NodeAttribut attr;
  final ModelSchemaDetail schema;

  @override
  State<ModelSwitch> createState() => _ModelSwitchState();
}

class _ModelSwitchState extends State<ModelSwitch> {
  bool selected = false;

  @override
  Widget build(BuildContext context) {
    var v = widget.schema.lastBrowser?.selectedPath?.contains(
      widget.attr.info.path,
    );
    return Switch(
      key: GlobalKey(),
      value: v ?? false,
      onChanged: (value) {
        setState(() {
          widget.schema.changeSelected(widget.attr);
          if (widget.attr.info.type == 'model') {
            (widget.schema.lastJsonBrowser as JsonBrowserWidget).reloadAll(widget.attr);
          }
        });
      },
    );
  }
}
