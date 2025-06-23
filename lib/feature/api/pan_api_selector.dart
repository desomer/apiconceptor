import 'package:flutter/material.dart';
import 'package:highlight/languages/yaml.dart' show yaml;
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/repaint_manager.dart';
import 'package:jsonschema/core/yaml_browser.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/feature/api/pan_api_editor.dart';
import 'package:jsonschema/feature/api/pan_api_import.dart';
import 'package:jsonschema/feature/api/pan_api_info.dart';
import 'package:jsonschema/widget/json_editor/widget_json_tree.dart';
import 'package:jsonschema/widget/widget_hidden_box.dart';
import 'package:jsonschema/widget/widget_hover.dart';
import 'package:jsonschema/widget/widget_keep_alive.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget/widget_split.dart';
import 'package:jsonschema/widget/widget_tab.dart';
import 'package:jsonschema/widget_state/state_api.dart';

// ignore: must_be_immutable
class PanAPISelector extends StatelessWidget with WidgetModelHelper {
  PanAPISelector({super.key});
  late final TextConfig textConfig;
  final ValueNotifier<double> showAttrEditor = ValueNotifier(0);
  State? rowSelected;
  final GlobalKey keyAttrEditor = GlobalKey();

  @override
  Widget build(BuildContext context) {
    void onYamlChange(String yaml, TextConfig config) {
      if (currentCompany.listAPI.modelYaml != yaml) {
        currentCompany.listAPI.modelYaml = yaml;
        var parser = ParseYamlManager();
        bool parseOk = parser.doParseYaml(
          currentCompany.listAPI.modelYaml,
          config,
        );

        if (parseOk) {
          currentCompany.listAPI.mapModelYaml = parser.mapYaml!;
          // bddStorage.savePath(type: 'YAML', id: id, value: yaml);
          bddStorage.setYaml(
            currentCompany.listAPI,
            currentCompany.listAPI.modelYaml,
            currentCompany.listAPI.currentVersion
          );
          // ignore: invalid_use_of_protected_member
          stateApi.keyListAPIInfo.currentState?.setState(() {});
        }
      }
    }

    getYaml() {
      return currentCompany.listAPI.modelYaml;
    }

    textConfig = TextConfig(
      mode: yaml,
      notifError: ValueNotifier<String>(''),
      onChange: onYamlChange,
      getText: getYaml,
    );

    var model = SplitView(
      primaryWidth: 400,
      children: [
        getStructureModel(context),
        Row(
          children: [
            Expanded(
              child: JsonListEditor(
                key: stateApi.keyListAPIInfo,
                config:
                    JsonTreeConfig(
                        textConfig: textConfig,
                        getModel: () => currentCompany.listAPI,
                        onTap: (NodeAttribut node) {
                          goToAPI(node, 1);
                        },
                      )
                      ..widthTree = 500
                      ..getJson = getYaml
                      ..getRow = _getRowModelInfo,
              ),
            ),
            WidgetHiddenBox(
              showNotifier: showAttrEditor,
              child: APIProperties(
                typeAttr: TypeAttr.model,
                key: keyAttrEditor,
                getModel: () {
                  return currentCompany.listAPI;
                },
              ),
            ),
          ],
        ),
      ],
    );

    return WidgetTab(
      listTab: [
        Tab(text: 'API'),
        Tab(text: 'Proxy Mock'),
        Tab(text: 'Proxy random error'),
      ],
      listTabCont: [KeepAliveWidget(child: model), Container(), Container()],
      heightTab: 40,
    );
  }

