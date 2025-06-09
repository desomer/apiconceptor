import 'package:flutter/material.dart';
import 'package:highlight/languages/yaml.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/editor/cell_prop_editor.dart';
import 'package:jsonschema/editor/code_editor.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/feature/pan_attribut_editor.dart';
import 'package:jsonschema/widget/json_editor/widget_json_tree.dart';
import 'package:jsonschema/widget/widget_hidden_box.dart';
import 'package:jsonschema/widget/widget_hover.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget/widget_tab.dart';

// ignore: must_be_immutable
class PanResponseApi extends StatelessWidget with WidgetModelHelper {
  PanResponseApi({super.key, required this.response});

  final ValueNotifier<double> showAttrEditor = ValueNotifier(0);
  late TextConfig textConfig;
  final GlobalKey keyApiYamlEditor = GlobalKey();
  final GlobalKey keyApiTreeEditor = GlobalKey();
  final GlobalKey keyAttrEditor = GlobalKey();
  final ModelSchemaDetail? response;

  State? rowSelected;

  @override
  Widget build(BuildContext context) {
    void onYamlChange(String yaml, TextConfig config) {
      if (response == null) return;

      var modelSchemaDetail = response!;
      if (modelSchemaDetail.modelYaml != yaml) {
        modelSchemaDetail.modelYaml = yaml;

        modelSchemaDetail.doChangeYaml(config, true, 'change');
      }
    }

    getYaml() {
      return response!.modelYaml;
    }

    textConfig = TextConfig(
      mode: yaml,
      notifError: notifierErrorYaml,
      onChange: onYamlChange,
      getText: getYaml,
    );

    return WidgetTab(
      listTab: [
        Tab(text: 'Responses code'),
        Tab(text: 'Version'),
      ],
      listTabCont: [
        Row(
          children: [
            SizedBox(width: 350, child: _getYamlParam()),
            Expanded(child: _getTreeEditor()),
          ],
        ),
        Container(),
      ],
      heightTab: 40,
    );
  }

  Widget _getYamlParam() {
    return Container(
      color: Colors.black,
      child: TextEditor(
        header: "200, 404",
        key: keyApiYamlEditor,
        config: textConfig,
      ),
    );
  }


  Widget _getTreeEditor() {
    getJsonYaml() {
      return response!.mapModelYaml; //currentCompany.currentModel!.mapModelYaml;
    }

    return Row(
      children: [
        Expanded(
          child: JsonEditor(
            key: keyApiTreeEditor,
            config:
                JsonTreeConfig(
                    textConfig: textConfig,
                    getModel: () {
                      return response;
                    },
                    onTap: (NodeAttribut node) {
                      // doShowAttrEditor(currentCompany.currentModel!, node);
                    },
                  )
                  ..getJson = getJsonYaml
                  ..getRow = _getRowsAttrInfo,
          ),
        ),
        WidgetHiddenBox(
          showNotifier: showAttrEditor,
          child: AttributProperties(
            typeAttr: TypeAttr.api,
            key: keyAttrEditor,
            getModel: () {
              return response;
            },
          ),
        ),
      ],
    );
  }

  Widget _getRowsAttrInfo(NodeAttribut attr, ModelSchemaDetail schema) {
    if (attr.info.type == 'root' || attr.level < 2) {
      return Container(height: rowHeight);
    }

    List<Widget> rowWidget = [SizedBox(width: 10)];
    rowWidget.add(
      CellEditor(
        key: ValueKey('${attr.hashCode}#title'),
        acces: ModelAccessorAttr(
          node: attr,
          schema: response!,
          propName: 'title',
        ),
        inArray: true,
      ),
    );

    bool minmax =
        (attr.info.properties?['minimum'] != null) ||
        (attr.info.properties?['maximun'] != null) ||
        (attr.info.properties?['minLength'] != null) ||
        (attr.info.properties?['maxLength'] != null);

    rowWidget.addAll(<Widget>[
      SizedBox(width: 10),
      if (attr.info.properties?['required'] != null)
        Icon(Icons.check_circle_outline),
      if (attr.info.properties?['const'] != null)
        getChip(Text('const'), color: null),
      if (attr.info.properties?['enum'] != null) Icon(Icons.checklist),
      if (attr.info.properties?['pattern'] != null)
        getChip(Text('regex'), color: null),
      if (minmax) Icon(Icons.tune),
      Spacer(),
      getChip(
        Row(children: [Icon(Icons.warning_amber, size: 20), Text('Glossary')]),
        color: Colors.red,
      ),
    ]);

    // row.add(getChip(Text(attr.info.treePosition ?? ''), color: null));
    // row.add(getChip(Text(attr.info.path), color: null));
    // addWidgetMasterId(attr, row);

    return SizedBox(
      height: rowHeight,
      child: InkWell(
        onTap: () {
          doShowAttrEditor(schema, attr);
          //bool isSelected = schema.currentAttr == attr.info;
          if (rowSelected?.mounted == true) {
            // ignore: invalid_use_of_protected_member
            rowSelected?.setState(() {});
          }
        },
        child: HoverableCard(
          isSelected: (State state) {
            attr.widgetSelectState = state;
            bool isSelected = schema.currentAttr == attr;
            if (isSelected) {
              rowSelected = state;
            }
            return isSelected;
            // bool isSelected = schema.currentAttr == attr;
            // if (isSelected) {
            //   var repaint = rowSelected;
            //   WidgetsBinding.instance.addPostFrameCallback((_) {
            //     // ignore: invalid_use_of_protected_member
            //     repaint?.setState(() {});
            //   });
            //   rowSelected = state;
            // }
            // return isSelected;
          },
          key: ObjectKey(attr),
          //margin: EdgeInsets.all(1),
          child: Row(spacing: 5, children: rowWidget),
        ),
      ),
    );
  }

  void doShowAttrEditor(ModelSchemaDetail schema, NodeAttribut attr) {
    schema.currentAttr = attr;
    // ignore: invalid_use_of_protected_member
    keyAttrEditor.currentState?.setState(() {});
    showAttrEditor.value = 300;
  }
}
