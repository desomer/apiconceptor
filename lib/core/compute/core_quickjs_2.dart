@JS()
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

void log(String msg) {
  print("[Dart] $msg");
}

int add(int a, int b) {
  return a + b;
}

JSObject buildDartApi() {
  final api = JSObject();
  api.setProperty('log'.toJS, log.toJS);
  api.setProperty('add'.toJS, add.toJS);
  return api;
}

void exposeDartApi() {
  globalContext['dartApi'] = buildDartApi();
}
