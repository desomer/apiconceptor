import 'package:flutter/material.dart';
import 'package:highlight/languages/yaml.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:intl/intl.dart';
import 'package:jsonschema/core/repaint_manager.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/feature/api/pan_api_editor.dart';
import 'package:jsonschema/feature/pan_attribut_editor.dart';
import 'package:jsonschema/widget/tree_editor/widget_json_tree.dart';
import 'package:jsonschema/widget/widget_hidden_box.dart';
import 'package:jsonschema/widget/widget_hover.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget_state/state_api.dart';
import 'package:jsonschema/widget/widget_md_doc.dart';

// ignore: must_be_immutable
class PanAPITrashcan extends StatelessWidget with WidgetHelper {
  PanAPITrashcan({super.key, required this.getModelFct});
  CodeEditorConfig? textConfig;
  final ValueNotifier<double> showAttrEditor = ValueNotifier(0);
  State? rowSelected;
  final GlobalKey keyAttrEditor = GlobalKey(
    debugLabel: 'PanAPITrashcankeyAttrEditor',
  );
  final GlobalKey treeEditor = GlobalKey(
    debugLabel: 'PanAPITrashcankeyAttrEditor',
  );
  final Function getModelFct;
  ModelSchema? modelToDisplay;

  @override
  Widget build(BuildContext context) {
    Future<ModelSchema> futureModel = getModelFct();

    getYaml() {
      return modelToDisplay?.modelYaml;
    }

    textConfig ??= CodeEditorConfig(
      mode: yaml,
      notifError: ValueNotifier<String>(''),
      onChange: () {},
      getText: getYaml,
    );

    var model = Row(
      children: [
        Expanded(
          child: JsonListEditor(
            key: treeEditor,
            config:
                JsonTreeConfig(
                    textConfig: textConfig,
                    getModel: () => modelToDisplay,
                    onTap: (NodeAttribut node, BuildContext context) {
                      _goToAPI(node, 1);
                      return true;
                    },
                  )
                  ..getJson = getYaml
                  ..getRow = _getRowModelInfo,
          ),
        ),
        WidgetHiddenBox(
          showNotifier: showAttrEditor,
          child: EditorProperties(
            typeAttr: TypeAttr.model,
            key: keyAttrEditor,
            getModel: () {
              return modelToDisplay;
            },
          ),
        ),
      ],
    );

    return FutureBuilder<ModelSchema>(
      future: futureModel,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          modelToDisplay = snapshot.data;
          return model;
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          return Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  var inputFormat = DateFormat('dd/MM/yyyy HH:mm:ss');

  Widget _getRowModelInfo(
    NodeAttribut attr,
    ModelSchema schema,
    BuildContext context,
  ) {
    if (attr.info.type == 'root') {
      return Container(height: rowHeight);
    }

    if (attr.level == 1) {
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
          editable: false,
        ),
      ),
    );

    row.add(
      Text(
        ' version: ${attr.info.properties!['_\$\$version']}',
        // style: TextStyle(fontSize: 10, color: Colors.grey),
      ),
    );

    row.add(
      TextButton.icon(
        onPressed: () async {},
        label: Icon(Icons.delete, size: 20, color: Colors.red),
      ),
    );

    row.add(
      TextButton.icon(
        onPressed: () async {},
        label: Icon(Icons.restore, size: 20),
      ),
    );

    var inputDate = '';
    if (attr.info.timeLastUpdate != null) {
      inputDate = ' at ${inputFormat.format(attr.info.timeLastUpdate!)}';
    }

    row.add(Text(inputDate));

    var ret = SizedBox(
      height: rowHeight,
      child: InkWell(
        onTap: () {
          _doShowAttrEditor(schema, attr);
          if (rowSelected?.mounted == true) {
            // ignore: invalid_use_of_protected_member
            rowSelected?.setState(() {});
          }
        },

        onDoubleTap: () async {
          await _goToAPI(attr, 1);
        },
        child: HoverableCard(
          isSelected: (State state) {
            attr.widgetSelectState = state;
            bool isSelected = schema.selectedAttr == attr;
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

  void _doShowAttrEditor(ModelSchema schema, NodeAttribut attr) {
    if (schema.selectedAttr == attr && showAttrEditor.value == 300) {
      showAttrEditor.value = 0;
    } else {
      showAttrEditor.value = 300;
    }
    schema.selectedAttr = attr;
    //ignore: invalid_use_of_protected_member
    keyAttrEditor.currentState?.setState(() {});
  }

  Future<void> _goToAPI(
    NodeAttribut attr,
    int tabNumber, {
    int subtabNumber = -1,
  }) async {
    if (attr.level == 2) {
      //stateApi.tabDisable.clear();
      // ignore: invalid_use_of_protected_member
      // stateApi.keyTab.currentState?.setState(() {});

      NodeAttribut? n = attr.parent;
      var modelPath = [];
      while (n != null) {
        if (n.parent != null) {
          modelPath.insert(0, n.info.name);
        }

        n = n.parent;
      }

      // BreadCrumbNavigator.setPath(["Trashcan API", ...modelPath, "draft"]);

      // stateApi.path = ["Tashcan API", ...modelPath, "0.0.1", "draft"];
      // // ignore: invalid_use_of_protected_member
      // stateApi.keyBreadcrumb.currentState?.setState(() {});

      currentCompany.listAPI!.selectedAttr = attr;

      var key = attr.info.name;
      currentCompany.currentAPIResquest = ModelSchema(
        category: Category.api,
        infoManager: InfoManagerAPIParam(typeMD: TypeMD.apiparam),
        headerName: 'trashcan/${attr.info.type}',
        id: key,
        ref: currentCompany.listModel,
      );

      await currentCompany.currentAPIResquest!.loadYamlAndProperties(
        cache: false,
        withProperties: true,
      );
      currentCompany.currentAPIResquest!.onChange = (change) {
        //currentCompany.currentAPICallInfo?.params.clear();
        repaintManager.doRepaint(ChangeTag.apiparam);
      };

      currentCompany.currentAPIResponse = ModelSchema(
        category: Category.api,
        infoManager: InfoManagerAPIParam(typeMD: TypeMD.apiparam),
        headerName: attr.info.name,
        id: 'response/$key',
        ref: currentCompany.listModel,
      );

      await currentCompany.currentAPIResponse!.loadYamlAndProperties(
        cache: false,
        withProperties: true,
      );

      repaintManager.doRepaint(ChangeTag.apichange);

      //stateApi.tabApi?.index = tabNumber;
      Future.delayed(Duration(milliseconds: 100)).then((value) {
        stateApi.tabSubApi?.index = 0; // charge l'ordre des params
        Future.delayed(Duration(milliseconds: 100)).then((value) {
          if (subtabNumber >= 0) {
            // exemple : aller sur le test d'api
            stateApi.tabSubApi?.index = subtabNumber;
          }
        });
      });
    }
  }
}
