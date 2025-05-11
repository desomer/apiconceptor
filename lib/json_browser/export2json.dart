import 'package:faker/faker.dart';
import 'package:jsonschema/core/randexp.dart';
import 'package:jsonschema/core/export2generic.dart';
import 'package:jsonschema/core/json_browser.dart';

class Export2Json<T extends Map<String, dynamic>>
    extends JsonBrowser2generic<T> {
  Map<String, dynamic> json = {};

  @override
  T getRoot(NodeAttribut node) {
    node.addInAttr = '';
    return json as T;
  }

  @override
  NodeJson doArrayOfObject(String name, NodeAttribut node) {
    var child = [];
    return NodeJson(name: name, value: child);
  }

  @override
  NodeJson doArrayWithAnyOf(String name, NodeAttribut node) {
    var child = [];
    return NodeJson(name: name, value: child);
  }

  @override
  NodeJson doRefOf(String name, NodeAttribut node) {
    return NodeJson(name: name, value: null)..add = false;
  }

  @override
  NodeJson doAnyOf(String name, NodeAttribut node) {
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
    return NodeJson(name: name, value: child);
  }

  @override
  NodeJson doAttr(String name, String type, NodeAttribut node) {
    return NodeJson(name: name, value: getValue(name, type, node));
  }

  getValue(String name, String type, NodeAttribut node) {
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

    var pattern = node.info.properties?['pattern'];
    if (pattern != null) {
      String vString = RandExp(RegExp(pattern)).gen();
      return getValueTyped(type, vString);
    }

    var lowerCase = name.toLowerCase();

    if (type == "number") {
      return faker.randomGenerator.integer(100);
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
}
