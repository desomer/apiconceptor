import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/async_api/pan_attribut_editor_async.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/tree_editor/pan_yaml_tree.dart';
import 'package:jsonschema/widget/tree_editor/tree_view.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget/widget_overflow.dart';

enum TypeAsyncSelector { model }

// ignore: must_be_immutable
class PanAsyncSelector extends PanYamlTree {
  PanAsyncSelector({
    super.key,
    required super.getSchemaFct,
    required this.type,
    this.onSelect,
  });

  final TypeAsyncSelector type;
  final Function? onSelect;

  @override
  bool withEditor() {
    return type == TypeAsyncSelector.model;
  }

  @override
  void addRowWidget(
    TreeNodeData<NodeAttribut> node,
    ModelSchema schema,
    List<Widget> row,
    BuildContext context,
  ) {
    schema.infoManager.addRowWidget(node.data, schema, row, context);
  }
  //   var attr = node.data;

  //   if (attr.info.type == 'root') {
  //     row.add(Container(height: rowHeight));
  //     return;
  //   }

  //   // row.add(SizedBox(width: 10));
  //   row.add(
  //     CellEditor(
  //       inArray: true,
  //       key: ValueKey(
  //         '${schema.getVersionId()}%${attr.info.name}%${attr.info.numUpdateForKey}',
  //       ),
  //       acces: ModelAccessorAttr(node: attr, schema: schema, propName: 'title'),
  //     ),
  //   );

  //   //addWidgetMasterId(attr, row);

  //   if (attr.info.type != 'folder' && type == TypeAsyncSelector.model) {
  //     row.add(SizedBox(width: 10));
  //     row.add(
  //       WidgetVersionState(
  //         margeVertical: 2,
  //         version: null,
  //         model: getSchema(),
  //         attr: attr,
  //         modelParent: currentCompany.listModel!,
  //       ),
  //     );
  //     row.add(
  //       Padding(
  //         padding: EdgeInsetsGeometry.fromLTRB(5, 0, 0, 0),
  //         child: getChip(
  //           Text(attr.info.properties?['#version'] ?? ''),
  //           color: null,
  //         ),
  //       ),
  //     );
  //     // row.add(
  //     //   TextButton.icon(
  //     //     onPressed: () async {
  //     //       node.doTapHeader();
  //     //     },
  //     //     label: Icon(Icons.remove_red_eye),
  //     //   ),
  //     // );
  //     // row.add(
  //     //   TextButton.icon(
  //     //     icon: Icon(Icons.import_export),
  //     //     onPressed: () async {
  //     //       if (attr.info.type == 'model') {
  //     //         var key = attr.info.properties![constMasterID];

  //     //         // ignore: use_build_context_synchronously
  //     //         context.push(Pages.modelJsonSchema.id(key));
  //     //       }
  //     //     },
  //     //     label: Text('Json schemas'),
  //     //   ),
  //     // );
  //   }
  // }

  @override
  Future<void> onActionRow(
    TreeNodeData<NodeAttribut> node,
    BuildContext context,
  ) async {
    var attr = node.data;
    if (attr.info.type != 'folder') {
      //var key = attr.info.properties![constMasterID];

      // ignore: use_build_context_synchronously
      //RouteManager.goto(Pages.modelDetail.id(key), context);

      //context.push(Pages.modelDetail.url);
    } else {
      node.doToogleChild();
    }
  }

  @override
  void doDoubleTapRow(NodeAttribut data, BuildContext context) {
    var attr = data;
    if (attr.info.type != 'folder') {
      //var key = attr.info.properties![constMasterID];

      // // ignore: use_build_context_synchronously
      // RouteManager.goto(Pages.modelDetail.id(key), context);

      //context.push(Pages.modelDetail.url);
    }
  }

  @override
  Widget? getAttributProperties(BuildContext context) {
    return EditorProperties(
      typeAttr: TypeAttr.asyncapi,
      key: keyAttrEditor,
      getModel: () {
        return getSchema();
      },
      onClose: () {
        doShowAttrEditor(null);
      },
    );
  }

  // Future<void> showImportDialog(BuildContext ctx) async {
  //   return showDialog<void>(
  //     context: ctx,
  //     barrierDismissible: false, // user must tap button!
  //     builder: (BuildContext context) {
  //       return PanModelImportDialog(yamlEditorConfig: getYamlConfig());
  //     },
  //   );
  // }
}

