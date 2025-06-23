import 'package:jsonschema/core/export2generic.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/main.dart';

class Export2JsonSchema<T extends Map<String, dynamic>>
    extends JsonBrowser2generic<T> {
  Map<String, dynamic> json = {};
  Map<String, NodeJson> ref = {};

  @override
  void onInit(ModelSchema model) {
    json = {
      "\$schema": "https://json-schema.org/draft/2020-12/schema",
      "\$id": model.headerName,
      "title": model.headerName,
      "description":
          currentCompany.currentModelSel?.info.properties?['description'] ?? '',
      "type": "object",
      "properties": {},
      "additionalProperties": false,
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
    prop.remove(constMasterID);
    prop.remove('required');
    Map<String, dynamic> child = {'type': 'array', ...prop};
    Map<String, dynamic> items = {
      'type': 'object',
      "additionalProperties": false,
    };
    child['items'] = items;
    node.addChildOn = "items";
    node.addInAttr = "properties";
    return NodeJson(name: name, value: child);
  }

  @override
  NodeJson doArrayOfType(String name, String type, NodeAttribut node) {
    var prop = {...node.info.properties ?? {}};
    prop.remove(constMasterID);
    prop.remove('required');
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
      child['items'] = items;
    }

    //
    //node.addInAttr = "properties";
    return NodeJson(name: name, value: child);
  }

  @override
  NodeJson doArrayWithAnyOf(String name, NodeAttribut node) {
    var prop = {...node.info.properties ?? {}};
    prop.remove(constMasterID);
    prop.remove('required');
    Map<String, dynamic> child = {'type': 'array', ...prop};
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
      ..parentOfChild = ref[refName]!.value;
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
        var name2 = child.info.name;
        if (name2.endsWith('[]')) name2 = name2.substring(0, name2.length - 2);
        aRequired.add(name2);
      }
    }
    if (aRequired.isNotEmpty) {
      child['required'] = aRequired;
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
    Map<String, dynamic> child = {'type': type, ...prop};
    return NodeJson(name: name, value: child);
  }

  Map<String, dynamic> getProp(NodeAttribut node) {
    var prop = {...node.info.properties ?? {}};
    prop.remove(constMasterID);
    prop.remove('required');
    if (node.info.properties?['enum'] != null) {
      List<String> enumer = node.info.properties!['enum'].toString().split(
        '\n',
      );
      prop['enum'] = enumer;
    }
    // if (node.info.properties?['format'] != null)
    // {
    //   prop['\$schema'] = 'https://json-schema.org/draft/2020-12/schema';
    // }

    return prop;
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
