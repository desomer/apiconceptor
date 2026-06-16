import 'package:jsonschema/core/compute/core_data_eval.dart';

class ResultCompil {
  final String? error;
  final int idx;
  final String line;

  ResultCompil({required this.idx, required this.line, this.error});
}

class ResultExec {
  final String? error;
  final int idx;
  final String line;
  final dynamic value;

  ResultExec({required this.idx, required this.line, this.error, this.value});
}

class CoreExpression {
  static Map<String, CoreDataEval> cache = {};

  late CoreDataEval exp;

  void init(
    String expression, {
    required List<String> logs,
    required bool isAsync,
  }) {
    String cacheKey = expression + (isAsync ? '_async' : '_sync');
    if (cache[cacheKey] != null) {
      exp = cache[cacheKey]!;
    } else {
      exp = CoreDataEval();
      exp.compil(expression, logs, isAsync);
      cache[cacheKey] = exp;
    }
  }

  // bool evalBool({String? self, Map<String, dynamic>? variables}) {
  //   bool? ok = false;
  //   if (self != null) {
  //     exp.self = double.tryParse(self);
  //   } else {
  //     exp.self = null;
  //   }
  //   exp.variables = variables;
  //   if (variables == null) return false;
  //   ok = exp.execute().value;

  //   return ok ?? false;
  // }

  dynamic eval({
    String? self,
    Map<String, dynamic>? variables,
    required List<String> logs,
  }) {
    if (self != null) {
      exp.self = double.tryParse(self);
    }
    if (variables == null) return false;
    var ret = exp.execute(logs: logs, variables: variables).value;
    return ret;
  }
}
