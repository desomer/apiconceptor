import 'package:flutter/material.dart';
import 'package:highlight/languages/yaml.dart' show yaml;
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/editor/cell_prop_editor.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/json_browser/export2json_schema.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/widget/json_editor/widget_json_tree.dart';
import 'package:jsonschema/widget/widget_keep_alive.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/editor/code_editor.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget/widget_tab.dart';
import 'package:yaml/yaml.dart';

class WidgetModelSelector extends StatelessWidget with WidgetModelHelper {
  const WidgetModelSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return getBrowser(context);
  }

  Widget getBrowser(BuildContext context) {
    getJsonYaml() {
      return currentCompany.listModel!.modelYaml;
    }

    var model = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 300,
          height: double.infinity,
          child: getStructureModel(),
        ),
        Expanded(
          child: JsonEditor(
            key: keyListModelInfo,
            config:
                JsonTreeConfig(getModel: () => currentCompany.listModel!)
                  ..getJson = getJsonYaml
                  ..getRow = getWidgetModelInfo,
          ),
        ),
      ],
    );

    return WidgetTab(
      listTab: [Tab(text: 'Business entities'), Tab(text: 'Components')],
      listTabCont: [KeepAliveWidget(child: model), Container()],
      heightTab: 40,
    );
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
          info: attr.info,
          schema: currentCompany.listModel!,
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
                name: attr.info.name,
                id: key,
                infoManager: InfoManagerModel(),
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
      var key = attr.info.properties![constMasterID];
      currentCompany.currentModel = ModelSchemaDetail(
        infoManager: InfoManagerModel(),
        name: attr.info.name,
        id: key,
      );
      currentCompany.listModel!.currentAttr = attr.info;
      await currentCompany.currentModel!.loadYamlAndProperties(cache: false);
      tabModel.animateTo(1);
    }
  }

  Widget getStructureModel() {
    void onYamlChange(String yaml, TextConfig config) {
      if (currentCompany.listModel!.modelYaml != yaml) {
        currentCompany.listModel!.modelYaml = yaml;
        bddStorage.setItem('model', currentCompany.listModel!.modelYaml);
        bool parseOk = false;
        try {
          currentCompany.listModel!.mapModelYaml = loadYaml(
            currentCompany.listModel!.modelYaml,
          );
          parseOk = true;
          config.notifError.value = '';
        } catch (e) {
          config.notifError.value = '$e';
        }

        if (parseOk) {
          // ignore: invalid_use_of_protected_member
          keyListModelInfo.currentState?.setState(() {});
        }
      }
    }

    getYaml() {
      return currentCompany.listModel!.modelYaml;
    }

    return Container(
      color: Colors.black,
      child: TextEditor(
        header: "Business models",
        key: keyListModel,
        config: TextConfig(
          mode: yaml,
          notifError: notifierModelErrorYaml,
          onChange: onYamlChange,
          getText: getYaml,
        ),
      ),
    );
  }
}
