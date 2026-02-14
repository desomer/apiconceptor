import 'dart:math';

import 'package:faker/faker.dart';
import 'package:jsonschema/core/randexp.dart';
import 'package:jsonschema/core/export2generic.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/start_core.dart';

enum ModeArrayEnum { anyInstance, randomInstance }

enum ModeEnum { fake, empty }

enum PropertyRequiredEnum { required, all }

class Export2FakeJson<T extends Map<String, dynamic>>
    extends JsonBrowser2generic<T> {
  final ModeArrayEnum modeArray;
  final ModeEnum mode;
  final PropertyRequiredEnum propMode;

  int maxArrayItems = 10;

  Map<String, dynamic> json = {};

  Export2FakeJson({
    required this.modeArray,
    required this.mode,
    required this.propMode,
  });

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
      loop = faker.randomGenerator.integer(maxArrayItems);
    }
    loop = getLoopItems(loop, node);

    return NodeJson(name: name, value: child)
      ..parentOfChild = obj
      ..loop = loop;
  }

  int? getLoopItems(int? loop, NodeAttribut node) {
    int? min = int.tryParse(node.info.properties?['#minItems'] ?? '');
    int? max = int.tryParse(node.info.properties?['#maxItems'] ?? '');
    if (min != null && max != null && max >= min) {
      if (min == max) {
        loop = min-1;
      } else {
        loop = faker.randomGenerator.integer(max, min: min-1);
      }
    } else if (min != null) {
      loop = min-1;
    } else if (max != null) {
      loop = faker.randomGenerator.integer(max, min: 0);
    }
    return loop;
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
    // print("doRefOf ${node.info.path} ${node.info.properties?[constRefOn]}");
    return NodeJson(name: name, value: null)..add = false;
  }

  @override
  NodeJson doAnyOf(String name, NodeAttribut node) {
    bool mustChoise = node.parent?.info.type == 'Object';
    if (mustChoise) {
      int i = faker.randomGenerator.integer(node.child.length);
      node.child[i].addInAttr = '##__choised__##';
    } else if (modeArray == ModeArrayEnum.randomInstance) {
      int nbRow = faker.randomGenerator.integer(maxArrayItems);
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
    if (propMode == PropertyRequiredEnum.required) {
      bool required = node.info.properties?['required'] ?? false;
      if (!required) {
        return NodeJson(name: '', value: null)..add = false;
      }
    }

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
    if (propMode == PropertyRequiredEnum.required) {
      bool required = node.info.properties?['required'] ?? false;
      if (!required) {
        return NodeJson(name: '', value: null)..add = false;
      }
    }
    return NodeJson(name: name, value: getValue(name, type, node));
  }

  double roundDouble(double value, int places) {
    num mod = pow(10.0, places);
    return ((value * mod).round().toDouble() / mod);
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

    if (mode == ModeEnum.empty) {
      return getValueTyped(type, '');
    }

    var pattern = node.info.properties?['pattern'];
    var format = node.info.properties!['format'];
    switch (format) {
      case 'date':
        pattern ??=
            r'^(?:19\d{2}|20\d{2})-(?:(?:01|03|05|07|08|10|12)-(?:0[1-9]|[12]\d|3[01])|(?:04|06|09|11)-(?:0[1-9]|[12]\d|30)|02-(?:0[1-9]|1\d|2[0-8]))$';
        break;
      case 'time':
        pattern ??=
            r'^(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d(?:Z|[+-][01]\d:[0-5]\d)?$';
        break;
      case 'date-time':
        // date time au format ISO 8601
        pattern ??=
            r'^(?:19\d{2}|20\d{2})-(?:(?:01|03|05|07|08|10|12)-(?:0[1-9]|[12]\d|3[01])|(?:04|06|09|11)-(?:0[1-9]|[12]\d|30)|02-(?:0[1-9]|1\d|2[0-8]))T(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d(?:Z|[+-][01]\d:[0-5]\d)$';
        break;
      case 'email':
        pattern ??= r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
        break;
      case 'url':
        pattern ??=
            r'^https?:\/\/(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(?::\d{2,5})?(?:\/[^\s]*)?$';
        break;
      // add more formats as needed
    }

    bool useFakeAlgo = ['email', 'url'].contains(format);

    if (pattern != null && !useFakeAlgo) {
      String vString = RandExp(RegExp(pattern)).gen();
      return getValueTyped(type, vString);
    }

    var lowerCase = name.toLowerCase();

    if (type == "integer") {
      return faker.randomGenerator.integer(100);
    } else if (type == "number") {
      return roundDouble(faker.randomGenerator.decimal(min: 0, scale: 100), 2);
    } else if (type == "boolean") {
      return faker.randomGenerator.boolean();
    } else {
      if (lowerCase.contains('firstname')) {
        return faker.person.firstName();
      } else if (lowerCase.contains('lastname')) {
        return faker.person.lastName();
      } else if (lowerCase.contains('city')) {
        return faker.address.city();
      } else if (lowerCase.contains('zipcode') ||
          lowerCase.contains('postalcode')) {
        return faker.address.zipCode();
      } else if (lowerCase.contains('address')) {
        return faker.address.streetAddress();
      } else if (lowerCase.contains('mail')) {
        return faker.internet.email();
      } else if (lowerCase.contains('phonenumber')) {
        return faker.phoneNumber.us();
      } else if (format == 'email') {
        return faker.internet.email();
      } else if (format == 'url') {
        return faker.internet.httpsUrl();
      }
      return faker.lorem.word();
    }
  }

  Object getValueTyped(String type, String vString) {
    if (mode == ModeEnum.empty) {
      if (type == "number" || type == "integer") return 0;
      if (type == "boolean") return false;
      return '';
    } else if (type == "number" || type == "integer") {
      int? vint = int.tryParse(vString);
      if (vint != null) return vint;
      double? vdouble = double.tryParse(vString);
      if (vdouble != null) return vdouble;
    } else if (type == "boolean") {
      if (vString.toLowerCase() == 'true') return true;
      if (vString.toLowerCase() == 'false') return false;
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
        loop = faker.randomGenerator.integer(maxArrayItems);
      }
      loop = getLoopItems(loop, node);
      return NodeJson(name: name, value: child)
        ..loop = loop
        ..parentOfChild = obj;
    } else {
      // tableau de type simple
      if (modeArray == ModeArrayEnum.randomInstance) {
        int? nbRow = faker.randomGenerator.integer(maxArrayItems);
        nbRow = getLoopItems(nbRow, node);
        for (var i = 0; i < (nbRow ?? 0); i++) {
          child.add(getValue(name, type, node));
        }
      } else {
        int? loop;
        loop = getLoopItems(loop, node);
        if (loop != null) {
          for (var i = 0; i < loop; i++) {
            child.add(getValue(name, type, node));
          }
        } else {
          child.add(getValue(name, type, node));
        }
      }
    }
    return NodeJson(name: name, value: child);
  }

  @override
  NodeJson doAllOf(
    NodeAttribut parent,
    dynamic parentNodeJson,
    String name,
    NodeAttribut node,
  ) {
    // TODO: implement doAllOf
    throw UnimplementedError();
  }
}
