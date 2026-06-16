import 'package:shortid/shortid.dart';

export 'core_data_eval_wasm.dart'
    if (dart.library.io) 'core_data_eval_jsdesktop.dart';

Map<String, ContextForJS> globalContextFormJS = {};

class ContextForJS {
  ContextForJS(this.variables);
  Map<String, dynamic>? variables;
}

String newJsSafeId() {
  final raw = '${shortid.generate()}${DateTime.now().microsecondsSinceEpoch}';
  final sanitized = raw.replaceAll(RegExp(r'[^A-Za-z0-9_$]'), '');
  return sanitized;
}