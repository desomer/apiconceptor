import 'package:faker/faker.dart';
import 'package:jsonschema/core/randexp.dart';
import 'package:jsonschema/core/export2generic.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/start_core.dart';

enum ModeArrayEnum { anyInstance, randomInstance }

enum ModeEnum { fake, empty }

class Export2FakeJson<T extends Map<String, dynamic>>
    extends JsonBrowser2generic<T> {
  final ModeArrayEnum modeArray;
  final ModeEnum mode;

  Map<String, dynamic> json = {};

  Export2FakeJson({required this.modeArray, required this.mode});

  @override
  T getRoot(NodeAttribut node) {
    node.addInAttr = '';
    return json as T;
  }

  @override
  NodeJson doArrayOfObject(String name, NodeAttribut node) {
    var obj = {};
    var child = [obj];

    int? loop;
    if (modeArray == ModeArrayEnum.randomInstance) {
      loop = faker.randomGenerator.integer(10);
    }

    return NodeJson(name: name, value: child)
      ..parentOfChild = obj
      ..loop = loop;
  }

  @override
  NodeJson doArrayWithAnyOf(String name, NodeAttribut node) {
    var child = [];
    return NodeJson(name: name, value: child);
  }

  @override
  NodeJson doObjectWithAnyOf(String name, NodeAttribut node) {
    Map<String, dynamic> child = {};
    return NodeJson(name: name, value: child);
  }

  @override
  NodeJson doRefOf(String name, NodeAttribut node) {
    return NodeJson(name: name, value: null)..add = false;
  }

  @override
  NodeJson doAnyOf(String name, NodeAttribut node) {
    bool mustChoise = node.parent?.info.type == 'Object';
    if (mustChoise) {
      int i = faker.randomGenerator.integer(node.child.length);
      node.child[i].addInAttr = '##__choised__##';
    } else if (modeArray == ModeArrayEnum.randomInstance) {
      int nbRow = faker.randomGenerator.integer(10);
      var nbTemplate = node.child.length;
      node.childExtends = [];
      for (var i = 0; i < nbRow; i++) {
        int i = faker.randomGenerator.integer(nbTemplate);
        node.childExtends!.add(node.child[i]);
      }
    }
    return NodeJson(name: name, value: null)..add = false;
  }

  @override
  NodeJson doRef(String name, NodeAttribut node) {
    var child = {};
    return NodeJson(name: name, value: child);
  }

  @override
  NodeJson doObject(String name, NodeAttribut node) {
    Map<String, dynamic> child = {};
    bool addName = true;
    bool parentAnyOf = node.parent?.info.name == constTypeAnyof;
    if (parentAnyOf) {
      bool mustChoise = node.parent?.parent?.info.type == 'Object';
      addName = !mustChoise;
      if (mustChoise && node.addInAttr != '##__choised__##') {
        // pas ajouter
        name = '';
      }
      node.addInAttr = '';
    }
    return NodeJson(name: name, value: child)..add = addName;
  }

  @override
  NodeJson doAttr(String name, String type, NodeAttribut node) {
    return NodeJson(name: name, value: getValue(name, type, node));
  }

  Object getValue(String name, String type, NodeAttribut node) {
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

    if (mode == ModeEnum.empty) {
      return getValueTyped(type, '');
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
    if (mode == ModeEnum.empty) {
      if (type == "number") return 0;
      if (type == "boolean") return false;
      return '';
    } else if (type == "number") {
      int? vint = int.tryParse(vString);
      if (vint != null) return vint;
      double? vdouble = double.tryParse(vString);
      if (vdouble != null) return vdouble;
    }
    return vString;
  }

  @override
  NodeJson doArrayOfType(String name, String type, NodeAttribut node) {
    var child = [];
    if (node.child.firstOrNull?.info.name == constType) {
      // sera ajouter par le type
    } else if (node.child.firstOrNull?.info.name == constRefOn) {
      // type $ref
      var obj = {};
      var child = [obj];
      int? loop;
      if (modeArray == ModeArrayEnum.randomInstance) {
        loop = faker.randomGenerator.integer(10);
      }
      return NodeJson(name: name, value: child)
        ..loop = loop
        ..parentOfChild = obj;
    } else {
      if (modeArray == ModeArrayEnum.randomInstance) {
        int nbRow = faker.randomGenerator.integer(5);
        for (var i = 0; i < nbRow; i++) {
          child.add(getValue(name, type, node));
        }
      } else {
        child.add(getValue(name, type, node));
      }
    }
    return NodeJson(name: name, value: child);
  }
}
