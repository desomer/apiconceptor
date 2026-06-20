// ignore: depend_on_referenced_packages
import 'dart:convert';

import 'package:flutter_js/flutter_js.dart';
import 'package:jsonschema/core/compute/core_data_eval.dart';
// import 'package:jsonschema/core/compute/core_data_eval_desktop.dart';
import 'package:jsonschema/core/compute/core_expression.dart';
import 'package:jsonschema/core/compute/helper_eval.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';

class CoreDataEval with HelperCoreExpression {
  List<String> logger = [];

  //CoreDataEvalDart? coreDataEvalDart;

  dynamic self;
  // Map<String, dynamic>? variables;
  Map<String, AttributBindInfo> listBindInfo = {};
  late String expr;

  final JavascriptRuntime javascriptRuntime = getJavascriptRuntime(
    forceJavascriptCoreOnAndroid: false,
  );

  void initializeJSEngine() {}

  bool noJS = false;
  String? mthKey;
  int ctxKey = 0;

  void compil(String expression, List<String> logs, bool isAsync) {
    if (!expression.startsWith('//JS')) {
      noJS = true;
      compilOk = true;
      // coreDataEvalDart = CoreDataEvalDart();
      // coreDataEvalDart!.compil(expression, logs, isAsync);
      // compilOk = coreDataEvalDart!.compilOk;
      return;
    }

    mthKey ??= newJsSafeId();
    logger = logs;
    expr = expression;

    var lines = splitIgnoringStringsAndComments(expr);
    expr = transformExpr(lines, ", ctxKey");

    String code =
        '''
      function ap_getData(key, ctxKey) {
        let t = `get var \${key}`; 
        console.log(`log \${t}`);
        let a = sendMessage('getData', JSON.stringify({ key, ctxKey }));
        console.log(Object.prototype.toString.call(a));
        return a;
      } 

      function ap_debug(idx, line) {
         sendMessage('debug', `\${line}`);
      } 


      function executeJS(ctxKey) {
        $expr
      }''';

    print(code);

    JsEvalResult jsResult = javascriptRuntime.evaluate(code);
    if (jsResult.isError) {
      print("Error evaluating JS code: ${jsResult.stringResult}");
      compilOk = false;
      return;
    }
    javascriptRuntime.setInspectable(true);
    javascriptRuntime.onMessage('getData', (args) {
      var data = args;
      return getDataFromPage(data['key'], globalContextFormJS[data['ctxKey']]?.variables);
    });
    javascriptRuntime.onMessage('debug', (args) {
      print("JS DEBUG: $args");
    });
    compilOk = true;
  }

  ResultExec execute({
    required List<String> logs,
    Map<String, dynamic>? variables,
  }) {
    if (noJS) {
      return ResultExec(idx: 0, line: '', value: "");
    }

    ctxKey++;
    if (ctxKey > 100000) {
      ctxKey = 0;
    }    
    var key = '${mthKey!}-$ctxKey';
    globalContextFormJS[key] = ContextForJS(variables);

    JsEvalResult jsResult = javascriptRuntime.evaluate("executeJS('$key');");

    globalContextFormJS.remove(key);

    final rawResult = jsResult.stringResult;
    dynamic decodedResult;
    try {
      decodedResult = json.decode(rawResult);
    } catch (_) {
      decodedResult = rawResult;
    }
    print("JS RESULT : decodedResult = $decodedResult type = ${decodedResult?.runtimeType}");

    return ResultExec(idx: 0, line: '', value: decodedResult);
  }
}