class InfoManagerAsync extends InfoManager with WidgetHelper {
  @override
  void addRowWidget(
    NodeAttribut attr,
    ModelSchema schema,
    List<Widget> row,
    BuildContext context,
  ) {
    if (attr.info.type == 'root') {
      row.add(Container(height: rowHeight));
      return;
    }

    row.add(
      CellEditor(
        inArray: true,
        key: ValueKey(
          '${schema.getVersionId()}%${attr.info.name}%${attr.info.numUpdateForKey}',
        ),
        acces: ModelAccessorAttr(
          node: attr,
          schema: schema,
          propName: 'summary',
        ),
      ),
    );

    if (attr.info.type == 'folder') {
      // row.add(Container(height: rowHeight));
      //     row.add(SizedBox(width: 10));
      row.add(SizedBox(width: 10));
      row.add(_getAsyncType(attr, false, context));
      return;
    }
    if (['send', 'receive'].contains(attr.info.type)) {
  
      return;
    }
    if (['message'].contains(attr.info.type)) {
      row.add(SizedBox(width: 10));
      row.add(
        ElevatedButton(
          onPressed: () {
            //currentCompany.currentApps = schema;
            //schema.selectedAttr = attr;
            //RouteManager.goto(Pages.pageViewer.id(attr.info.masterID!), context);
          },
          child: Text('Definition'),
        ),
      );
      return;
    }
  }

  Widget _getAsyncType(NodeAttribut attr, bool isRoot, BuildContext context) {
    bool hasError = attr.info.error?[EnumErrorType.errorRef] != null;
    hasError = hasError || attr.info.error?[EnumErrorType.errorType] != null;

    String type = "google pubsub";

    // if (type == '\$ref' ||
    //     attr.info.name == constInherit ||
    //     attr.info.name.startsWith(constTypeOf) ||
    //     type == '\$anyOf' ||
    //     type == '\$oneOf') {
    //   return SizedBox.shrink();
    // }

    var w = getChip(
      Row(
        spacing: 5,
        children: [Text(type), Icon(Icons.arrow_drop_down, size: 15)],
      ),
      color: hasError ? Colors.redAccent : null,
    );

    bool canEditType = modelSchema?.isReadOnlyModel == false && !isRoot
    //&& !attr.info.isRefAttr() &&
    // !attr.info.type.startsWith(r'$')
    ;
    if (canEditType) {
      return _getEditorAsyncType(attr, context, w);
    }
    return w;
  }

  Widget _getEditorAsyncType(
    NodeAttribut attr,
    BuildContext context,
    Widget child,
  ) {
    GlobalKey? k = GlobalKey();

    return GestureDetector(
      key: k,
      onTap: () {
        var listOptions = [
          OptionSelect(
            label: 'pubsub',
            name: 'pubsub',
            icon: Icons.wifi,
            color: Colors.green,
          ),
          OptionSelect(
            label: 'kafka',
            name: 'kafka',
            icon: Icons.mail_outline_outlined,
            color: Colors.orangeAccent,
          ),
          OptionSelect(
            label: 'websocket',
            name: 'websocket',
            icon: Icons.send_outlined,
            color: Colors.blueGrey,
          ),

          // OptionSelect(
          //   label: '\$type',
          //   name: '\$type',
          //   icon: Icons.type_specimen_outlined,
          //   color: Colors.brown,
          // ),
        ];

        // currentCompany.listModel?.mapInfoByTreePath.forEach((key, value) {
        //   if (value.type == 'model') {
        //     listOptions.add(
        //       OptionSelect(
        //         label: '\$${value.name}',
        //         name: key,
        //         icon: Icons.data_object,
        //         color: Colors.blueGrey,
        //       ),
        //     );
        //   }
        // });

        _openTypeAsyncSelector(editor!, context, listOptions, attr, k);
      },
      child: child,
    );
  }

