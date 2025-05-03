import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/export/json_browser.dart';
import 'package:jsonschema/main.dart';

class JsonBrowser2JsonSchema<T extends Map<String, dynamic>>
    extends JsonBrowser<T> {
  Map<String, dynamic> json = {
    "\$schema": "https://json-schema.org/draft/2020-12/schema",
    "\$id": "??",
    "title": "title",
    "description": "A product in the catalog",
    "type": "object",
    "properties": {},
    "additionalProperties": false,
  };

  @override
  T getRoot(NodeAttribut node) {
    return json as T;
  }

  @override
  dynamic getChild(NodeAttribut parentNode, NodeAttribut node, dynamic parent) {
    var type = node.info.type.toLowerCase();
    Map<String, dynamic> child = {'type': type};
    dynamic toAdd = child;
    String name = node.info.name;
    dynamic inBloc;

    if (type == 'array') {
      name = name.substring(0, name.length - 2);
      if (node.child.length == 1 &&
          node.child.first.info.name == constTypeAnyof) {
        // cas de tableau de AnyOf
        child['items'] = {};
        node.addInAttr = '';
      } else {
        Map<String, dynamic> items = {'type': 'object'};
        child['items'] = items;
      }
      node.addChildOn = "items";
    } else if (type == '\$anyof') {
      toAdd = [];
      name = 'anyOf';
    } else if (type == 'object') {
      if (node.info.isRef != null) {
        inBloc = {};
        toAdd = {'\$ref': '#/\$def/${node.info.isRef}'};
      } else {
        child["additionalProperties"] = false;
      }
    }

    if (parent is List) {
      parent.add(child);
    } else {
      if (parentNode.addChildOn != null) {
        parent = parent[parentNode.addChildOn];
      }
      if (parentNode.addInAttr != '') {
        parent[parentNode.addInAttr] ??= {};
        parent[parentNode.addInAttr][name] = toAdd;
      } else {
        parent[name] = toAdd;
      }
    }
    return inBloc ?? toAdd;
  }

  @override
  void doNode(NodeAttribut nodeAttribut) {
    //print('${nodeAttribut.info.path}  ${nodeAttribut.info.properties}');
    super.doNode(nodeAttribut);
  }
}

class ExportToJsonSchema {
  doExport(ModelSchemaDetail model) async {
    var export = JsonBrowser2JsonSchema()..browse(model, false);

    Clipboard.setData(ClipboardData(text: prettyPrintJson(export.json))).then((
      _,
    ) {
      if (keyListModel.currentContext?.mounted ?? false) {
        ScaffoldMessenger.of(keyListModel.currentContext!).showSnackBar(
          const SnackBar(content: Text('Copied to your clipboard !')),
        );
      }
    });

    print(export.json);
  }

  String prettyPrintJson(Map input) {
    //const JsonDecoder decoder = JsonDecoder();
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(input);
  }

  // https://medium.com/@patrice1972/how-to-set-default-value-conditionally-in-json-schema-dd19a689adfa
  /**   
  {
    "type": "array",
    "items": {
        "oneOf": [
            {"type": "string"},
            {"type": "integer"}
        ]
    }
}


{
  "type": "object",
  "properties": {
    "arr": {
      "type": "array",
      "items": 
           { "anyOf":[
             {
              "type": "object",
              "additionalProperties": false,
              "properties": {
                "a" : {"type" : "string"}
                }
              },
             {
              "type": "object",
              "additionalProperties": false,
              "properties": {
                "b" : {"type" : "string"}
                }
              }             
           ],        
           }
    }
  },
  "additionalProperties": false,
}

      "properties": {
        "email": {
          "title": "Email address",
          "type": "string",
          "pattern": "^\\S+@\\S+\\.\\S+$",
          "format": "email",
          "minLength": 6,
          "maxLength": 127
        }
      }


*/
}
