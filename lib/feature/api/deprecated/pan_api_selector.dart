import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:highlight/languages/yaml.dart' show yaml;
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/repaint_manager.dart';
import 'package:jsonschema/core/yaml_browser.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/server.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/feature/api/pan_api_import.dart';
import 'package:jsonschema/feature/pan_attribut_editor.dart';
import 'package:jsonschema/widget/tree_editor/widget_json_tree.dart';
import 'package:jsonschema/widget/widget_hidden_box.dart';
import 'package:jsonschema/widget/widget_hover.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget/widget_split.dart';
import 'package:jsonschema/widget/widget_tab.dart';
import 'package:jsonschema/widget/widget_version_state.dart';
import 'package:jsonschema/widget_state/state_api.dart';
import 'package:url_launcher/url_launcher.dart';

// ignore: must_be_immutable
class PanAPISelector extends StatelessWidget with WidgetHelper {
  PanAPISelector({super.key});
  late final YamlEditorConfig textConfig;
  final ValueNotifier<double> showAttrEditor = ValueNotifier(0);
  final GlobalKey keyAttrEditor = GlobalKey();

  State? rowSelected;

  @override
  Widget build(BuildContext context) {
    repaintManager.addTag(ChangeTag.showListApi, "PanAPISelector", null, () {
      stateOpenFactor?.setList(stateApi.keyListAPIInfo.currentState!);
      return false;
    });

    void onYamlChange(String yaml, YamlEditorConfig config) {
      if (currentCompany.listAPI!.modelYaml != yaml) {
        currentCompany.listAPI!.modelYaml = yaml;
        var parser = ParseYamlManager();
        bool parseOk = parser.doParseYaml(
          currentCompany.listAPI!.modelYaml,
          config,
        );

        if (parseOk) {
          currentCompany.listAPI!.mapModelYaml = parser.mapYaml!;
          // bddStorage.savePath(type: 'YAML', id: id, value: yaml);
          bddStorage.setYaml(
            currentCompany.listAPI!,
            currentCompany.listAPI!.modelYaml,
            currentCompany.listAPI!.currentVersion,
          );
          // ignore: invalid_use_of_protected_member
          stateApi.keyListAPIInfo.currentState?.setState(() {});
        }
      }
    }

    getYaml() {
      return currentCompany.listAPI!.modelYaml;
    }

    textConfig = YamlEditorConfig(
      mode: yaml,
      notifError: ValueNotifier<String>(''),
      onChange: onYamlChange,
      getText: getYaml,
    );

    var model = SplitView(
      primaryWidth: 350,
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
                        onTap: (NodeAttribut node, BuildContext context) {
                          goToAPI(node, 1, context: context);
                          return true;
                        },
                      )
                      ..getJson = getYaml
                      ..getRow = _getRowAPIInfo,
              ),
            ),
            WidgetHiddenBox(
              showNotifier: showAttrEditor,
              child: EditorProperties(
                typeAttr: TypeAttr.api,
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
        Tab(text: 'Definition'),
        Tab(text: 'Proxy Mock'),
        Tab(text: 'Proxy random error'),
      ],
      listTabCont: [
        model,
        Column(
          children: [
            ElevatedButton.icon(
              icon: Icon(Icons.troubleshoot_rounded),
              onPressed: () async {
                startServer();
              },
              label: Text('Start API Mock local Server'),
            ),
            ElevatedButton.icon(
              icon: Icon(Icons.open_in_browser),
              onPressed: () async {
                startServer();
                String baseUrl = 'localhost:1234';
                String path = 'all/api';
                Uri url = Uri.http(baseUrl, path);
                if (!await launchUrl(
                  url,
                  mode: LaunchMode.externalApplication,
                )) {
                  throw Exception('Could not launch $url');
                }
              },
              label: Text('View mock page'),
            ),
          ],
        ),
        Container(),
      ],
      heightTab: 40,
    );
  }

  Widget _getRowAPIInfo(
    NodeAttribut attr,
    ModelSchema schema,
    BuildContext context,
  ) {
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
          schema: currentCompany.listAPI!,
          propName: 'summary',
        ),
      ),
    );

    //addWidgetMasterId(attr, row);

    if (attr.info.type == 'ope') {
      row.add(SizedBox(width: 10));
      row.add(WidgetVersionState(margeVertical: 2));
      row.add(
        TextButton.icon(
          onPressed: () async {
            await goToAPI(attr, 1, context: context);
          },
          label: Icon(Icons.remove_red_eye),
        ),
      );
      row.add(
        TextButton.icon(
          icon: Icon(Icons.import_export),
          onPressed: () async {
            await goToAPI(attr, 1, subtabNumber: 2, context: context);
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
          await goToAPI(attr, 1, context: context);
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
      ),
    );
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
    required BuildContext context,
  }) async {
    var sel = currentCompany.listAPI!.nodeByMasterId[attr.info.masterID]!;

    if (sel.info.type == 'ope') {
      (key as GlobalKey).currentContext!.push(
        Pages.apiDetail.id(sel.info.masterID!),
      );
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
