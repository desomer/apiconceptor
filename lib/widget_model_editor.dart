import 'package:flutter/material.dart';
import 'package:jsonschema/attributProperties.dart';
import 'package:jsonschema/bdd/data_acces.dart';
import 'package:jsonschema/cell_editor.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/export/json_browser.dart';
import 'package:jsonschema/json_tree.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/widget_model_helper.dart';
import 'package:jsonschema/widget_tab.dart';
import 'package:jsonschema/yaml_editor.dart';
import 'package:yaml/yaml.dart';

class WidgetModelEditor extends StatelessWidget with WidgetModelHelper {
  const WidgetModelEditor({super.key});

  @override
  Widget build(BuildContext context) {
    return _getModelEditor();
  }

  Row _getModelEditor() {
    getJsonYaml() {
      return currentCompany.currentModel!.mapModelYaml;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 300,
          height: double.infinity,
          child: _getEditorLeftTab(),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: JsonEditor(
                  key: keyModelInfo,
                  config:
                      JsonTreeConfig(
                          getModel: () {
                            return currentCompany.currentModel;
                          },
                        )
                        ..getJson = getJsonYaml
                        ..getRow = _getWidgetAttrInfo,
                ),
              ),
              SizedBox(width: 400, child: AttributProperties()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _getEditorLeftTab() {
    void onYamlChange(String yaml, YamlConfig config) {
      if (currentCompany.currentModel == null) return;

      var modelSchemaDetail = currentCompany.currentModel!;
      if (modelSchemaDetail.modelYaml != yaml) {
        modelSchemaDetail.modelYaml = yaml;
        localStorage.setItem(modelSchemaDetail.id, modelSchemaDetail.modelYaml);
        bool parseOk = false;
        try {
          modelSchemaDetail.mapModelYaml = loadYaml(
            modelSchemaDetail.modelYaml,
          );
          parseOk = true;
          config.notifError.value = '';
        } catch (e) {
          config.notifError.value = '$e';
          //print(e);
        }

        if (parseOk) {
          // ignore: invalid_use_of_protected_member
          keyModelInfo.currentState?.setState(() {});
        }
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
          child: YamlEditor(
            key: keyModelEditor,
            config:
                YamlConfig()
                  ..notifError = notifierErrorYaml
                  ..onChange = onYamlChange
                  ..getYaml = getYaml,
          ),
        ),
        Container(),
        Container(),
      ],
      heightTab: 40,
    );
  }

  Widget _getWidgetAttrInfo(NodeAttribut attr, ModelSchemaDetail schema) {
    if (attr.info.type == 'root') {
      return Container(height: rowHeight);
    }

    List<Widget> row = [SizedBox(width: 10)];
    row.add(
      CellEditor(
        schema: schema,
        key: ValueKey('${attr.hashCode}#description'),
        info: attr.info,
        propName: 'description',
      ),
    );
    row.add(
      CellCheckEditor(
        schema: schema,
        key: ValueKey('${attr.hashCode}#required'),
        info: attr.info,
        propName: 'required',
      ),
    );

    row.add(getChip(Text(attr.info.treePosition ?? ''), color: null));
    row.add(getChip(Text(attr.info.path), color: null));

    addWidgetMasterId(attr, row);


    attr.info.cache = SizedBox( 
      height: rowHeight,
      child: InkWell(
        onTap: () {},
        child: Card(
          key: ObjectKey(attr),
          margin: EdgeInsets.all(1),
          child: Row(children: row),
        ),
      ),
    );
    return attr.info.cache!;
  }
}