  Widget _getRowModelInfo(NodeAttribut attr, ModelSchema schema) {
    if (attr.info.type == 'root') {
      return Container(height: rowHeight);
    }

    List<Widget> row = [SizedBox(width: 10)];
    row.add(
      CellEditor(
        inArray: true,
        key: ValueKey('${attr.hashCode}#summary'),
        acces: ModelAccessorAttr(
          node: attr,
          schema: currentCompany.listAPI,
          propName: 'summary',
        ),
      ),
    );

    //addWidgetMasterId(attr, row);

    if (attr.info.type == 'ope') {
      row.add(
        TextButton.icon(
          onPressed: () async {
            await goToAPI(attr, 1);
          },
          label: Icon(Icons.remove_red_eye),
        ),
      );
      row.add(
        TextButton.icon(
          icon: Icon(Icons.import_export),
          onPressed: () async {
            await goToAPI(attr, 1, subtabNumber: 2);
          },
          label: Text('Test API'),
        ),
      );
    }

    var ret = SizedBox(
      height: rowHeight,
      child: InkWell(
        onTap: () {
          doShowAttrEditor(schema, attr);
          if (rowSelected?.mounted == true) {
            // ignore: invalid_use_of_protected_member
            rowSelected?.setState(() {});
          }
        },

        onDoubleTap: () async {
          await goToAPI(attr, 1);
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
          child: Row(spacing: 5, children: row),
        ),

        //  Card(
        //   key: ObjectKey(attr),
        //   margin: EdgeInsets.all(1),
        //   child: Row(children: row),
        // ),
      ),
    );
    // attr.info.cacheRowWidget = ret;
    return ret;
  }

  void doShowAttrEditor(ModelSchema schema, NodeAttribut attr) {
    if (schema.currentAttr == attr && showAttrEditor.value == 300) {
      showAttrEditor.value = 0;
    } else {
      showAttrEditor.value = 300;
    }
    schema.currentAttr = attr;
    //ignore: invalid_use_of_protected_member
    keyAttrEditor.currentState?.setState(() {});
  }

  Future<void> goToAPI(
    NodeAttribut attr,
    int tabNumber, {
    int subtabNumber = -1,
  }) async {
    if (attr.info.type == 'ope') {
      stateApi.tabDisable.clear();
      // ignore: invalid_use_of_protected_member
      stateApi.keyTab.currentState?.setState(() {});

      NodeAttribut? n = attr.parent;
      var modelPath = [];
      while (n != null) {
        if (n.parent != null) {
          modelPath.insert(0, n.info.name);
        }

        n = n.parent;
      }

      stateApi.path = ["API", ...modelPath, "0.0.1", "draft"];
      // ignore: invalid_use_of_protected_member
      stateApi.keyBreadcrumb.currentState?.setState(() {});

      var key = attr.info.properties![constMasterID];
      currentCompany.currentAPIResquest = ModelSchema(
        type: YamlType.api,
        infoManager: InfoManagerAPIParam(),
        headerName: attr.info.name,
        id: key,
      );
      currentCompany.listAPI.currentAttr = attr;
      await currentCompany.currentAPIResquest!.loadYamlAndProperties(
        cache: false,
      );
      currentCompany.currentAPIResquest!.onChange = (change) {
        currentCompany.apiCallInfo?.params.clear();
        repaintManager.doRepaint(ChangeTag.apiparam);
      };

      currentCompany.currentAPIResponse = ModelSchema(
        type: YamlType.api,
        infoManager: InfoManagerAPIParam(),
        headerName: attr.info.name,
        id: 'response/$key',
      );
      currentCompany.listAPI.currentAttr = attr;
      await currentCompany.currentAPIResponse!.loadYamlAndProperties(
        cache: false,
      );

      repaintManager.doRepaint(ChangeTag.apichange);

      stateApi.tabApi.index = tabNumber;
      Future.delayed(Duration(milliseconds: 100)).then((value) {
        stateApi.tabSubApi.index = 0; // charge l'ordre des params
        Future.delayed(Duration(milliseconds: 100)).then((value) {
          if (subtabNumber >= 0) {
            // exemple : aller sur le test d'api
            stateApi.tabSubApi.index = subtabNumber;
          }
        });
      });
    }
  }

  Widget getStructureModel(BuildContext ctx) {
    return Container(
      color: Colors.black,
      child: TextEditor(
        header: "API routes",
        key: stateApi.keyListAPIYaml,
        config: textConfig,
        actions: <Widget>[
          InkWell(onTap: () {}, child: Icon(Icons.auto_fix_high, size: 18)),
        ],
      ),
    );
  }

  Future<void> showImportDialog(BuildContext ctx) async {
    return showDialog<void>(
      context: ctx,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return PanAPIImport();
      },
    );
  }
}
