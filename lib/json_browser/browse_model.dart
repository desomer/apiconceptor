import 'package:animated_tree_view/tree_view/tree_node.dart';
import 'package:flutter/material.dart';
import 'package:json_schema/json_schema.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/tree_editor/tree_view.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget/widget_overflow.dart';

import '../widget/widget_md_doc.dart';

void validateJsonSchemas(
  JsonSchema validator,
  dynamic json,
  ValueNotifier<String> error,
) {
  ValidationResults r = validator.validate(json);
  // print("r= $r");
  if (r.isValid) {
    error.value = '_VALID_';
  } else {
    StringBuffer ret = StringBuffer();
    for (var element in r.errors) {
      ret.writeln('${element.instancePath} : ${element.message}');
    }
    error.value = ret.toString();
  }
}

var commentRE = RegExp(r'"(?:[^\\"]|\\[^])*"|/\*[^]*?\*/|//.*');
String removeComments(String jsonWithComments) =>
    jsonWithComments.replaceAllMapped(commentRE, (m) {
      var s = m[0]!;
      return s.startsWith('"') ? s : "";
    });

//************************************************************************* */
class BrowseModel<T extends Map> extends JsonBrowser<T> {
  BrowseModel({required super.config});

  @override
  void doTree(ModelSchema model, NodeAttribut aNodeAttribut, r) {
    if (aNodeAttribut.info.type == 'model') {
      initVersion(aNodeAttribut, r);
    }
    super.doTree(model, aNodeAttribut, r);
  }

  @override
  T? getRoot(NodeAttribut node) {
    return {} as T;
  }

  @override
  dynamic getChild(
    ModelSchema model,
    NodeAttribut parentNode,
    NodeAttribut node,
    dynamic parent,
  ) {
    if (config.isGet == true) {
      bool wr = node.info.properties?['writeOnly'] ?? false;
      if (wr) {
        return null;
      }
    }

    if (config.isApi == true &&
        !(node.info.properties?['#target']?.toString().contains('api') ??
            true)) {
      return null;
    }

    return parent;
  }

  void initVersion(NodeAttribut aNodeAttribut, r) {
    //print(aNodeAttribut.info.name);
  }
}

class BrowseSingle<T extends Map> extends JsonBrowser<T> {
  BrowseSingle({required super.config});
  List<NodeAttribut> root = [];

  @override
  T? getRoot(NodeAttribut node) {
    return {} as T;
  }

  @override
  dynamic getChild(
    ModelSchema model,
    NodeAttribut parentNode,
    NodeAttribut node,
    dynamic parent,
  ) {
    if (config.isGet == true) {
      bool wr = node.info.properties?['writeOnly'] ?? false;
      if (wr) {
        return null;
      }
    }

    if (config.isApi == true &&
        !(node.info.properties?['#target']?.toString().contains('api') ??
            true)) {
      return null;
    }

    root.add(node);
    return parent;
  }
}

class InfoManagerListModel extends InfoManager with WidgetHelper {
  InfoManagerListModel({required this.typeMD});
  final TypeMD typeMD;

