import 'dart:convert';

import 'package:jsonschema/core/export2generic.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/start_core.dart';

class Export2JsonSchema<T extends Map<String, dynamic>>
    extends JsonBrowser2generic<T> {
  Map<String, dynamic> json = {};
  Map<String, NodeJson> ref = {};

  @override
  void onInit(ModelSchema model) {
    List example = [];
    var ex = model.getExtendedNode('#examples').info.properties?['#examples'];
    if (ex is List) {
      for (var element in ex) {
        if (element['json'] is String) {
          try {
            example.add(jsonDecode(element['json']));
          } catch (e) {
            print(' error decode example $e');
          }
        }
      }
    }

    json = {
      "\$schema": "https://json-schema.org/draft/2020-12/schema",
      "\$id": model.headerName,
      "title": model.headerName,
      "description":
          currentCompany.currentModelSel?.info.properties?['description'] ?? '',
      "type": "object",
      "properties": {},
      "additionalProperties": false,
      "examples": example,
    };
  }

  @override
  void onReady(ModelSchema model) {
    var def = {};
    json['\$def'] = def;
    for (var element in ref.entries) {
      def[element.key] = element.value.value;
    }
  }

  @override
  T getRoot(NodeAttribut node) {
    node.addInAttr = 'properties';
    addPropObject(json, node);
    return json as T;
  }

  @override
  NodeJson doArrayOfObject(String name, NodeAttribut node) {
    var prop = {...node.info.properties ?? {}};
    initProp(prop);
    Map<String, dynamic> child = {'type': 'array', ...prop};
    Map<String, dynamic> items = {'type': 'object'};
    addPropObject(items, node);
    child['items'] = items;
    node.addChildOn = "items";
    node.addInAttr = "properties";
    return NodeJson(name: name, value: child);
  }

  @override
  NodeJson doArrayOfType(String name, String type, NodeAttribut node) {
    var prop = {...node.info.properties ?? {}};
    initProp(prop);
    var enumer = prop.remove('enum');
    Map<String, dynamic> child = {'type': 'array', ...prop};
    if (node.child.firstOrNull?.info.name == constType) {
      // ajoute le type et ses properties
      child['items'] = {'type': type, ...getProp(node.child.first)};
      node.addChildOn = "items";
    } else if (node.child.firstOrNull?.info.name == constRefOn) {
      // ajoute le type et ses properties
      String refName = node.info.isRef!;
      child['items'] = {'\$ref': '#/\$def/$refName'};
      node.addChildOn = "items";
      ref[refName] = NodeJson(
        name: name,
        value: {
          "type": "object",
          "additionalProperties": false,
          "properties": {},
        },
      );
      return NodeJson(name: name, value: child)
        ..parentOfChild = ref[refName]!.value;
    } else {
      Map<String, dynamic> items = {'type': type};
      if (enumer != null) {
        List<String> enumer = node.info.properties!['enum'].toString().split(
          '\n',
        );
        items['enum'] = enumer;
      }
      child['items'] = items;
    }

    //
    //node.addInAttr = "properties";
    return NodeJson(name: name, value: child);
  }

  void initProp(Map<String, dynamic> prop) {
    prop.remove(constMasterID);
    prop.remove('required');
    prop.removeWhere((key, value) {
      return key.startsWith('#');
    });
  }

  @override
  NodeJson doArrayWithAnyOf(String name, NodeAttribut node) {
    var prop = {...node.info.properties ?? {}};
    initProp(prop);
    Map<String, dynamic> child = {'type': 'array', ...prop};
    child['items'] = {};
    node.addInAttr = ''; // ajoute le anyOf à la racine
    node.addChildOn = "items";
    return NodeJson(name: name, value: child);
  }

  @override
  NodeJson doObjectWithAnyOf(String name, NodeAttribut node) {
    node.addInAttr = ''; // ajoute le anyOf à la racine
    return NodeJson(name: name, value: {});
  }

  @override
  NodeJson doAnyOf(String name, NodeAttribut node) {
    var child = [];
    name = 'anyOf';
    return NodeJson(name: name, value: child);
  }

  @override
  NodeJson doRefOf(String name, NodeAttribut node) {
    node.addInAttr = "properties";
    return NodeJson(name: name, value: null)..add = false;
  }

  @override
  NodeJson doRef(String name, NodeAttribut node) {
    node.addInAttr = "properties";
    var refName = node.info.isRef!;
    var child = {'\$ref': '#/\$def/$refName'};
    ref[refName] = NodeJson(
      name: name,
      value: {
        "type": "object",
        "additionalProperties": false,
        "properties": {},
      },
    );
    return NodeJson(name: name, value: child)
      ..parentOfChild = ref[refName]!.value;
  }

  @override
  NodeJson doObject(String name, NodeAttribut node) {
    node.addInAttr = "properties";
    Map<String, dynamic> child = {'type': 'object'};
    addPropObject(child, node);
    return NodeJson(name: name, value: child);
  }

  void addPropObject(Map<String, dynamic> prop, NodeAttribut node) {
    prop.addAll(node.info.properties ?? {});
    initProp(prop);
    prop["additionalProperties"] = false;

    List<String> aRequired = [];
    for (var child in node.child) {
      if (child.info.properties?['required'] ?? false) {
        var name2 = child.info.name;
        if (name2.endsWith('[]')) name2 = name2.substring(0, name2.length - 2);
        aRequired.add(name2);
      }
    }
    if (aRequired.isNotEmpty) {
      prop['required'] = aRequired;
    }
  }

  @override
  NodeJson doAttr(String name, String type, NodeAttribut node) {
    node.addInAttr = "properties";
    if (name == constType) {
      //pas d'ajout des type de tableau
      return NodeJson(name: '', value: '')..add = false;
    }
    Map<String, dynamic> prop = getProp(node);
    bool nullable = node.info.properties?['#nullable'] ?? false;
    Map<String, dynamic> child = {
      'type': nullable ? [type, 'null'] : type,
      ...prop,
    };
    return NodeJson(name: name, value: child);
  }

  Map<String, dynamic> getProp(NodeAttribut node) {
    var prop = {...node.info.properties ?? {}};
    prop.remove(constMasterID);
    prop.remove('required');
    prop.removeWhere((key, value) {
      return key.startsWith('#');
    });

    if (node.info.properties?['enum'] != null) {
      List<String> enumer = node.info.properties!['enum'].toString().split(
        '\n',
      );
      prop['enum'] = enumer;
    }
    if (node.info.properties?['format'] != null) {
      prop['format'] = node.info.properties!['format'];
      switch (prop['format']) {
        case 'date':
          prop['pattern'] =
              r'^(?:19\d{2}|20\d{2})-(?:(?:01|03|05|07|08|10|12)-(?:0[1-9]|[12]\d|3[01])|(?:04|06|09|11)-(?:0[1-9]|[12]\d|30)|02-(?:0[1-9]|1\d|2[0-8]))$';
          break;
        case 'time':
          prop['pattern'] =
              r'^(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d(?:Z|[+-][01]\d:[0-5]\d)?$';
          break;
        case 'date-time':
          // date time au format ISO 8601
          prop['pattern'] =
              r'^(?:19\d{2}|20\d{2})-(?:(?:01|03|05|07|08|10|12)-(?:0[1-9]|[12]\d|3[01])|(?:04|06|09|11)-(?:0[1-9]|[12]\d|30)|02-(?:0[1-9]|1\d|2[0-8]))T(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d(?:Z|[+-][01]\d:[0-5]\d)$';
          break;
        case 'email':
          prop['pattern'] = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
          break;
        // add more formats as needed
      }
    }
    // {
    //   prop['\$schema'] = 'https://json-schema.org/draft/2020-12/schema';
    // }

    return prop;
  }

  @override
  NodeJson doAllOf(
    NodeAttribut parent,
    dynamic parentNodeJson,
    String name,
    NodeAttribut node,
  ) {
    parent.addInAttr = "";
    var child = [];
    name = 'allOf';
    parentNodeJson as Map<String, dynamic>;
    parentNodeJson.remove('properties');
    parentNodeJson.remove('additionalProperties');
    return NodeJson(name: name, value: child);
  }
}

class ExportJsonSchema2clipboard {
  Future<void> doExport(ModelSchema model) async {
    // var export = Export2JsonSchema()..browse(model, false);

    // Clipboard.setData(
    //   ClipboardData(text: export.prettyPrintJson(export.json)),
    // ).then((_) {
    //   if (stateModel.keyYamlListModel.currentContext?.mounted ?? false) {
    //     ScaffoldMessenger.of(
    //       stateModel.keyYamlListModel.currentContext!,
    //     ).showSnackBar(
    //       const SnackBar(content: Text('Copied to your clipboard !')),
    //     );
    //   }
    // });

    //print(export.json);
  }
}
