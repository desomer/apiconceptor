import 'package:flutter/material.dart';
import 'package:highlight/languages/yaml.dart' show yaml;
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/widget/json_editor/widget_json_tree.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget/widget_version_state.dart';
import 'package:jsonschema/widget_state/state_model.dart';
import 'package:jsonschema/widget_state/widget_md_doc.dart';

import '../../widget/widget_split.dart';

// ignore: must_be_immutable
class WidgetModelSelector extends StatelessWidget with WidgetModelHelper {
  WidgetModelSelector({
    super.key,
    required this.listModel,
    required this.typeModel,
  });
  final ModelSchema listModel;
  final GlobalKey keyYamlListModel = GlobalKey();
  final GlobalKey<JsonListEditorState> keyListModelInfo = GlobalKey();
  final TypeModelBreadcrumb typeModel;
  late TextConfig textConfig;

  @override
  Widget build(BuildContext context) {

    void onYamlChange(String yaml, TextConfig config) {
      if (listModel.modelYaml != yaml) {
        listModel.modelYaml = yaml;
        listModel.doChangeAndRepaintYaml(config, true, 'change');
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
      primaryWidth: 350,
      children: [
        getStructureModel(),
        JsonListEditor(
          key: keyListModelInfo,
          config:
              JsonTreeConfig(
                  textConfig: textConfig,
                  getModel: () => listModel,
                  onTap: (NodeAttribut node) {
                    _goToModel(node, 1);
                  },
                  onDoubleTap: (NodeAttribut node) {
                    _goToModel(node, 1);
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
          schema: listModel,
          propName: 'title',
        ),
      ),
    );

    //addWidgetMasterId(attr, row);

    if (attr.info.type == 'model') {
      row.add(SizedBox(width: 10));
      row.add(WidgetVersionState(margeVertical: 2));
      row.add(
        TextButton.icon(
          onPressed: () async {
            await _goToModel(attr, 1);
          },
          label: Icon(Icons.remove_red_eye),
        ),
      );
      row.add(
        TextButton.icon(
          icon: Icon(Icons.import_export),
          onPressed: () async {
            if (attr.info.type == 'model') {
              await _goToModel(attr, 2);
              // var key = attr.info.properties![constMasterID];
              // var model = ModelSchemaDetail(
              //   type: YamlType.model,
              //   name: attr.info.name,
              //   id: key,
              //   infoManager: InfoManagerModel(typeMD: TypeMD.model),
              // );
              // await model.loadYamlAndProperties(cache: false);
              // await ExportJsonSchema2clipboard().doExport(model);
            }
          },
          label: Text('Json schemas'),
        ),
      );
    }

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

  Future<void> _goToModel(NodeAttribut attr, int tabNumber) async {
    if (attr.info.type == 'model') {
      stateModel.tabDisable.clear();
      // ignore: invalid_use_of_protected_member
      stateModel.keyTab.currentState?.setState(() {});

      var key = attr.info.properties![constMasterID];
      currentCompany.currentModel = ModelSchema(
        category: Category.model,
        infoManager: InfoManagerModel(typeMD: TypeMD.model),
        headerName: attr.info.name,
        id: key,
      );
      currentCompany.currentModelSel = attr;
      listModel.currentAttr = attr;
      if (withBdd) {
        await currentCompany.currentModel!.loadYamlAndProperties(
          cache: false,
          withProperties: true,
        );
      }

      NodeAttribut? n = attr;
      List<String> modelPath = currentCompany.currentModel!.modelPath;
      currentCompany.currentModel!.typeBreabcrumb = typeModel;
      while (n != null) {
        if (n.parent != null) {
          modelPath.insert(0, n.info.name);
        }
        n = n.parent;
      }

      currentCompany.currentModel!.initBreadcrumb();

      stateModel.tabModel.animateTo(tabNumber);
      // ignore: invalid_use_of_protected_member
      stateModel.keyModelEditor.currentState?.setState(() {});
    }
  }

  Widget getStructureModel() {
    return Container(
      color: Colors.black,
      child: TextEditor(
        header: TypeModelBreadcrumb.valString(listModel.typeBreabcrumb!),
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
