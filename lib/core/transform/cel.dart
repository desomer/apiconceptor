import 'package:libcel/libcel.dart'; // ou 'package:cel/cel.dart'

class CelEngine {
  final _cache = <String, CelProgram>{};
  final cel = Cel();

  CelProgram _compile(String expr) {
    if (_cache.containsKey(expr)) return _cache[expr]!;
    final env = cel;
    final ast = env.compile(expr);
    _cache[expr] = ast;
    return ast;
  }

  /// Evaluate expression with context map. Returns result or throws.
  dynamic eval(String expr, Map<String, dynamic> ctx, {Duration? timeout}) {
    final prog = _compile(expr);
    // wrap in timeout future to avoid long-running evals
    return prog.evaluate(ctx);
    // if (timeout != null) {
    //   return future.timeout(
    //     timeout,
    //     onTimeout: () => throw Exception('CEL evaluation timeout'),
    //   );
    // }
    // return future;
  }
}
