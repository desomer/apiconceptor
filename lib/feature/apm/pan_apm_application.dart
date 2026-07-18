import 'package:flutter/material.dart';
import 'package:jsonschema/authorization_manager.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/apm/widget_app_sheet.dart';
import 'package:jsonschema/feature/pan_attribut_editor_model.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/widget/tree_editor/pan_yaml_tree.dart';
import 'package:jsonschema/widget/tree_editor/tree_view.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget/widget_overflow.dart';

List<String> autorizedType = [
  'saas',
  'app',
  'customapp',
  'webapp',
  'mobile',
  'microservice',
  'middleware',
  'dataplatform',
];

// ignore: must_be_immutable
class PanAPMApplication extends PanYamlTree {
  PanAPMApplication({super.key, required super.getSchemaFct});

  // @override
  // void onInitSchema(BuildContext context) {
  //   getSchema().onChange = (change) {
  //     NodeAttribut node = change['node'];
  //     String ope = change['ope'];
  //     String path = change['path'];
  //     String? from = change['from'];
  //     if (ope == ChangeOpe.rename.name) {
  //       var sp = from!.split('>');
  //       currentCompany.glossaryManager.dico.remove(sp.last.toLowerCase());
  //     }
  //     if (ope == ChangeOpe.remove.name) {
  //       currentCompany.glossaryManager.dico.remove(
  //         node.info.name.toLowerCase(),
  //       );
  //     } else if (ope != ChangeOpe.change.name || path.endsWith('.type')) {
  //       if (autorizedGlossaryType.contains(node.info.type)) {
  //         currentCompany.glossaryManager.add(node);
  //       }
  //     }
  //   };
  // }

  @override
  void doDoubleTapRow(NodeAttribut data, BuildContext context) {
    scrollCodeEditorTo(data);
  }

  @override
  Widget? overrideGetWidgetPropForTooltip(String key, value) {
    return null;
  }

  @override
  void addRowWidget(
    TreeNodeData<NodeAttribut> node,
    ModelSchema schema,
    List<Widget> row,
    BuildContext context,
  ) {
    var attr = node.data;

    if (attr.info.type == 'root') {
      row.add(Container(height: rowHeight));
      return;
    }

    row.add(const SizedBox(width: 10));
    row.add(
      CellEditor(
        inArray: true,
        key: ValueKey(
          '${schema.getVersionId()}%${attr.info.name}%${attr.info.numUpdateForKey}',
        ),
        acces: ModelAccessorAttr(node: attr, schema: schema, propName: 'title'),
      ),
    );
    if (attr.info.type != 'root' && attr.info.type != 'category') {
      row.add(getBtnProfile(context, attr));
    }
    if (attr.info.type == 'microservice') {
      row.add(getBtnPrompt(context, attr));
    }    
  }

  TextButton getBtnPrompt(BuildContext context, NodeAttribut attr) {
    return TextButton.icon(
      icon: const Icon(Icons.smart_toy),
      onPressed: () {
        Pages.apmAppPrompt.goto(context);
      },
      label: const Text('AI Prompt'),
    );
  }

