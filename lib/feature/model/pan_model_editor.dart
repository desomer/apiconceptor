import 'package:flutter/material.dart';
import 'package:highlight/languages/yaml.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/model/pan_model_version_list.dart';
import 'package:jsonschema/feature/pan_attribut_editor.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/feature/model/pan_model_change_log.dart';
import 'package:jsonschema/feature/model/pan_model_import.dart';
import 'package:jsonschema/widget/editor/doc_editor.dart';
import 'package:jsonschema/widget/json_editor/widget_json_tree.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/widget/widget_glossary_indicator.dart';
import 'package:jsonschema/widget/widget_hidden_box.dart';
import 'package:jsonschema/widget/widget_hover.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget/widget_split.dart';
import 'package:jsonschema/widget/widget_tab.dart';
import 'package:jsonschema/widget_state/state_model.dart';
import 'package:jsonschema/widget_state/widget_MD_doc.dart';

// ignore: must_be_immutable
class WidgetModelEditor extends StatefulWidget {
  const WidgetModelEditor({super.key});

  @override
  State<WidgetModelEditor> createState() => _WidgetModelEditorState();
}

class _WidgetModelEditorState extends State<WidgetModelEditor>
    with WidgetModelHelper {
  final ValueNotifier<double> showAttrEditor = ValueNotifier(0);
  State? rowSelected;

  final GlobalKey keyAttrEditor = GlobalKey();
  final GlobalKey keyChangeViewer = GlobalKey();
  final GlobalKey keyVersion = GlobalKey();

  late TextConfig textConfig;

  @override
  Widget build(BuildContext context) {
    void onYamlChange(String yaml, TextConfig config) {
      if (currentCompany.currentModel == null) return;

      var modelSchemaDetail = currentCompany.currentModel!;
      if (modelSchemaDetail.modelYaml != yaml) {
        modelSchemaDetail.modelYaml = yaml;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          tabEditor.index = 0;

          modelSchemaDetail.doChangeAndRepaintYaml(config, true, 'change');
        });
      }
    }

    getYaml() {
      return currentCompany.currentModel?.modelYaml;
    }

    textConfig = TextConfig(
      mode: yaml,
      notifError: notifierErrorYaml,
      onChange: onYamlChange,
      getText: getYaml,
    );

    currentCompany.currentModel?.initEventListener(textConfig);

    return SplitView(
      primaryWidth: 350,
      children: [_getEditorLeftTab(context), _getEditorMainTab(context)],
    );
  }

  Widget _getEditor() {
    getJsonYaml() {
      return currentCompany.currentModel!.mapModelYaml;
    }

    return Row(
      children: [
        Expanded(
          child: JsonListEditor(
            key: ObjectKey(currentCompany.currentModel),
            config:
                JsonTreeConfig(
                    textConfig: textConfig,
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
                      node.widgetSelectState?.setState(() {});
                    },
                  )
                  ..getJson = getJsonYaml
                  ..getRow = _getRowsAttrInfo,
          ),
        ),
        WidgetHiddenBox(
          showNotifier: showAttrEditor,
          child: AttributProperties(
            typeAttr: TypeAttr.model,
            key: keyAttrEditor,
            getModel: () {
              return currentCompany.currentModel;
            },
          ),
        ),
      ],
    );
  }

  late TabController tabEditor;

  Widget _getEditorMainTab(BuildContext ctx) {
    return WidgetTab(
      onInitController: (TabController tab) {
        tabEditor = tab;
        tab.addListener(() {
          // raffraichi lr change log
          if (tab.indexIsChanging && tab.index == 3) {
            // ignore: invalid_use_of_protected_member
            keyChangeViewer.currentState?.setState(() {});
          }
        });
      },
      listTab: [
        Tab(text: 'Schema detail'),
        Tab(text: 'Life cycle method'),
        Tab(text: 'Mapping rules'),
        Tab(text: 'Change log'),
        Tab(text: 'Documentation'),
        Tab(text: 'Recommendation'),
      ],
      listTabCont: [
        _getEditor(),
        getLifeCycleTab(),
        Container(),
        _getChangeLogTab(),
        DocEditor(),
        Container(),
      ],
      heightTab: 40,
    );
  }

  Widget getLifeCycleTab() {
    return WidgetTab(
      onInitController: (TabController tab) {},
      listTab: [
        Tab(text: 'Create use cases'),
        Tab(text: 'Enhancement use cases'),
        Tab(text: 'Delete use cases'),
      ],
      listTabCont: [Container(), Container(), Container()],
      heightTab: 40,
    );
  }

  Widget _getChangeLogTab() {
    if (currentCompany.currentModel == null) return Container();

    return PanModelChangeLog(key: keyChangeViewer);
  }

  Widget _getEditorLeftTab(BuildContext ctx) {
    return WidgetTab(
      listTab: [
        Tab(text: 'Structure'),
        Tab(text: 'Info'),
        Tab(text: 'Version'),
        Tab(text: 'Restore point'),
      ],
      listTabCont: [
        Container(
          color: Colors.black,
          child: TextEditor(
            header: "Model attributs",
            key: stateModel.keyModelYamlEditor,
            onHelp: (BuildContext ctx) {
              showDialog(
                context: ctx,
                barrierDismissible: true,
                builder: (BuildContext context) {
                  return WidgetMdDoc(type: TypeMD.model);
                },
              );
            },
            actions: <Widget>[
              InkWell(
                onTap: () {
                  _showMyDialog(ctx);
                },
                child: Icon(Icons.auto_fix_high, size: 18),
              ),
            ],
            config: textConfig,
          ),
        ),
        getInfoForm(),
        getVersionTab(),
        Container(),
      ],
      heightTab: 40,
    );
  }

  Widget getVersionTab() {
    var model = currentCompany.currentModel!;
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () async {
            var versionNum = int.parse(model.versions!.first.version) + 1;
            ModelVersion version = ModelVersion(
              id: model.id,
              version: '$versionNum',
              data: {
                'state': 'D',
                'by': currentCompany.userId,
                'versionTxt': '0.0.$versionNum',
              },
            );
            model.versions!.insert(0, version);
            model.currentVersion = version;
            await bddStorage.addVersion(model, version);
            keyVersion.currentState?.setState(() {});
            String modelYaml = model.modelYaml;
            var modelProperties = model.useAttributInfo;
            model.clear();
            await bddStorage.duplicateVersion(
              model,
              version,
              modelYaml,
              modelProperties,
            );
            await model.loadYamlAndProperties(
              cache: false,
              withProperties: true,
            );
            model.doChangeAndRepaintYaml(textConfig, false, 'event');
          },
          label: Text('add version'),
          icon: Icon(Icons.add_box_outlined),
        ),
        Expanded(
          child: PanModelVersionList(
            key: keyVersion,
            schema: model,
            onTap: (ModelVersion version) async {
              model.currentVersion = version;
              model.clear();
              await model.loadYamlAndProperties(
                cache: false,
                withProperties: true,
              );
              model.doChangeAndRepaintYaml(textConfig, false, 'event');
              model.initBreadcrumb();
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showMyDialog(BuildContext ctx) async {
    return showDialog<void>(
      context: ctx,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return PanModelImport();
      },
    );
  }

  Widget getInfoForm() {
    if (currentCompany.listModel.currentAttr == null) {
      return Container();
    }

    var info = currentCompany.listModel.currentAttr!;
    return Padding(
      padding: EdgeInsets.all(10),
      child: Column(
        spacing: 10,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CellSelectEditor(),
          CellEditor(
            key: ValueKey('description#${info.info.masterID}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: currentCompany.listModel,
              propName: 'description',
            ),
            line: 5,
            inArray: false,
          ),
          CellEditor(
            key: ValueKey('link#${info.info.masterID}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: currentCompany.listModel,
              propName: 'link',
            ),
            line: 5,
            inArray: false,
          ),
        ],
      ),
    );
  }

  Widget _getRowsAttrInfo(NodeAttribut attr, ModelSchema schema) {
    if (attr.info.type == 'root') {
      return Container(height: rowHeight);
    }

    List<Widget> rowWidget = [SizedBox(width: 10)];
    rowWidget.add(
      CellEditor(
        key: ValueKey(attr.info.numUpdateForKey),
        acces: ModelAccessorAttr(
          node: attr,
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
        (attr.info.properties?['maxLength'] != null) ||
        (attr.info.properties?['minItems'] != null) ||
        (attr.info.properties?['maxItems'] != null);

    rowWidget.addAll(<Widget>[
      SizedBox(width: 10),
      if (attr.info.properties?['required'] == true)
        Icon(Icons.check_circle_outline),
      if (attr.info.properties?['const'] != null)
        getChip(Text('const'), color: null),
      if (attr.info.properties?['enum'] != null) Icon(Icons.checklist),
      if (attr.info.properties?['pattern'] != null)
        getChip(Text('regex'), color: null),
      if (minmax) Icon(Icons.tune),
      Spacer(),
      WidgetGlossaryIndicator(attr: attr.info),
    ]);

    // row.add(getChip(Text(attr.info.treePosition ?? ''), color: null));
    // row.add(getChip(Text(attr.info.path), color: null));
    // addWidgetMasterId(attr, row);

    // if (true) {
    //   return Row(spacing: 5, children: rowWidget);
    // }

    return SizedBox(
      height: rowHeight,
      child: InkWell(
        onTap: () {
          doShowAttrEditor(schema, attr);
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
          },
          child: getToolTip(
            toolContent: getTooltipFromAttr(attr),
            child: Row(spacing: 5, children: rowWidget),
          ),
        ),
      ),
    );
  }

  void doShowAttrEditor(ModelSchema schema, NodeAttribut attr) {
    if (schema.currentAttr == attr && showAttrEditor.value == 300) {
      showAttrEditor.value = 0;
    } else {
      showAttrEditor.value = 300;
    }
    schema.currentAttr = attr;
    // ignore: invalid_use_of_protected_member
    keyAttrEditor.currentState?.setState(() {});
  }
}
