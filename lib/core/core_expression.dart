import 'package:jsonschema/core/core_data_eval.dart';

class CoreExpression {
  static Map<String, CoreDataEval> cache = {};

  late CoreDataEval exp;

  void init(String expression, {required List<String> logs}) {
    String cacheKey = expression;
    if (cache[cacheKey] != null) {
      exp = cache[cacheKey]!;
    } else {
      exp = CoreDataEval();
      exp.compil(expression, logs);
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

  dynamic eval({String? self, Map<String, dynamic>? variables, required List<String> logs}) async {
    if (self != null) {
      exp.self = double.tryParse(self);
    }
    exp.variables = variables;
    if (variables == null) return false;
    var ret = exp.execute(logs: logs).value;
    if (ret is Future) {
      ret = await ret;
    }
    return ret;
  }
}
