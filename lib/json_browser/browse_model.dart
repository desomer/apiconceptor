import 'package:animated_tree_view/tree_view/tree_node.dart';
import 'package:flutter/material.dart';
import 'package:json_schema/json_schema.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/main.dart';

import '../widget_state/widget_md_doc.dart';

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

class BrowseModel<T extends Map> extends JsonBrowser<T> {
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
  dynamic getChild(NodeAttribut parentNode, NodeAttribut node, dynamic parent) {
    return parent;
  }

  void initVersion(NodeAttribut aNodeAttribut, r) {
    print(aNodeAttribut.info.name);
  }
}

//************************************************************************* */
class InfoManagerModel extends InfoManager {
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
      } else if (name.endsWith('[]')) {
        node.bgcolor = Colors.blue.withAlpha(50);
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
        typeStr = 'Array';
      }
    } else if (type is int) {
      typeStr = 'number';
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
      'number',
      'object',
      'array',
      'boolean',
      '\$ref',
      '\$anyof',
    ].contains(type);
    if (!valid) {
      return InvalidInfo(color: Colors.red);
    }
    return null;
  }

  @override
  Widget getAttributHeader(TreeNode<NodeAttribut> node) {
    Widget icon = Container();
    var isRoot = node.isRoot;
    var isObject = node.data!.info.type == 'Object';
    var isOneOf = node.data!.info.type == '\$anyOf';
    var isRef = node.data!.info.type == '\$ref';
    var isType = node.data!.info.name == constType;
    var isArray =
        node.data!.info.type == 'Array' || node.data!.info.type.endsWith('[]');
    String name = node.data?.yamlNode.key;

    if (isRoot) {
      icon = Icon(Icons.business);
    } else if (isRoot) {
      icon = Icon(Icons.lan_outlined);
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

    return IntrinsicWidth(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 5, 0),
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
