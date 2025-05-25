import 'dart:convert';

import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/main.dart';

abstract class JsonBrowser2generic<T extends Map<String, dynamic>>
    extends JsonBrowser<T> {
  @override
  dynamic getChild(NodeAttribut parentNode, NodeAttribut node, dynamic parent) {
    doClean(node);
    String type = node.info.type.toLowerCase();
    String name = node.info.name;

    NodeJson toAdd;

    if (type == 'array') {
      name = name.substring(0, name.length - 2);
      if (node.child.length == 1 &&
          node.child.first.info.name == constTypeAnyof) {
        toAdd = doArrayWithAnyOf(name, node);
      } else {
        toAdd = doArrayOfObject(name, node);
      }
    } else if (type == '\$anyof') {
      toAdd = doAnyOf(name, node);
    } else if (type == '\$ref') {
      toAdd = doRefOf(name, node);
    } else if (type == 'object') {
      if (node.info.isRef != null) {
        toAdd = doRef(name, node);
      } else {
        toAdd = doObject(name, node);
      }
    } else {
      toAdd = doAttr(name, type, node);
    }

    if (!toAdd.add) {
      // node invisible
      return parent;
    }

    dynamic value = toAdd.value;
    name = toAdd.name;
    if (parent is List) {
      parent.add(value);
    } else {
      if (parentNode.addChildOn != null) {
        parent = parent[parentNode.addChildOn];
      }
      if (parentNode.addInAttr != '') {
        parent[parentNode.addInAttr] ??= {};
        parent[parentNode.addInAttr][name] = value;
      } else {
        parent[name] = value;
      }
    }
    return toAdd.parentOfChild ?? value;
  }

  NodeJson doArrayOfObject(String name, NodeAttribut node);

  NodeJson doArrayWithAnyOf(String name, NodeAttribut node);

  NodeJson doAnyOf(String name, NodeAttribut node);

  NodeJson doRefOf(String name, NodeAttribut node);

  NodeJson doRef(String name, NodeAttribut node);

  NodeJson doObject(String name, NodeAttribut node);

  NodeJson doAttr(String name, String type, NodeAttribut node);

  void doClean(NodeAttribut node) {
    node.addChildOn = null;
    node.addInAttr = "";
  }

  @override
  void doNode(NodeAttribut nodeAttribut) {
    //print('${nodeAttribut.info.path}  ${nodeAttribut.info.properties}');
    super.doNode(nodeAttribut);
  }

  String prettyPrintJson(dynamic input) {
    //const JsonDecoder decoder = JsonDecoder();
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(input);
  }
}

class NodeJson {
  NodeJson({required this.name, required this.value});
  String name;
  dynamic value;
  dynamic parentOfChild;
  bool add = true;
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
