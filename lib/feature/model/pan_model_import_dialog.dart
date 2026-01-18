import 'package:flutter/material.dart';
import 'package:highlight/languages/json.dart' show json;
import 'package:jsonschema/authorization_manager.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/yaml_browser.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/core/import/json2schema_yaml.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_tab.dart';
import 'package:jsonschema/widget/widget_md_doc.dart';
import 'package:yaml/yaml.dart';

// ignore: must_be_immutable
class PanModelImportDialog extends StatelessWidget {
  PanModelImportDialog({super.key, required this.yamlEditorConfig});

  final CodeEditorConfig yamlEditorConfig;

  late TabController tabImport;
  JsonToSchemaYaml import = JsonToSchemaYaml();

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double width = size.width * 0.8;
    double height = size.height * 0.8;
    Map<String, String> info = {};

    return AlertDialog(
      title: const Text('Create model from ...'),
      content: SizedBox(
        width: width,
        height: height,

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 80,
              width: 600,
              child: Row(
                spacing: 20,
                children: [
                  Flexible(
                    child: CellEditor(
                      acces: InfoAccess(map: info, name: 'domain'),
                      inArray: false,
                    ),
                  ),
                  Flexible(
                    child: CellEditor(
                      acces: InfoAccess(map: info, name: 'model name'),
                      inArray: false,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _getImportTab(context)),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: const Text('Create'),
          onPressed: () {
            if (tabImport.index == 0) {
              var yaml = import.doImportJSON().yaml.toString();

              var modelSchemaDetail = currentCompany.listModel!;
              YamlDocument doc = loadYamlDocument(modelSchemaDetail.modelYaml);
              YamlDoc docYaml = YamlDoc();
              docYaml.doAnalyse(doc, modelSchemaDetail.modelYaml);

              YamlLine? domain;
              for (var element in docYaml.listRoot) {
                if (element.name?.toLowerCase() ==
                    info['domain']?.toLowerCase()) {
                  domain = element;
                  break;
                }
              }
              var domainKey = info['domain'] ?? 'new';
              var nameKey = info['model name'] ?? 'new';
              domain ??= docYaml.addAtEnd(domainKey, '');
              docYaml.addChild(domain, nameKey, 'model');
              var newYaml = docYaml.getDoc();
              modelSchemaDetail.modelYaml = newYaml;
              modelSchemaDetail.doChangeAndRepaintYaml(
                yamlEditorConfig,
                true,
                'import',
              );

              WidgetsBinding.instance.addPostFrameCallback((_) {
                // save du json du model
                var newModel =
                    modelSchemaDetail
                        .mapInfoByJsonPath['root>$domainKey>$nameKey'];
                var id = newModel!.masterID!;
                var aModel = ModelSchema(
                  category: Category.model,
                  infoManager: InfoManagerModel(typeMD: TypeMD.model),
                  headerName: nameKey,
                  id: id,
                  ref: currentCompany.listModel,
                );
                aModel.modelYaml = yaml;
                aModel.doChangeAndRepaintYaml(null, true, 'import');
              });
            } else if (tabImport.index == 1) {}

            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  Widget _getImportTab(BuildContext ctx) {
    return WidgetTab(
      onInitController: (TabController tab) {
        tabImport = tab;
        tab.addListener(() {});
      },
      listTab: [Tab(text: 'From Json (Optionnel)')],
      listTabCont: [_getJsonImport(import)],
      heightTab: 40,
    );
  }

  Widget _getJsonImport(JsonToSchemaYaml import) {
    return TextEditor(
      config: CodeEditorConfig(
        mode: json,
        getText: () {
          return '';
        },
        onChange: (String json, CodeEditorConfig config) {
          import.rawJson = json;
        },
        notifError: ValueNotifier(''),
      ),
      header: 'import json',
    );
  }
}

class InfoAccess extends ValueAccessor {
  InfoAccess({required this.map, required this.name});

  final Map<String, String> map;
  final String name;

  @override
  dynamic get() {
    return map[name] ?? '';
  }

  @override
  String getName() {
    return name;
  }

  @override
  bool isEditable() {
    return true;
  }

  @override
  void remove() {
    map.remove(name);
  }

  @override
  void set(value) {
    map[name] = value;
  }
}