  void _openTypeAsyncSelector(
    PanYamlTree editor,
    BuildContext context,
    List<OptionSelect> listOptions,
    NodeAttribut attr,
    GlobalKey<State<StatefulWidget>> k,
  ) {
    BuildContext? bCtx;

    dialogBuilderBelow(
      context,
      SizedBox(
        width: 110,
        height: 220,
        child: ListView(
          children: listOptions.map<Widget>((option) {
            return ListTile(
              dense: true,
              leading: Icon(option.icon, color: option.color),
              title: Text(option.label),
              onTap: () {
                bCtx?.pop();

                // raffraichir l'éditeur d'attribut
                SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
                  // ignore: invalid_use_of_protected_member
                  editor.keyAttrEditor.currentState?.setState(() {});
                });
              },
            );
          }).toList(),
        ),
      ),
      k,
      Offset(-40, -20),
      (BuildContext ctx) {
        bCtx = ctx;
      },
    );
  }

  @override
  String getTypeTitle(NodeAttribut node, String name, dynamic type) {
    String? typeStr;
    if (type is Map) {
      node.bgcolor = Colors.blueGrey.withAlpha(50);
      typeStr = 'folder';
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

    // if (type.endsWith('[]')) {
    //   type = type.substring(0, type.length - 2);
    // }

    bool valid = [
      'folder',

      'channel',
      'message',
      'send',
      'receive',
    ].contains(type);
    if (!valid) {
      return InvalidInfo(color: Colors.red);
    }
    return null;
  }

  @override
  Function? getValidateKey() {
    return null;
  }

  @override
  Widget getRowHeader(TreeNodeData<NodeAttribut> node, BuildContext context) {
    Widget? icon;
    var isRoot = node.isRoot;
    var attr = node.data.info;
    var isFolder = attr.type == 'folder';
    var isChannel = attr.type == 'channel';

    var isMessage = attr.type == 'message';
    var isSend = attr.type == 'send';
    var isReceive = attr.type == 'receive';

    // var isAnyOf = attr.type == '\$anyOf';
    // var isOneOf = attr.type == '\$oneOf';
    // var isRef = attr.type == '\$ref';
    // var isType = attr.name == constType;
    // var isArray = attr.type == 'Array' || attr.type.endsWith('[]');
    // var isInherit = attr.name == constInherit;
    String name = attr.name;

    Color? iconColor = Colors.blueGrey;

    if (isRoot) {
      icon = Icon(Icons.business, color: iconColor, size: 20);
    } else if (isFolder) {
      icon = Icon(Icons.folder, color: iconColor, size: 20);
    } else if (isChannel) {
      iconColor = Colors.green;
      icon = Icon(Icons.wifi, color: iconColor, size: 20);
    } else if (isMessage) {
      iconColor = Colors.orangeAccent;
      icon = Icon(Icons.mail_outline_outlined, color: iconColor, size: 20);
    } else if (isSend) {
      icon = Icon(Icons.send_outlined, color: iconColor, size: 20);
    } else if (isReceive) {
      icon = Icon(Icons.send_and_archive_outlined, color: iconColor, size: 20);
    }

    // else if (isObject) {
    //   icon = Icon(Icons.data_object, color: iconColor, size: 20);
    // } else if (isRef) {
    //   icon = Icon(Icons.link, color: iconColor, size: 20);
    //   name = '\$${node.data.info.properties?[constRefOn] ?? '?'}';
    // } else if (isOneOf) {
    //   name = '\$oneOf';
    //   icon = Icon(Icons.looks_one_rounded, color: iconColor, size: 20);
    // } else if (isAnyOf) {
    //   name = '\$anyOf';
    //   icon = Icon(Icons.looks_one_rounded, color: iconColor, size: 20);
    // } else if (isArray) {
    //   icon = Icon(Icons.data_array, color: iconColor, size: 20);
    // } else if (isType) {
    //   name = '\$type';
    //   icon = Icon(Icons.type_specimen_outlined, color: iconColor, size: 20);
    // }

    var changeStyle = InfoManagerChangeStyle();
    changeStyle.initStyle(modelSchema!, node);

    Color? colorText = (attr.isRefAttr() ? Colors.grey : null);
    if (changeStyle.nameChange != null) {
      colorText = changeStyle.nameChange!;
    }

    bool isDeprecated = attr.properties?['deprecated'] == true;

    return NoOverflowErrorFlex(
      direction: Axis.horizontal,
      children: [
        if (icon != null)
          GestureDetector(
            onTap: () {
              node.doToogleChild();
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 2, 0),
              child: icon,
            ),
          ),
        // if (icon == null)
        Container(width: 5), // to align with other rows with icon
        Expanded(
          child: InkWell(
            onTap: () {
              node.doTapHeader();
            },
            child: NoOverflowErrorFlex(
              direction: Axis.horizontal,
              children: [
                // if (changeStyle.addColor != null)
                //   Padding(
                //     padding: const EdgeInsets.only(right: 3, top: 6, bottom: 6),
                //     child: Tooltip(
                //       message: 'Added',
                //       child: Container(width: 4, color: changeStyle.addColor),
                //     ),
                //   ),
                // if (changeStyle.pathChange != null)
                //   Padding(
                //     padding: const EdgeInsets.only(right: 3, top: 6, bottom: 6),
                //     child: Tooltip(
                //       message: 'Path changed ${changeStyle.tooltipMessage}',
                //       child: Container(width: 4, color: changeStyle.pathChange),
                //     ),
                //   ), // for error display   // for error display
                Expanded(
                  child: _getTooltipText(
                    changeStyle,
                    'Name ',
                    _getBorder(
                      attr,
                      Text(
                        overflow: TextOverflow.fade,
                        maxLines: 1,
                        name,
                        style: (isChannel)
                            ? TextStyle(
                                decoration: isDeprecated
                                    ? TextDecoration.lineThrough
                                    : null,
                                fontWeight: FontWeight.bold,
                                color: colorText,
                                fontSize: 14,
                              )
                            : TextStyle(
                                color: colorText,
                                fontSize: 14,
                                decoration: isDeprecated
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                      ),
                    ),
                  ),
                ),
                //Spacer(),
                _getWidgetType(node.data, isRoot, context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _getBorder(AttributInfo attr, Widget child) {
    if (attr.type == '\$ref') {
      return NoOverflowErrorFlex(
        direction: Axis.horizontal,
        mainAxisSize: MainAxisSize.max,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(5, 0, 5, 0),
            decoration: BoxDecoration(
              color: Colors.grey.withAlpha(100),
              borderRadius: BorderRadius.all(Radius.circular(5)),
              border: Border.all(color: Colors.blueGrey, width: 1),
            ),
            child: child,
          ),
          Spacer(),
        ],
      );
    }

    return child;
  }

  Widget _getTooltipText(
    InfoManagerChangeStyle changeStyle,
    String message,
    Widget child,
  ) {
    if (changeStyle.tooltipMessage == null) return child;

    return Tooltip(
      message: '$message ${changeStyle.tooltipMessage}',
      child: child,
    );
  }

  Widget _getWidgetType(NodeAttribut attr, bool isRoot, BuildContext context) {
    if (isRoot) {
      return Text('${modelSchema?.useAttributInfo.length} properties');
    }

    bool hasError = attr.info.error?[EnumErrorType.errorRef] != null;
    hasError = hasError || attr.info.error?[EnumErrorType.errorType] != null;

    String type = attr.info.type;

    if (type == 'folder') {
      return SizedBox.shrink();
    }

    // if (type == '\$ref' ||
    //     attr.info.name == constInherit ||
    //     attr.info.name.startsWith(constTypeOf) ||
    //     type == '\$anyOf' ||
    //     type == '\$oneOf') {
    //   return SizedBox.shrink();
    // }

    var w = getChip(
      Row(
        spacing: 5,
        children: [Text(type), Icon(Icons.arrow_drop_down, size: 15)],
      ),
      color: hasError ? Colors.redAccent : null,
    );

    bool canEditType = modelSchema?.isReadOnlyModel == false && !isRoot
    //&& !attr.info.isRefAttr() &&
    // !attr.info.type.startsWith(r'$')
    ;
    if (canEditType) {
      return _getEditorType(attr, context, w);
    }
    return w;
  }

  Widget _getEditorType(NodeAttribut attr, BuildContext context, Widget child) {
    GlobalKey? k = GlobalKey();

    return GestureDetector(
      key: k,
      onTap: () {
        var listOptions = [
          OptionSelect(
            label: 'channel',
            name: 'channel',
            icon: Icons.wifi,
            color: Colors.green,
          ),
          OptionSelect(
            label: 'message',
            name: 'message',
            icon: Icons.mail_outline_outlined,
            color: Colors.orangeAccent,
          ),
          OptionSelect(
            label: 'send',
            name: 'send',
            icon: Icons.send_outlined,
            color: Colors.blueGrey,
          ),
          OptionSelect(
            label: 'receive',
            name: 'receive',
            icon: Icons.send_and_archive_outlined,
            color: Colors.blueGrey,
          ),

          // OptionSelect(
          //   label: '\$type',
          //   name: '\$type',
          //   icon: Icons.type_specimen_outlined,
          //   color: Colors.brown,
          // ),
        ];

        // currentCompany.listModel?.mapInfoByTreePath.forEach((key, value) {
        //   if (value.type == 'model') {
        //     listOptions.add(
        //       OptionSelect(
        //         label: '\$${value.name}',
        //         name: key,
        //         icon: Icons.data_object,
        //         color: Colors.blueGrey,
        //       ),
        //     );
        //   }
        // });

        openTypeSelector(editor!, context, listOptions, attr, k);
      },
      child: child,
    );
  }
}
