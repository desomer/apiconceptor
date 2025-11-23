import 'package:faker/faker.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/randexp.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/start_core.dart';

class NodeJson {
  NodeJson({required this.name, required this.value});
  String name;
  dynamic value;
  dynamic parentOfChild;
  bool add = true;
}

var cstType = '\$\$__type\$\$__';
var cstContent = '\$\$__content\$\$__';
var cstProp = '\$\$__prop\$\$__';
var cstAnyChoice = '##__choise__##';
var cstPropLabel = '\$\$__proplabel\$\$__';

class Export2UI<T> extends JsonBrowser<T> {
  @override
  dynamic getChild(
    ModelSchema model,
    NodeAttribut parentNode,
    NodeAttribut node,
    dynamic parent,
  ) {
    doClean(node);
    String type = node.info.type.toLowerCase();
    String name = node.info.name;

    if (type == 'param') {
      type = 'object';
      node.info.type = 'object';
    }

    NodeJson toAdd;

    if (type.endsWith('[]')) {
      name = name.substring(0, name.length - 2);
      var typeArray = node.info.type.substring(0, node.info.type.length - 2);
      toAdd = doArrayOfType(name, typeArray, node);
    } else if (type == 'array') {
      if (name.endsWith('[]')) {
        name = name.substring(0, name.length - 2);
      }
      if (node.child.length == 1 &&
          node.child.first.info.name == constTypeAnyof) {
        toAdd = doArrayWithAnyOf(name, node);
      } else if (node.child.length == 1 &&
          node.child.first.info.name == constType) {
        toAdd = doArrayOfType(name, node.child.first.info.type, node);
      } else if (node.child.length == 1 &&
          node.child.first.info.name == constRefOn) {
        toAdd = doArrayOfType(name, node.child.first.info.type, node);
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

  void doClean(NodeAttribut node) {
    node.addChildOn = null;
    node.addInAttr = "";
  }

  @override
  void doNode(NodeAttribut nodeAttribut) {
    //print('${nodeAttribut.info.path}  ${nodeAttribut.info.properties}');
    super.doNode(nodeAttribut);
  }

  Map<String, dynamic> json = {};

  @override
  T getRoot(NodeAttribut node) {
    node.addInAttr = '';
    return json as T;
  }

  NodeJson doArrayOfObject(String name, NodeAttribut node) {
    var obj = {};

    var child = {
      cstType: 'array',
      cstContent: [obj],
      cstProp: node.info,
    };
    return NodeJson(name: name, value: child)..parentOfChild = obj;
  }

  NodeJson doArrayWithAnyOf(String name, NodeAttribut node) {
    var obj = [];
    var child = {cstType: 'arrayAnyOf', cstContent: obj, cstProp: node.info};
    return NodeJson(name: name, value: child)..parentOfChild = obj;
  }

  NodeJson doRefOf(String name, NodeAttribut node) {
    return NodeJson(name: name, value: null)..add = false;
  }

  NodeJson doAnyOf(String name, NodeAttribut node) {
    bool mustChoise = node.parent?.info.type == 'Object';
    if (mustChoise) {
      var obj = {};
      Map<String, dynamic> map = {
        cstType: 'objectAnyOf',
        cstContent: obj,
        cstProp: node.info,
      };
      dynamic child = mustChoise ? map : null;

      return NodeJson(name: cstAnyChoice, value: child)..parentOfChild = obj;
    } else {
      return NodeJson(name: name, value: null)..add = false;
    }
  }

  NodeJson doRef(String name, NodeAttribut node) {
    var child = {};
    return NodeJson(name: name, value: child);
  }

  NodeJson doObject(String name, NodeAttribut node) {
    Map<String, dynamic> child = {};
    child[cstProp] = node.info;

    // bool parentAnyOf = node.parent?.info.name == constTypeAnyof;
    // if (parentAnyOf) {
    //   bool mustChoise = node.parent?.parent?.info.type == 'Object';
    // }

    return NodeJson(name: name, value: child);
  }

  NodeJson doAttr(String name, String type, NodeAttribut node) {
    return NodeJson(name: name, value: getValue(name, type, node));
  }

  Object getValue(String name, String type, NodeAttribut node) {
    return {cstType: 'input', cstProp: node.info, cstContent: node.info.path};
  }

  Object getFake(NodeAttribut node, String type, String name) {
    if (node.info.properties?['const'] != null) {
      var vString = node.info.properties?['const'];
      return getValueTyped(type, vString);
    }
    if (node.info.properties?['enum'] != null) {
      List<String> enumer = node.info.properties!['enum'].toString().split(
        '\n',
      );
      var vString = enumer[faker.randomGenerator.integer(enumer.length)];
      return getValueTyped(type, vString);
    }
    if (node.info.properties?['example'] != null) {
      List<String> enumer = node.info.properties!['example'].toString().split(
        '\n',
      );
      var vString = enumer[faker.randomGenerator.integer(enumer.length)];
      return getValueTyped(type, vString);
    }

    var pattern = node.info.properties?['pattern'];
    if (pattern != null) {
      String vString = RandExp(RegExp(pattern)).gen();
      return getValueTyped(type, vString);
    }

    var lowerCase = name.toLowerCase();

    if (type == "number") {
      return faker.randomGenerator.integer(100);
    } else if (type == "boolean") {
      return faker.randomGenerator.boolean();
    } else {
      if (lowerCase.contains('firstname')) {
        return faker.person.firstName();
      } else if (lowerCase.contains('lastname')) {
        return faker.person.lastName();
      } else if (lowerCase.contains('city')) {
        return faker.address.city();
      } else if (lowerCase.contains('zipcode')) {
        return faker.address.zipCode();
      } else if (lowerCase.contains('address')) {
        return faker.address.streetAddress();
      } else if (lowerCase.contains('mail')) {
        return faker.internet.email();
      } else if (lowerCase.contains('phonenumber')) {
        return faker.phoneNumber.us();
      }
      return faker.lorem.word();
    }
  }

  Object getValueTyped(String type, String vString) {
    if (type == "number") {
      int? vint = int.tryParse(vString);
      if (vint != null) return vint;
      double? vdouble = double.tryParse(vString);
      if (vdouble != null) return vdouble;
    }
    return vString;
  }

  NodeJson doArrayOfType(String name, String type, NodeAttribut node) {
    var child = [];
    if (node.child.firstOrNull?.info.name == constType) {
      // sera ajouter par le type
    } else if (node.child.firstOrNull?.info.name == constRefOn) {
      var obj = {};
      var child = {
        cstType: node.info.type,
        cstContent: [obj],
        cstProp: node.info,
      };
      return NodeJson(name: name, value: child)..parentOfChild = obj;
    } else {
      child.add(getValue(name, type, node));
    }
    var child2 = {cstType: type, cstContent: child, cstProp: node.info};
    return NodeJson(name: name, value: child2)..parentOfChild = child;
  }
}
