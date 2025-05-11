import 'package:flutter/material.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/main.dart';

class BrowseModel<T extends Map> extends JsonBrowser<T> {
  @override
  void doTree(NodeAttribut aNodeAttribut, r) {
    if (aNodeAttribut.info.type == 'model') {
      initVersion(aNodeAttribut, r);
    }
    super.doTree(aNodeAttribut, r);
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
  @override
  String getTypeTitle(String name, dynamic type) {
    String? typeStr;
    if (type is Map) {
      if (name.startsWith(constRefOn)) {
        typeStr = '\$ref';
      } else if (name.startsWith(constTypeAnyof)) {
        typeStr = '\$anyOf';
      } else if (name.endsWith('[]')) {
        typeStr = 'Array';
      } else {
        typeStr = 'Object';
      }
    } else if (type is List) {
      if (name.endsWith('[]')) {
        typeStr = 'Array';
      } else {
        typeStr = 'Object';
      }
    } else if (type is int) {
      typeStr = 'number';
    } else if (type is double) {
      typeStr = 'number';
    } else if (type is String) {
      if (type.startsWith('\$')) {
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
    bool valid = [
      'model',
      'string',
      'number',
      'object',
      'array',
      '\$ref',
      '\$anyof',
    ].contains(type);
    if (!valid) {
      return InvalidInfo(color: Colors.red);
    }
    return null;
  }
}

