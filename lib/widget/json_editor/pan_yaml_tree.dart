import 'package:flutter/material.dart';
import 'package:highlight/languages/yaml.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/feature/api/pan_api_info.dart';
import 'package:jsonschema/widget/json_editor/widget_json_tree.dart';
import 'package:jsonschema/widget/widget_hidden_box.dart';
import 'package:jsonschema/widget/widget_hover.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget/widget_split.dart';
import 'package:jsonschema/widget_state/widget_md_doc.dart';

// ignore: must_be_immutable
abstract class PanYamlTree extends StatelessWidget with WidgetModelHelper {
  PanYamlTree({super.key, required this.getSchemaFct});
  TextConfig? textConfig;
  final ValueNotifier<double> showAttrEditor = ValueNotifier(0);
  State? rowSelected;

  final GlobalKey yamlEditor = GlobalKey();
  final GlobalKey treeEditor = GlobalKey();
  final GlobalKey keyAttrEditor = GlobalKey();

  final Function getSchemaFct;
  ModelSchema? schema;

  Function getOnChange() {
    return (String yaml, TextConfig config) {
      var model = schema!;
      if (model.modelYaml != yaml) {
        model.modelYaml = yaml;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onYamlChange();
          model.doChangeAndRepaintYaml(
            config,
            model.autoSaveProperties,
            'change',
          );
        });
      }
    };
  }

  void onYamlChange() {}
  void onInit() {}

  Widget getLeftPan() {
    return getYamlEditor();
  }

  Widget getRightPan(Widget viewer) {
    return viewer;
  }

  Widget? getDoc() {
    return WidgetMdDoc(type: TypeMD.listmodel);
  }

  String getHeaderCode() {
    return TypeModelBreadcrumb.valString(schema!.typeBreabcrumb);
  }

  Widget getYamlEditor() {
    var doc = getDoc();

    return Container(
      color: Colors.black,
      child: TextEditor(
        header: getHeaderCode(),
        onHelp:
            doc != null
                ? (BuildContext ctx) {
                  showDialog(
                    context: ctx,
                    barrierDismissible: true,
                    builder: (BuildContext context) {
                      return doc;
                    },
                  );
                }
                : null,
        key: yamlEditor,
        config: textConfig!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Future<ModelSchema> futureModel = getSchemaFct();
    return FutureBuilder<ModelSchema>(
      future: futureModel,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          schema = snapshot.data;

          Widget split = getContent();

          return split;
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          return Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  Widget getContent() {
    getYaml() {
      return schema?.modelYaml;
    }

    textConfig ??= TextConfig(
      mode: yaml,
      notifError: ValueNotifier<String>(''),
      onChange: getOnChange(),
      getText: getYaml,
    );

    var attrViewer = Row(
      children: [
        Expanded(
          child: JsonListEditor(
            key: treeEditor,
            config:
                JsonTreeConfig(
                    textConfig: textConfig,
                    getModel: () => schema,
                    onTap: (NodeAttribut node) {
                      if (node.level > 0) goToModel(node, 1);
                    },
                  )
                  ..getJson = getYaml
                  ..getRow = _getRowInfo,
          ),
        ),
        WidgetHiddenBox(
          showNotifier: showAttrEditor,
          child: APIProperties(
            typeAttr: TypeAttr.model,
            key: keyAttrEditor,
            getModel: () {
              return schema;
            },
          ),
        ),
      ],
    );

    Widget split = SplitView(
      primaryWidth: 350,
      children: [getLeftPan(), getRightPan(attrViewer)],
    );
    return split;
  }

  void addRowWidget(NodeAttribut attr, ModelSchema schema, List<Widget> row) {}

  Widget _getRowInfo(NodeAttribut attr, ModelSchema schema) {
    if (attr.info.type == 'root') {
      return Container(height: rowHeight);
    }

    List<Widget> row = [SizedBox(width: 10)];

    addRowWidget(attr, schema, row);
    schema.infoManager.getAttributRow(attr, schema, row);

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
          await goToModel(attr, 1);
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
          child: getToolTip(
            toolContent: getTooltipFromAttr(attr),
            child: Row(spacing: 5, children: row),
          ),
        ),
      ),
    );
    return ret;
  }

  void _doShowAttrEditor(ModelSchema schema, NodeAttribut attr) {
    if (schema.currentAttr == attr && showAttrEditor.value == 300) {
      showAttrEditor.value = 0;
    } else {
      showAttrEditor.value = 300;
    }
    schema.currentAttr = attr;
    //ignore: invalid_use_of_protected_member
    keyAttrEditor.currentState?.setState(() {});
  }

  Future<void> goToModel(NodeAttribut attr, int tabNumber) async {
    // if (attr.info.type == 'model') {
    //   stateModel.tabDisable.clear();
    //   // ignore: invalid_use_of_protected_member
    //   stateModel.keyTab.currentState?.setState(() {});

    //   var key = attr.info.properties![constMasterID];
    //   currentCompany.currentModel = ModelSchema(
    //     type: YamlType.model,
    //     infoManager: InfoManagerModel(typeMD: TypeMD.model),
    //     headerName: attr.info.name,
    //     id: key,
    //   );
    //   currentCompany.currentModelSel = attr;
    //   //listModel.currentAttr = attr;
    //   if (withBdd) {
    //     await currentCompany.currentModel!.loadYamlAndProperties(
    //       cache: false,
    //       withProperties: true,
    //     );
    //   }

    //   NodeAttribut? n = attr;
    //   List<String> modelPath = currentCompany.currentModel!.modelPath;
    //   //  currentCompany.currentModel!.typeBreabcrumb = typeModel;
    //   while (n != null) {
    //     if (n.parent != null) {
    //       modelPath.insert(0, n.info.name);
    //     }
    //     n = n.parent;
    //   }

    //   currentCompany.currentModel!.initBreadcrumb();

    //   stateModel.tabModel.animateTo(tabNumber);
    //   // ignore: invalid_use_of_protected_member
    //   stateModel.keyModelEditor.currentState?.setState(() {});
    // }
  }
}
