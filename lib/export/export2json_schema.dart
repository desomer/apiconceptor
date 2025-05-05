import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/export/export2generic.dart';
import 'package:jsonschema/export/json_browser.dart';
import 'package:jsonschema/main.dart';

class Export2JsonSchema<T extends Map<String, dynamic>>
    extends JsonBrowser2generic<T> {
  Map<String, dynamic> json = {};
  Map<String, NodeJson> ref = {};

  @override
  void onInit(ModelSchemaDetail model) {
    json = {
      "\$schema": "https://json-schema.org/draft/2020-12/schema",
      "\$id": model.name,
      "title": model.name,
      "description": model.name,
      "type": "object",
      "properties": {},
      "additionalProperties": false,
    };
  }

  @override
  void onReady(ModelSchemaDetail model) {
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
    Map<String, dynamic> child = {'type': 'array'};
    Map<String, dynamic> items = {'type': 'object'};
    child['items'] = items;
    node.addChildOn = "items";
    //node.addInAttr = "properties";
    return NodeJson(name: name, value: child);
  }

  @override
  NodeJson doArrayWithAnyOf(String name, NodeAttribut node) {
    Map<String, dynamic> child = {'type': 'array'};
    child['items'] = {};
    node.addInAttr = ''; // ajoute le anyOf à la racine
    node.addChildOn = "items";
    return NodeJson(name: name, value: child);
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
      ..treeOfChild = ref[refName]!.value;
  }

  @override
  NodeJson doObject(String name, NodeAttribut node) {
    node.addInAttr = "properties";
    Map<String, dynamic> child = {'type': 'object'};
    addPropObject(child, node);
    return NodeJson(name: name, value: child);
  }

  void addPropObject(Map<String, dynamic> child, NodeAttribut node) {
    child["additionalProperties"] = false;

    List<String> aRequired = [];
    for (var child in node.child) {
      if (child.info.properties?['required'] ?? false) {
        aRequired.add(child.info.name);
      }
    }
    if (aRequired.isNotEmpty) {
      child['required'] = aRequired;
    }
  }

  @override
  NodeJson doAttr(String name, String type, NodeAttribut node) {
    node.addInAttr = "properties";
    var prop = {...node.info.properties ?? {}};
    prop.remove(constMasterID);
    prop.remove('required');
    if (node.info.properties?['enum'] != null) {
      List<String> enumer = node.info.properties!['enum'].toString().split(
        '\n',
      );
      prop['enum'] = enumer;
    }
    Map<String, dynamic> child = {'type': type, ...prop};
    return NodeJson(name: name, value: child);
  }
}

class ExportJsonSchema2clipboard {
  doExport(ModelSchemaDetail model) async {
    var export = Export2JsonSchema()..browse(model, false);

    Clipboard.setData(
      ClipboardData(text: export.prettyPrintJson(export.json)),
    ).then((_) {
      if (keyListModel.currentContext?.mounted ?? false) {
        ScaffoldMessenger.of(keyListModel.currentContext!).showSnackBar(
          const SnackBar(content: Text('Copied to your clipboard !')),
        );
      }
    });

    print(export.json);
  }
}
