import 'package:flutter/material.dart';
import 'package:highlight/languages/json.dart' show json;
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/editor/code_editor.dart';
import 'package:jsonschema/import/json2schema_yaml.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/feature/model/pan_model_link.dart';
import 'package:jsonschema/widget/json_editor/widget_json_tree.dart';
import 'package:jsonschema/widget/widget_tab.dart';
import 'package:jsonschema/widget_state/state_model.dart';

// ignore: must_be_immutable
class PanModelImport extends StatelessWidget {
  PanModelImport({super.key});

  late TabController tabImport;

  Widget _getImportTab(
    JsonToSchemaYaml import,
    ModelSchemaDetail model,
    BuildContext ctx,
  ) {
    return WidgetTab(
      onInitController: (TabController tab) {
        tabImport = tab;
        tab.addListener(() {});
      },
      listTab: [
        Tab(text: 'From Json'),
        Tab(text: 'From Models'),
        Tab(text: 'From Json-schema or Swagger'),
      ],
      listTabCont: [
        _getJsonImport(import),
        _getAttrSelector(model),
        Container(),
      ],
      heightTab: 40,
    );
  }

  Widget _getJsonImport(JsonToSchemaYaml import) {
    return TextEditor(
      config: TextConfig(
        mode: json,
        getText: () {
          return '';
        },
        onChange: (String json, TextConfig config) {
          import.rawJson = json;
        },
        notifError: ValueNotifier(''),
      ),
      header: 'import json',
    );
  }

  Widget _getAttrSelector(ModelSchemaDetail model) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        //TextButton(onPressed: () {}, child: Text("Import")),
        Expanded(child: WidgetModelLink(listModel: model)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    JsonToSchemaYaml import = JsonToSchemaYaml();

    ModelSchemaDetail model = ModelSchemaDetail(
      type: YamlType.selector,
      name: 'Select Models',
      id: 'model',
      infoManager: currentCompany.listModel.infoManager,
    );
    model.autoSave = false;
    model.mapModelYaml = currentCompany.listModel.mapModelYaml;
    model.modelProperties = currentCompany.listModel.modelProperties;

    Size size = MediaQuery.of(context).size;
    double width = size.width * 0.8;
    double height = size.height * 0.8;

    return AlertDialog(
      title: const Text('Import model from ...'),
      content: SizedBox(
        width: width,
        height: height,

        child: _getImportTab(import, model, context),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: const Text('Import'),
          onPressed: () {
            if (tabImport.index == 0) {
              var modelSchemaDetail = currentCompany.currentModel!;
              modelSchemaDetail.modelYaml =
                  import.doImportJSON().yaml.toString();
              // ignore: invalid_use_of_protected_member
              stateModel.keyModelYamlEditor.currentState?.setState(() {});
              modelSchemaDetail.doChangeYaml(null, true, 'import');
            } else if (tabImport.index == 1) {
              doImportFromModel(model);
            }
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  void doImportFromModel(ModelSchemaDetail model) {
    print(model.lastBrowser?.selectedPath);
    for (var sel in model.lastBrowser?.selectedPath ?? {}) {
      var info = model.mapInfoByJsonPath[sel];
      var node = (model.lastJsonBrowser as JsonBrowserWidget).findNode(info!);
      var data = node!.data;
      List<NodeAttribut> path = [];
      while (data != null) {
        path.insert(0, data);
        data = data.parent;
        if (data?.info.type == 'model') {
          break;
        }
      }

      var modelSchemaDetail = currentCompany.currentModel!;
      modelSchemaDetail.modelYaml = '${modelSchemaDetail.modelYaml}add';
      // ignore: invalid_use_of_protected_member
      stateModel.keyModelYamlEditor.currentState?.setState(() {});
      modelSchemaDetail.doChangeYaml(null, true, 'import');
    }
  }
}
