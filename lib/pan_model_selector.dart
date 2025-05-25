import 'package:flutter/material.dart';
import 'package:highlight/languages/yaml.dart' show yaml;
import 'package:jsonschema/editor/cell_prop_editor.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/json_browser/export2json_schema.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/widget/json_editor/widget_json_tree.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/editor/code_editor.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget_state/state_model.dart';
import 'package:jsonschema/widget_state/widget_md_doc.dart';

import 'widget/widget_split.dart';

// ignore: must_be_immutable
class WidgetModelSelector extends StatelessWidget with WidgetModelHelper {
  WidgetModelSelector({
    super.key,
    required this.listModel,
    required this.typeModel,
  });
  final ModelSchemaDetail listModel;
  final GlobalKey keyYamlListModel = GlobalKey();
  final GlobalKey keyListModelInfo = GlobalKey();
  final String typeModel;
  late TextConfig textConfig;

  @override
  Widget build(BuildContext context) {
    void onYamlChange(String yaml, TextConfig config) {
      if (listModel.modelYaml != yaml) {
        listModel.modelYaml = yaml;
        listModel.doChangeYaml(config, true, 'change');
      }
    }

    getYaml() {
      return listModel.modelYaml;
    }

    textConfig = TextConfig(
      mode: yaml,
      notifError: ValueNotifier<String>(''),
      onChange: onYamlChange,
      getText: getYaml,
    );

    listModel.initEventListener(textConfig);

    getJsonYaml() {
      return listModel.modelYaml;
    }

    var modelSelector = SplitView(
      childs: [
        getStructureModel(),
        JsonEditor(
          key: keyListModelInfo,
          config:
              JsonTreeConfig(
                  textConfig: textConfig,
                  getModel: () => listModel,
                  onTap: (NodeAttribut node) {
                    goToModel(node);
                  },
                  onDoubleTap: (NodeAttribut node) {
                    goToModel(node);
                  },
                )
                ..getJson = getJsonYaml
                ..getRow = getWidgetModelInfo,
        ),
      ],
    );

    return modelSelector;
  }


  Widget getWidgetModelInfo(NodeAttribut attr, ModelSchemaDetail schema) {
    if (attr.info.type == 'root') {
      return Container(height: rowHeight);
    }

    List<Widget> row = [SizedBox(width: 10)];
    row.add(
      CellEditor(
        inArray: true,
        key: ValueKey('${attr.hashCode}#title'),
        acces: ModelAccessorAttr(
          node: attr,
          schema: listModel,
          propName: 'title',
        ),
      ),
    );

    //addWidgetMasterId(attr, row);

    if (attr.info.type == 'model') {
      row.add(
        TextButton.icon(
          onPressed: () async {
            await goToModel(attr);
          },
          label: Icon(Icons.remove_red_eye),
        ),
      );
      row.add(
        TextButton.icon(
          icon: Icon(Icons.import_export),
          onPressed: () async {
            if (attr.info.type == 'model') {
              var key = attr.info.properties![constMasterID];
              var model = ModelSchemaDetail(
                type: YamlType.model,
                name: attr.info.name,
                id: key,
                infoManager: InfoManagerModel(typeMD: TypeMD.model),
              );
              await model.loadYamlAndProperties(cache: false);
              await ExportJsonSchema2clipboard().doExport(model);
            }
          },
          label: Text('Json schemas'),
        ),
      );
    }

    var ret = SizedBox(
      height: rowHeight,
      child: InkWell(
        onDoubleTap: () async {
          await goToModel(attr);
        },
        child: Card(
          key: ObjectKey(attr),
          margin: EdgeInsets.all(1),
          child: Row(children: row),
        ),
      ),
    );
    attr.info.cache = ret;
    return ret;
  }

  Future<void> goToModel(NodeAttribut attr) async {
    if (attr.info.type == 'model') {
      stateModel.tabDisable.clear();
      // ignore: invalid_use_of_protected_member
      stateModel.keyTab.currentState?.setState(() {});

      NodeAttribut? n = attr;
      var modelPath = [];
      while (n != null) {
        if (n.parent != null) {
          modelPath.insert(0, n.info.name);
        }
        n = n.parent;
      }

      stateModel.path = [typeModel, ...modelPath, "0.0.1", "draft"];
      // ignore: invalid_use_of_protected_member
      stateModel.keyBreadcrumb.currentState?.setState(() {});

      var key = attr.info.properties![constMasterID];
      currentCompany.currentModel = ModelSchemaDetail(
        type: YamlType.model,
        infoManager: InfoManagerModel(typeMD: TypeMD.model),
        name: attr.info.name,
        id: key,
      );
      currentCompany.currentModelSel = attr;
      listModel.currentAttr = attr;

      await currentCompany.currentModel!.loadYamlAndProperties(cache: false);
      stateModel.tabModel.animateTo(1);
    }
  }

  Widget getStructureModel() {
    return Container(
      color: Colors.black,
      child: TextEditor(
        header: "Business models",
        onHelp: (BuildContext ctx) {
          showDialog(
            context: ctx,
            barrierDismissible: true,
            builder: (BuildContext context) {
              return WidgetMdDoc(type: TypeMD.listmodel);
            },
          );
        },
        key: keyYamlListModel,
        config: textConfig,
      ),
    );
  }
}