  @override
  String getTypeTitle(NodeAttribut node, String name, dynamic type) {
    String? typeStr;
    if (type is Map) {
      node.bgcolor = Colors.blueGrey.withAlpha(50);
      typeStr = typeMD == TypeMD.listmodel ? 'folder' : 'Object';
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

    bool valid = ['folder', 'model'].contains(type);
    if (!valid) {
      return InvalidInfo(color: Colors.red);
    }
    return null;
  }

  @override
  Widget getAttributHeaderOLD(TreeNode<NodeAttribut> node) {
    return Container();
  }

  @override
  Widget getRowHeader(TreeNodeData<NodeAttribut> node, BuildContext context) {
    Widget? icon;
    var isRoot = node.isRoot;
    var attr = node.data.info;
    var isFolder = attr.type == 'folder';
    var isModel = attr.type == 'model';

    String name = attr.name;

    Color? iconColor =
        attr.isRefAttr() ? Colors.grey.shade800 : Colors.blueGrey;

    if (isRoot) {
      icon = Icon(Icons.business, color: iconColor);
    } else if (isFolder) {
      icon = Icon(Icons.folder, color: iconColor);
    } else if (isModel) {
      icon = Icon(Icons.data_object, color: iconColor);
    }

    return NoOverflowErrorFlex(
      direction: Axis.horizontal,
      children: [
        if (icon != null)
          Padding(padding: const EdgeInsets.fromLTRB(0, 0, 5, 0), child: icon),

        Expanded(
          child: InkWell(
            onTap: () {
              node.doTapHeader();
            },
            child: NoOverflowErrorFlex(
              direction: Axis.horizontal,
              children: [
                Expanded(
                  child: Text(name, overflow: TextOverflow.fade, maxLines: 1),
                ),
                getWidgetType(node.data, isModel, isRoot, context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget getWidgetType(
    NodeAttribut attr,
    bool isModel,
    bool isRoot,
    BuildContext context,
  ) {
    if (isRoot) return Container();

    bool hasError = attr.info.error?[EnumErrorType.errorRef] != null;
    hasError = hasError || attr.info.error?[EnumErrorType.errorType] != null;
    //String msg = hasError ? 'error type' : '';

    var w = getChip(
      isModel
          ? Row(
            spacing: 5,
            children: [
              Text(attr.info.type),
              Icon(Icons.arrow_forward_ios, size: 10),
            ],
          )
          : hasError
          ? Row(
            spacing: 5,
            children: [
              Text(attr.info.type),
              Icon(Icons.arrow_drop_down, size: 15),
            ],
          )
          : Text(attr.info.type),
      color: hasError ? Colors.redAccent : (isModel ? Colors.blue : null),
    );

    bool canEditType = !isRoot && attr.info.type != 'folder';
    if (canEditType && hasError) {
      return getEditorType(attr, context, w);
    }
    return w;
  }

  Widget getEditorType(NodeAttribut attr, BuildContext context, Widget child) {
    GlobalKey? k = GlobalKey();

    return GestureDetector(
      key: k,
      onTap: () {
        var listOptions = [
          OptionSelect(
            label: 'model',
            name: 'model',
            icon: Icons.data_object,
            color: Colors.blueGrey,
          ),
        ];

        openTypeSelector(editor!, context, listOptions, attr, k);
      },
      child: child,
    );
  }

  @override
  Function? getValidateKey() {
    return null;
  }
}

//**************************************************************************/
class InfoManagerChangeStyle {
  Color? addColor;
  Color? nameChange;
  Color? pathChange;
  String? tooltipMessage;

  void initStyle(ModelSchema modelSchema, TreeNodeData<NodeAttribut> node) {
    if (modelSchema.olderModelSchema != null && !node.isRoot) {
      var masterIDPath = node.data.info.getMasterIDPath();
      var exist = modelSchema.olderModelSchema!.getNodeByMasterIdPath(
        masterIDPath,
      );
      if (exist == null) {
        addColor = Colors.greenAccent;
      } else {
        if (exist.info.name != node.data.info.name) {
          nameChange = Colors.orangeAccent;
          tooltipMessage =
              'from "${exist.info.name}" to "${node.data.info.name}"';
        }
        if (exist.info.getJsonPath(onlyPath: true) !=
            node.data.info.getJsonPath(onlyPath: true)) {
          pathChange = Colors.yellowAccent;
          tooltipMessage =
              'from "${exist.info.getJsonPath(withRoot: false, sep: '.')}" to "${node.data.info.getJsonPath(withRoot: false, sep: '.')}"';
        }
      }
    }
  }
}

class InfoManagerModel extends InfoManager with WidgetHelper {
  InfoManagerModel({required this.typeMD});
  final TypeMD typeMD;

  @override
  String getTypeTitle(NodeAttribut node, String name, dynamic type) {
    String? typeStr;
    if (type is Map) {
      if (name.startsWith(constRefOn)) {
        typeStr = '\$ref';
      } else if (name.startsWith(constTypeAnyof)) {
        typeStr = '\$anyOf';
        node.bgcolor = Colors.orange.withAlpha(100);
      } else if (name.endsWith('[]')) {
        node.bgcolor = Colors.blue.withAlpha(100);
        typeStr = 'Array';
      } else {
        node.bgcolor = Colors.blueGrey.withAlpha(50);
        typeStr = typeMD == TypeMD.listmodel ? 'folder' : 'Object';
      }
    } else if (type is List) {
      if (name.endsWith('[]')) {
        typeStr = 'Array';
        node.bgcolor = Colors.blue.withAlpha(50);
      } else {
        node.bgcolor = Colors.blue.withAlpha(50);
        typeStr = 'Object';
      }
    } else if (type is int) {
      typeStr = 'integer';
    } else if (type is double) {
      typeStr = 'number';
    } else if (type is String) {
      if (name.endsWith('[]')) {
        node.bgcolor = Colors.blue.withAlpha(50);
        if (type.startsWith('\$')) {
          typeStr = 'Array';
        } else {
          typeStr = '$type[]';
        }
      } else if (type.startsWith('\$')) {
        typeStr = 'Object';
      }
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

    if (type.endsWith('[]')) {
      type = type.substring(0, type.length - 2);
    }

    bool valid = [
      'folder',
      'model',
      'string',
      'integer',
      'number',
      'object',
      'array',
      'boolean',
      '\$ref',
      '\$anyof',
      '\$inherit',
    ].contains(type);
    if (!valid) {
      return InvalidInfo(color: Colors.red);
    }
    return null;
  }

  @override
  Widget getAttributHeaderOLD(TreeNode<NodeAttribut> node) {
    var isRoot = node.isRoot;
    var isFolder = node.data!.info.type == 'folder';
    var isModel = node.data!.info.type == 'model';

    var isObject = node.data!.info.type == 'Object';
    var isOneOf = node.data!.info.type == '\$anyOf';
    var isRef = node.data!.info.type == '\$ref';
    var isType = node.data!.info.name == constType;
    var isInherit = node.data!.info.name == constInherit;
    var isArray =
        node.data!.info.type == 'Array' || node.data!.info.type.endsWith('[]');
    String name = node.data!.yamlNode.key.toString();

    Widget icon = Container(width: 20);
    if (isRoot) {
      icon = Icon(Icons.business);
    } else if (isInherit) {
      icon = Icon(Icons.call_split);
    } else if (isFolder) {
      icon = Icon(Icons.lan_outlined);
    } else if (isModel) {
      icon = Icon(Icons.data_object);
    } else if (isObject) {
      icon = Icon(Icons.data_object);
    } else if (isRef) {
      icon = Icon(Icons.link);
      name = '\$${node.data?.info.properties?[constRefOn] ?? '?'}';
    } else if (isOneOf) {
      name = '\$anyOf';
      icon = Icon(Icons.looks_one_rounded);
    } else if (isArray) {
      icon = Icon(Icons.data_array);
    } else if (isType) {
      name = '\$type';
      icon = Icon(Icons.type_specimen_outlined);
    }

    return GetHeaderRowWidget(
      icon: icon,
      name: name,
      isObject: isObject,
      isArray: isArray,
    );
  }

  @override
  Widget getRowHeader(TreeNodeData<NodeAttribut> node, BuildContext context) {
    Widget? icon;
    var isRoot = node.isRoot;
    var attr = node.data.info;
    var isFolder = attr.type == 'folder';
    var isModel = attr.type == 'model';

    var isObject = attr.type == 'Object';
    var isOneOf = attr.type == '\$anyOf';
    var isRef = attr.type == '\$ref';
    var isType = attr.name == constType;
    var isArray = attr.type == 'Array' || attr.type.endsWith('[]');
    var isInherit = attr.name == constInherit;
    String name = attr.name;

    Color? iconColor =
        attr.isRefAttr() ? Colors.grey.shade800 : Colors.blueGrey;

    if (isRoot) {
      icon = Icon(Icons.business, color: iconColor, size: 20);
    } else if (isInherit) {
      icon = Icon(Icons.call_split, color: iconColor, size: 20);
    } else if (isFolder) {
      icon = Icon(Icons.folder, color: iconColor, size: 20);
    } else if (isModel) {
      icon = Icon(Icons.data_object, color: iconColor, size: 20);
    } else if (isObject) {
      icon = Icon(Icons.data_object, color: iconColor, size: 20);
    } else if (isRef) {
      icon = Icon(Icons.link, color: iconColor, size: 20);
      name = '\$${node.data.info.properties?[constRefOn] ?? '?'}';
    } else if (isOneOf) {
      name = '\$anyOf';
      icon = Icon(Icons.looks_one_rounded, color: iconColor, size: 20);
    } else if (isArray) {
      icon = Icon(Icons.data_array, color: iconColor, size: 20);
    } else if (isType) {
      name = '\$type';
      icon = Icon(Icons.type_specimen_outlined, color: iconColor, size: 20);
    }

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
        if (icon == null) 
          Container(width: 10), // to align with other rows with icon
        Expanded(
          child: InkWell(
            onTap: () {
              node.doTapHeader();
            },
            child: NoOverflowErrorFlex(
              direction: Axis.horizontal,
              children: [
                if (changeStyle.addColor != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 3, top: 6, bottom: 6),
                    child: Tooltip(
                      message: 'Added',
                      child: Container(width: 4, color: changeStyle.addColor),
                    ),
                  ),
                if (changeStyle.pathChange != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 3, top: 6, bottom: 6),
                    child: Tooltip(
                      message: 'Path changed ${changeStyle.tooltipMessage}',
                      child: Container(width: 4, color: changeStyle.pathChange),
                    ),
                  ), // for error display   // for error display
                Expanded(
                  child: getTooltipText(
                    changeStyle,
                    'Name ',
                    getBorder(
                      attr,
                      Text(
                        overflow: TextOverflow.fade,
                        maxLines: 1,
                        name,
                        style:
                            (isObject || isArray)
                                ? TextStyle(
                                  decoration:
                                      isDeprecated
                                          ? TextDecoration.lineThrough
                                          : null,
                                  fontWeight: FontWeight.bold,
                                  color: colorText,
                                )
                                : TextStyle(
                                  color: colorText,
                                  decoration:
                                      isDeprecated
                                          ? TextDecoration.lineThrough
                                          : null,
                                ),
                      ),
                    ),
                  ),
                ),
                //Spacer(),
                getWidgetType(node.data, isModel, isRoot, context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget getBorder(AttributInfo attr, Widget child) {
    if (attr.type == '\$ref') {
      return NoOverflowErrorFlex(
        direction: Axis.horizontal,
        mainAxisSize: MainAxisSize.max,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(5, 0, 5, 0),
            decoration:  BoxDecoration(
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

  Widget getTooltipText(
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

  Widget getWidgetType(
    NodeAttribut attr,
    bool isModel,
    bool isRoot,
    BuildContext context,
  ) {
    if (isRoot) {
      return Text('${modelSchema?.useAttributInfo.length} properties');
    }

    bool hasError = attr.info.error?[EnumErrorType.errorRef] != null;
    hasError = hasError || attr.info.error?[EnumErrorType.errorType] != null;

    String type = attr.info.type;

    if (type == '\$ref' ||
        attr.info.name == constInherit ||
        type == '\$anyOf') {
      return SizedBox.shrink();
    }

    var w = getChip(
      isModel
          ? Row(
            spacing: 5,
            children: [Text(type), Icon(Icons.arrow_forward_ios, size: 10)],
          )
          : hasError
          ? Row(
            spacing: 5,
            children: [Text(type), Icon(Icons.arrow_drop_down, size: 15)],
          )
          : Text(type),
      color: hasError ? Colors.redAccent : (isModel ? Colors.blue : null),
    );

    bool canEditType =
        modelSchema?.isReadOnlyModel == false &&
        !isRoot &&
        !attr.info.isRefAttr() &&
        !attr.info.type.startsWith(r'$');
    if (canEditType) {
      return getEditorType(attr, context, w);
    }
    return w;
  }

  Widget getEditorType(NodeAttribut attr, BuildContext context, Widget child) {
    GlobalKey? k = GlobalKey();

    return GestureDetector(
      key: k,
      onTap: () {
        var listOptions = [
          OptionSelect(
            label: 'string',
            name: 'string',
            icon: Icons.text_fields,
            color: Colors.green,
          ),
          OptionSelect(
            label: 'integer',
            name: 'integer',
            icon: Icons.numbers,
            color: Colors.orange,
          ),
          OptionSelect(
            label: 'number',
            name: 'number',
            icon: Icons.calculate,
            color: Colors.blue,
          ),
          OptionSelect(
            label: 'boolean',
            name: 'boolean',
            icon: Icons.toggle_on,
            color: Colors.purple,
          ),
          // OptionSelect(
          //   label: '\$type',
          //   name: '\$type',
          //   icon: Icons.type_specimen_outlined,
          //   color: Colors.brown,
          // ),
        ];

        currentCompany.listModel?.mapInfoByTreePath.forEach((key, value) {
          if (value.type == 'model') {
            listOptions.add(
              OptionSelect(
                label: '\$${value.name}',
                name: key,
                icon: Icons.data_object,
                color: Colors.blueGrey,
              ),
            );
          }
        });

        openTypeSelector(editor!, context, listOptions, attr, k);
      },
      child: child,
    );
  }

  @override
  Function? getValidateKey() {
    return (String key) {
      if (key.contains(' ')) {
        throw Exception(
          'Key "$key" is not valid.\nSpaces are not allowed in keys.',
        );
      }
    };
  }
}

class GetHeaderRowWidget extends StatelessWidget {
  const GetHeaderRowWidget({
    super.key,
    required this.icon,
    required this.name,
    required this.isObject,
    required this.isArray,
  });

  final Widget icon;
  final String name;
  final bool isObject;
  final bool isArray;

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
        child: NoOverflowErrorFlex(
          direction: Axis.horizontal,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
              child: icon,
            ),
            Text(
              name,
              style:
                  (isObject || isArray)
                      ? const TextStyle(fontWeight: FontWeight.bold)
                      : null,
            ),
          ],
        ),
      ),
    );
  }
}
