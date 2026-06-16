@JS()
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:jsonschema/core/compute/helper_eval.dart';

import 'core_data_eval.dart';

void log(String msg) {
  print("[Dart] $msg");
}

JSString getData(String key, String contextKey) {
  var r = getDataFromPage(key, globalContextFormJS[contextKey]?.variables);
  return json.encode(r).toJS;
}

JSAny toJSAny(dynamic value) {
  if (value is List) {
    final jsArray = JSArray();
    for (final item in value) {
      jsArray.add(toJSAny(item));
    }
    return jsArray;
  }

  if (value is Map<String, dynamic>) {
    final jsObj = JSObject();
    value.forEach((key, val) {
      jsObj[key] = toJSAny(val);
    });
    return jsObj;
  }

  return value.toJS; // primitives
}

dynamic jsAny2Dart(JSAny? value) {
  if (value == null) {
    return null;
  }
  return value.dartify();
}

JSObject buildDartApi() {
  final api = JSObject();
  api.setProperty('log'.toJS, log.toJS);
  api.setProperty('getData'.toJS, getData.toJS);
  return api;
}

void exposeDartApi() {
  globalContext['dartApi'] = buildDartApi();
}
