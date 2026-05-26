// ignore: depend_on_referenced_packages
@JS()
library;

import 'package:jsonschema/core/compute/core_expression.dart';
import 'package:jsonschema/core/compute/core_quickjs_2.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';

import 'dart:js_interop_unsafe';
import 'dart:js_interop';

@JS('initQJS')
external JSPromise _initQJS();

@JS('evalInQJS')
external JSAny? _evalInQJS(String code);

@JS('setProp')
external void _setProp(String targetExpr, String propName, JSAny? value);

@JS('globalThis')
external JSObject get globalThis;

String helloFromDart(String name) {
  print("Dart dit bonjour à $name");
  return "Dart dit bonjour à $name";
}

void exposeToGlobalThis() {
  globalThis.setProperty('helloDart'.toJS, helloFromDart.toJS);
}

Future<void> initQuickJS() async {
  await _initQJS().toDart;
}

String? runJS(String code) {
  final result = _evalInQJS(code);
  return result?.toString();
}

void setPropInQJS(String targetExpr, String propName, dynamic value) {
  _setProp(targetExpr, propName, _toJSAny(value));
}

JSAny? _toJSAny(dynamic value) {
  if (value == null) return null;
  if (value is String) return value.toJS;
  if (value is int) return value.toJS;
  if (value is double) return value.toJS;
  if (value is bool) return value.toJS;

  // ignore: invalid_runtime_check_with_js_interop_types
  if (value is JSAny) return value;

  throw UnsupportedError(
    'setProp only supports String, int, double, bool, or null.',
  );
}

class CoreDataEval {
  dynamic self;
  Map<String, dynamic>? variables;
  Map<String, AttributBindInfo> listBindInfo = {};

  int lastIdx = 0;
  int lastLine = 0;

  bool compilOk = false;
  List<String> logger = [];

  void compil(String expression, List<String> logs, bool isAsync) {
    initQuickJS();
  }

  ResultExec execute({required List<String> logs}) {
    logger = logs;

    exposeDartApi();

    // setPropInQJS('globalThis', 'dartApi', globalContext['dartApi']);
    // exposeToGlobalThis();

    print('exécution de l\'expression JS...');
    setPropInQJS('globalThis', 'x', 10);

//     runJS("""
//   function hello(name) {
//     return helloDart(name);
//   }
// """);

    final result = runJS("""
(() => {
  dart.log('Hello from QuickJS! x = ' + x);
  if (x > 5) return 'grand';
  return 'petit';
})();
    """);

    print('result quickjs = $result');

    return ResultExec(idx: lastIdx, line: '', value: result);
  }
}