  TextButton getBtnProfile(BuildContext context, NodeAttribut attr) {
    return TextButton(
      onPressed: () {
        // dialog to show application profile WidgetAppSheet
        showDialog<void>(
          context: context,
          barrierDismissible: true, // user must tap button!
          builder: (BuildContext dialogContext) {
            Size size = MediaQuery.of(dialogContext).size;
            double width = (size.width * 0.9).clamp(0.0, 600.0).toDouble();
            double height = size.height * 0.8;

            ModelSchema tempModel = ModelSchema(
              category: Category.apm,
              headerName: '',
              id: '',
              infoManager: InfoManagerApmAppli(),
              refDomain: null,
            );
            tempModel.autoSaveProperties = false;

            var mapEntryEmpty = const MapEntry('', null);
            tempModel.selectedAttr = NodeAttribut(
              yamlNode: mapEntryEmpty,
              info: AttributInfo()
                ..properties = {...attr.info.properties ?? {}},
              parent: null,
            );

            return AlertDialog(
              content: SizedBox(
                width: width,
                height: height,
                child: SingleChildScrollView(
                  child: WidgetAppSheet(model: tempModel),
                ),
              ),
              actions: [
                TextButton.icon(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close),
                  label: const Text('Close'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    tempModel.selectedAttr?.info.properties?.forEach((
                      key,
                      value,
                    ) {
                      if (key == 'identity.logo') {
                        attr = currentCompany.currentAPM!.getExtendedNode(
                          attr.info.getMasterID(),
                        );
                        attr.info.singleSaveKey = 'identity.logo';
                      }
                      var accessor = ModelAccessorAttr(
                        node: attr,
                        schema: currentCompany.currentAPM,
                        propName: key,
                      );
                      accessor.set(value);
                    });
                    // retire the model to avoid saving changes on close
                    attr.info.properties?.forEach((key, value) {
                      if (!['title', constMasterID].contains(key) &&
                          tempModel.selectedAttr?.info.properties?[key] ==
                              null) {
                        if (key == 'identity.logo') {
                          attr = currentCompany.currentAPM!.getExtendedNode(
                            attr.info.getMasterID(),
                          );
                          attr.info.singleSaveKey = 'identity.logo';
                        }
                        var accessor = ModelAccessorAttr(
                          node: attr,
                          schema: currentCompany.currentAPM,
                          propName: key,
                        );
                        accessor.remove();
                      }
                    });

                    Navigator.of(dialogContext).pop();
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
      child: const Text('Application Profile'),
    );
  }

  @override
  Widget? getAttributProperties(BuildContext context) {
    return EditorProperties(
      typeAttr: TypeAttr.model,
      key: keyAttrEditor,
      getModel: () {
        return getSchema();
      },
      onClose: () {
        doShowAttrEditor(null);
      },
    );
  }
}

class InfoManagerApmAppli extends InfoManager with WidgetHelper {
  InfoManagerApmAppli();

  @override
  Function? getValidateKey() {
    return null;
  }

  @override
  String getTypeTitle(NodeAttribut node, String name, dynamic type) {
    String? typeStr;
    if (type is Map) {
      node.bgcolor = Colors.blueGrey.withAlpha(50);
      typeStr = 'category';
    }
    typeStr ??= '$type';
    return typeStr;
  }

  @override
  InvalidInfo? isTypeValid(
    NodeAttribut nodeAttribut,
    String name,
    dynamic type,
    String typeTitle,
  ) {
    var type = typeTitle.toLowerCase();
    bool valid = ['category', ...autorizedType].contains(type);
    if (!valid) {
      return InvalidInfo(color: Colors.red);
    }
    return null;
  }

  @override
  Widget getRowHeader(TreeNodeData<NodeAttribut> node, BuildContext context) {
    Widget? icon;
    var isRoot = node.isRoot;
    bool isCategory = node.data.info.type == 'category';

    if (isRoot) {
      icon = const Icon(Icons.business);
    } else if (isCategory) {
      icon = const Icon(Icons.folder);
    } else {
      icon = const Icon(Icons.label_outline);
    }

    var attr = node.data;

    bool hasError = attr.info.error?[EnumErrorType.errorRef] != null;
    hasError = hasError || attr.info.error?[EnumErrorType.errorType] != null;

    Widget w;

    if (!isRoot && !isCategory) {
      w = getChip(
        Row(
          spacing: 5,
          children: [
            Text(attr.info.type),
            const Icon(Icons.arrow_drop_down, size: 15),
          ],
        ),
        color: hasError ? Colors.red : null,
      );
      w = getEditorType(attr, context, w);
    } else {
      w = const SizedBox.shrink();
    }

    return NoOverflowErrorFlex(
      direction: Axis.horizontal,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(0, 0, 5, 0), child: icon),

        Expanded(
          child: InkWell(
            onTap: () {
              node.doTapHeader();
            },
            child: Row(
              children: [
                Text(
                  node.data.info.name,
                  style: (node.data.info.type == 'category')
                      ? const TextStyle(fontWeight: FontWeight.bold)
                      : null,
                ),
                const Spacer(),
                w,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget getEditorType(NodeAttribut attr, BuildContext context, Widget child) {
    GlobalKey? k = GlobalKey();

    return GestureDetector(
      key: k,
      onTap: () {
        var listOptions = <OptionSelect>[];

        for (var element in autorizedType) {
          listOptions.add(
            OptionSelect(
              label: element,
              name: element,
              icon: Icons.label_outline,
              color: Colors.blueGrey,
            ),
          );
        }

        openTypeSelector(editor!, context, listOptions, attr, k);
      },
      child: child,
    );
  }
}
