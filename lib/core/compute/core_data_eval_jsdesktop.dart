// ignore: depend_on_referenced_packages
import 'package:flutter_js/flutter_js.dart';
import 'package:jsonschema/core/compute/core_expression.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';

class CoreDataEval {
  List<String> logger = [];

  dynamic self;
  Map<String, dynamic>? variables;
  Map<String, AttributBindInfo> listBindInfo = {};

  final JavascriptRuntime javascriptRuntime = getJavascriptRuntime(
    forceJavascriptCoreOnAndroid: false,
  );

  void compil(String expression, List<String> logs, bool isAsync) {}

  ResultExec execute({required List<String> logs}) {
    JsEvalResult jsResult = javascriptRuntime.evaluate(
      "Math.trunc(Math.random() * 100).toString();",
    );

    return ResultExec(idx: 0, line: '', value: jsResult.stringResult);
  }
}
