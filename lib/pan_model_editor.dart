import 'package:flutter/material.dart';
import 'package:highlight/languages/yaml.dart';
import 'package:jsonschema/pan_attribut_editor.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/editor/cell_prop_editor.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/pan_model_change_viewer.dart';
import 'package:jsonschema/widget/json_editor/widget_json_tree.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/editor/code_editor.dart';
import 'package:jsonschema/widget/widget_hidden_box.dart';
import 'package:jsonschema/widget/widget_hover.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget/widget_tab.dart';
import 'package:jsonschema/widget_state/state_model.dart';
import 'package:yaml/yaml.dart';

// ignore: must_be_immutable
class WidgetModelEditor extends StatelessWidget with WidgetModelHelper {
  WidgetModelEditor({super.key});
  final GlobalKey keyAttrEditor = GlobalKey();
  final ValueNotifier<double> showAttrEditor = ValueNotifier(0);
  State? rowSelected;
  final GlobalKey keyChangeViewer = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return _getModelEditor();
  }

  Row _getModelEditor() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 300,
          height: double.infinity,
          child: _getEditorLeftTab(),
        ),
        Expanded(child: _getEditorMainTab()),
      ],
    );
  }

  Widget _getEditor() {
    getJsonYaml() {
      return currentCompany.currentModel!.mapModelYaml;
    }

    return Row(
      children: [
        Expanded(
          child: JsonEditor(
            key: stateModel.keyTreeModelInfo,
            config:
                JsonTreeConfig(
                    getModel: () {
                      return currentCompany.currentModel;
                    },
                    onTap: (NodeAttribut node) {
                      doShowAttrEditor(currentCompany.currentModel!, node);
                      if (rowSelected?.mounted == true) {
                        // ignore: invalid_use_of_protected_member
                        rowSelected?.setState(() {});
                      }
                      // ignore: invalid_use_of_protected_member
                      node.widgetState?.setState(() {});
                    },
                  )
                  ..getJson = getJsonYaml
                  ..getRow = _getRowsAttrInfo,
          ),
        ),
        WidgetHiddenBox(
          showNotifier: showAttrEditor,
          child: AttributProperties(key: keyAttrEditor),
        ),
      ],
    );
  }

  late TabController tabEditor;

  Widget _getEditorMainTab() {
    return WidgetTab(
      onInitController: (TabController tab) {
        tabEditor = tab;
        tab.addListener(() {
          if (tab.indexIsChanging && tab.index == 1) {
            // ignore: invalid_use_of_protected_member
            keyChangeViewer.currentState?.setState(() {});
          }
        });
      },
      listTab: [Tab(text: 'Editor'), Tab(text: 'Change log')],
      listTabCont: [_getEditor(), _getChangeLogTab()],
      heightTab: 40,
    );
  }

  Widget _getChangeLogTab() {
    if (currentCompany.currentModel == null) return Container();

    return PanModelChangeViewer(key: keyChangeViewer);
  }

  Widget _getEditorLeftTab() {
    void onYamlChange(String yaml, TextConfig config) {
      if (currentCompany.currentModel == null) return;

      var modelSchemaDetail = currentCompany.currentModel!;
      if (modelSchemaDetail.modelYaml != yaml) {
        modelSchemaDetail.modelYaml = yaml;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          tabEditor.index = 0;

          bddStorage.setItem(modelSchemaDetail.id, modelSchemaDetail.modelYaml);
          bool parseOk = false;
          try {
            modelSchemaDetail.mapModelYaml = loadYaml(
              modelSchemaDetail.modelYaml,
            );
            parseOk = true;
            config.notifError.value = '';
          } catch (e) {
            config.notifError.value = '$e';
          }

          if (parseOk) {
            // ignore: invalid_use_of_protected_member
            stateModel.keyTreeModelInfo.currentState?.setState(() {});
          }
        });
      }
    }

    getYaml() {
      return currentCompany.currentModel?.modelYaml;
    }

    return WidgetTab(
      listTab: [
        Tab(text: 'Structure'),
        Tab(text: 'Info'),
        Tab(text: 'Version'),
      ],
      listTabCont: [
        Container(
          color: Colors.black,
          child: TextEditor(
            header: "Model attributs",
            key: stateModel.keyModelYamlEditor,
            config: TextConfig(
              mode: yaml,
              notifError: notifierErrorYaml,
              onChange: onYamlChange,
              getText: getYaml,
            ),
          ),
        ),
        getInfoForm(),
        Container(),
      ],
      heightTab: 40,
    );
  }

  Widget getInfoForm() {
    if (currentCompany.listModel?.currentAttr == null) {
      return Container();
    }

    var info = currentCompany.listModel!.currentAttr!;
    return Padding(
      padding: EdgeInsets.all(10),
      child: Column(
        spacing: 10,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CellSelectEditor(),
          CellEditor(
            key: ValueKey('description#${info.hashCode}'),
            acces: ModelAccessorAttr(
              info: info.info,
              schema: currentCompany.listModel!,
              propName: 'description',
            ),
            line: 5,
            inArray: false,
          ),
        ],
      ),
    );
  }

  Widget _getRowsAttrInfo(NodeAttribut attr, ModelSchemaDetail schema) {
    if (attr.info.type == 'root') {
      return Container(height: rowHeight);
    }

    List<Widget> rowWidget = [SizedBox(width: 10)];
    rowWidget.add(
      CellEditor(
        key: ValueKey('${attr.hashCode}#title'),
        acces: ModelAccessorAttr(
          info: attr.info,
          schema: currentCompany.currentModel!,
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

    attr.info.cache = SizedBox(
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
            attr.widgetState = state;
            bool isSelected = schema.currentAttr == attr;
            if (isSelected) {
              rowSelected = state;
            }
            return isSelected;
          },
          key: ObjectKey(attr),
          //margin: EdgeInsets.all(1),
          child: Row(spacing: 5, children: rowWidget),
        ),
      ),
    );
    return attr.info.cache!;
  }

  void doShowAttrEditor(ModelSchemaDetail schema, NodeAttribut attr) {
    schema.currentAttr = attr;
    // ignore: invalid_use_of_protected_member
    keyAttrEditor.currentState?.setState(() {});
    showAttrEditor.value = 300;
  }
}
