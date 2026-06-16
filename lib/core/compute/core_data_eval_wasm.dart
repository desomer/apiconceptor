// ignore: depend_on_referenced_packages
@JS()
library;

import 'package:jsonschema/core/compute/core_data_eval.dart';
import 'package:jsonschema/core/compute/core_expression.dart';
import 'package:jsonschema/core/compute/core_quickjs_2.dart';
import 'package:jsonschema/core/compute/helper_eval.dart';
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

dynamic runJS(String code) {
  final result = _evalInQJS(code);
  return result;
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

class CoreDataEval with HelperCoreExpression {
  dynamic self;
  // Map<String, dynamic>? variables;
  Map<String, AttributBindInfo> listBindInfo = {};

  int lastIdx = 0;
  int lastLine = 0;

  late String expr;
  List<String> logger = [];

  void initializeJSEngine() {
    initQuickJS()
        .then((_) {
          exposeDartApi();
        })
        .catchError((error) {
          print('Error initializing QuickJS: $error');
        });
  }

  String? mthKey;
  int ctxKey = 0;
  bool noJS = false;

  void compil(String expression, List<String> logs, bool isAsync) {
    if (!expression.startsWith('//JS')) {
      noJS = true;
      compilOk = true;
      return;
    }

    logger = logs;
    expr = expression;

    // generate a short unique key for the context en chaine simple, pour pouvoir le passer à la fonction JS sans problème de type
    mthKey ??= newJsSafeId();

    var lines = splitIgnoringStringsAndComments(expr);
    expr = transformExpr(lines, ",ctxkey");

    String code =
        '''
      function ap_getData(key, ctxkey) {
        //let t = `get var \${key}`; 
        //dart.log(t);
        let a = dart.getData(key, ctxkey);
        //dart.log(a);
        let r = JSON.parse(a);
        //dart.log(Object.prototype.toString.call(r));
        return r;
      } 

      function ap_debug(idx, line) {
         dart.log(`debug \${idx}: \${line}`);
      } 

      function executeJS_$mthKey(ctxkey) {
        $expr
      }''';

    //print(code);
    compilOk = true;
    _evalInQJS(code);
  }

  ResultExec execute({
    required List<String> logs,
    Map<String, dynamic>? variables,
  }) {
    if (noJS) {
      return ResultExec(idx: lastIdx, line: '', value: "");
    }

    ctxKey++;
    if (ctxKey > 100000) {
      ctxKey = 0;
    }
    var key = '${mthKey!}-$ctxKey';
    globalContextFormJS[key] = ContextForJS(variables);
    logger = logs;

    // setPropInQJS('globalThis', 'dartApi', globalContext['dartApi']);
    // exposeToGlobalThis();

    //print('exécution de l\'expression JS...');
    //setPropInQJS('globalThis', 'x', 10);

    //     runJS("""
    //   function hello(name) {
    //     return helloDart(name);
    //   }
    // """);

    // calcul le temps d'execution
    //final startTime = DateTime.now();

    final result = runJS("""
(() => {
  return executeJS_$mthKey('$key');
})();
    """);

    globalContextFormJS.remove(key);

    // final endTime = DateTime.now();
    // final duration = endTime.difference(startTime);

    //print(
    //  'result quickjs = $result (exécuté en ${duration.inMilliseconds} ms)',
    //);
    print("JS RESULT : decodedResult = $result type = ${result?.runtimeType}");

    return ResultExec(idx: lastIdx, line: '', value: result);
  }
}
