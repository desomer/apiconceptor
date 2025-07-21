import 'package:flutter/material.dart';
import 'package:highlight/languages/yaml.dart' show yaml;
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/json_browser/browse_glossary.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/widget/json_editor/widget_json_tree.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';

import '../../widget/widget_split.dart';

// ignore: must_be_immutable
class WidgetGlossary extends StatelessWidget with WidgetModelHelper {
  WidgetGlossary({
    super.key,
    required this.schemaGlossary,
    required this.typeModel,
  });
  final ModelSchema schemaGlossary;
  final GlobalKey keyYaml = GlobalKey();
  final GlobalKey keyListInfo = GlobalKey();
  final String typeModel;
  late TextConfig textConfig;

  @override
  Widget build(BuildContext context) {
    schemaGlossary.onChange = (change) {
      NodeAttribut node = change['node'];
      String ope = change['ope'];
      String path = change['path'];
      String? from = change['from'];
      if (ope == ChangeOpe.rename.name) {
        var sp = from!.split('>');
        currentCompany.glossaryManager.dico.remove(sp.last.toLowerCase());
      }
      if (ope == ChangeOpe.remove.name) {
        currentCompany.glossaryManager.dico.remove(
          node.info.name.toLowerCase(),
        );
      } else if (ope != ChangeOpe.change.name || path.endsWith('.type')) {
        if (autorizedGlossaryType.contains(node.info.type)) {
          currentCompany.glossaryManager.add(node);
        }
      }
    };

    void onYamlChange(String yaml, TextConfig config) {
      if (schemaGlossary.modelYaml != yaml) {
        schemaGlossary.modelYaml = yaml;
        schemaGlossary.doChangeAndRepaintYaml(config, true, 'change');
      }
    }

    getYaml() {
      return schemaGlossary.modelYaml;
    }

    textConfig = TextConfig(
      mode: yaml,
      notifError: ValueNotifier<String>(''),
      onChange: onYamlChange,
      getText: getYaml,
    );

    schemaGlossary.initEventListener(textConfig);

    getJsonYaml() {
      return schemaGlossary.modelYaml;
    }

    var modelSelector = SplitView(
      primaryWidth: 350,
      children: [
        getStructureModel(),
        JsonListEditor(
          key: keyListInfo,
          config:
              JsonTreeConfig(
                  textConfig: textConfig,
                  getModel: () => schemaGlossary,
                  onTap: (NodeAttribut node) {
                    //goToModel(node, 1);
                  },
                  onDoubleTap: (NodeAttribut node) {
                    //goToModel(node, 1);
                  },
                )
                ..getJson = getJsonYaml
                ..getRow = _getWidgetModelInfo,
        ),
      ],
    );

    return modelSelector;
  }

  Widget _getWidgetModelInfo(NodeAttribut attr, ModelSchema schema) {
    if (attr.info.type == 'root') {
      return Container(height: rowHeight);
    }

    List<Widget> row = [SizedBox(width: 10)];
    row.add(
      CellEditor(
        inArray: true,
        key: ValueKey(attr.info.numUpdateForKey),
        acces: ModelAccessorAttr(
          node: attr,
          schema: schemaGlossary,
          propName: 'title',
        ),
      ),
    );

    //addWidgetMasterId(attr, row);

    // if (attr.info.type == 'model') {
    //   row.add(
    //     TextButton.icon(
    //       onPressed: () async {
    //         await goToModel(attr, 1);
    //       },
    //       label: Icon(Icons.remove_red_eye),
    //     ),
    //   );
    //   row.add(
    //     TextButton.icon(
    //       icon: Icon(Icons.import_export),
    //       onPressed: () async {
    //         if (attr.info.type == 'model') {
    //           await goToModel(attr, 2);
    //           // var key = attr.info.properties![constMasterID];
    //           // var model = ModelSchemaDetail(
    //           //   type: YamlType.model,
    //           //   name: attr.info.name,
    //           //   id: key,
    //           //   infoManager: InfoManagerModel(typeMD: TypeMD.model),
    //           // );
    //           // await model.loadYamlAndProperties(cache: false);
    //           // await ExportJsonSchema2clipboard().doExport(model);
    //         }
    //       },
    //       label: Text('Json schemas'),
    //     ),
    //   );
    // }

    var ret = SizedBox(
      height: rowHeight,
      child: InkWell(
        // onDoubleTap: () async {
        //   await goToModel(attr, 1);
        // },
        child: Card(
          key: ObjectKey(attr),
          margin: EdgeInsets.all(1),
          child: getToolTip(
            toolContent: getTooltipFromAttr(attr),
            child: Row(children: row),
          ),
        ),
      ),
    );
    // attr.info.cacheRowWidget = ret;
    return ret;
  }

  // Future<void> goToModel(NodeAttribut attr, int tabNumber) async {
  //   if (attr.info.type == 'model') {
  //     stateModel.tabDisable.clear();
  //     // ignore: invalid_use_of_protected_member
  //     stateModel.keyTab.currentState?.setState(() {});

  //     NodeAttribut? n = attr;
  //     var modelPath = [];
  //     while (n != null) {
  //       if (n.parent != null) {
  //         modelPath.insert(0, n.info.name);
  //       }
  //       n = n.parent;
  //     }

  //     stateModel.path = [typeModel, ...modelPath, "0.0.1", "draft"];
  //     // ignore: invalid_use_of_protected_member
  //     stateModel.keyBreadcrumb.currentState?.setState(() {});

  //     var key = attr.info.properties![constMasterID];
  //     currentCompany.currentModel = ModelSchemaDetail(
  //       type: YamlType.model,
  //       infoManager: InfoManagerModel(typeMD: TypeMD.model),
  //       name: attr.info.name,
  //       id: key,
  //     );
  //     currentCompany.currentModelSel = attr;
  //     listGlossary.currentAttr = attr;
  //     if (withBdd) {
  //       await currentCompany.currentModel!.loadYamlAndProperties(cache: false);
  //     }
  //     stateModel.tabModel.animateTo(tabNumber);
  //   }
  // }

  Widget getStructureModel() {
    return Container(
      color: Colors.black,
      child: TextEditor(
        header: "Business glossary",
        onHelp: (BuildContext ctx) {
          // showDialog(
          //   context: ctx,
          //   barrierDismissible: true,
          //   builder: (BuildContext context) {
          //     return WidgetMdDoc(type: TypeMD.listmodel);
          //   },
          // );
        },
        key: keyYaml,
        config: textConfig,
      ),
    );
  }
}
