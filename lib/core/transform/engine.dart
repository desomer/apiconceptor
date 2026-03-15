// transforms.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:jsonschema/core/transform/cel.dart';
import 'package:jsonschema/core/transform/enrichment.dart';
import 'package:jsonschema/core/transform/transform_registry.dart';
import 'package:yaml/yaml.dart';
// NOTE: 'cel' est un placeholder pour la lib CEL Dart que tu choisiras.
// Adapte les imports et l'API CelEngine selon la lib réelle.

// ignore: constant_identifier_names
enum ValidationAction { dlq, coerce_null, warn, none }

enum ValidationLevel { fail, warn }

ValidationAction _parseAction(String? a) {
  switch (a) {
    case 'dlq':
      return ValidationAction.dlq;
    case 'coerce_null':
      return ValidationAction.coerce_null;
    case 'warn':
      return ValidationAction.warn;
    default:
      return ValidationAction.none;
  }
}

ValidationLevel _parseLevel(String? l) {
  switch (l) {
    case 'warn':
      return ValidationLevel.warn;
    case 'fail':
      return ValidationLevel.fail;
    default:
      return ValidationLevel.fail;
  }
}

typedef JsonMap = Map<String, dynamic>;

class TransformException implements Exception {
  final String message;
  final Map? details;
  TransformException(this.message, {this.details});
  @override
  String toString() => 'TransformException: $message ${details ?? ''}';
}

class TransformInfo {
  final List<String> inputType;
  final List<String> outputType;
  final String type;
  TransformInfo(this.inputType, this.outputType, this.type);
}

class TransformAction {
  final TransformInfo info;
  TransformAction(this.apply, this.getInfo, {this.getForm, required this.info});
  final Function(dynamic value, Map t) apply;
  final Widget Function(dynamic value, Map t) getInfo;
  final Widget Function(
    dynamic value,
    Map param,
    ValueNotifier<int> valueChangeListenable,
  )?
  getForm;

  Widget? getTypeWidget() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('(${info.inputType.join(',')}) → (${info.outputType.join(',')})'),
      ],
    );
  }
}

class TransformEngine {
  final Map<String, dynamic> engineConfig;
  final CelEngine cel;
  final EnrichmentEngine enrichmentEngine;
  TransformEngine(this.engineConfig, this.enrichmentEngine) : cel = CelEngine();

  // -------------------------
  // Path helpers
  // -------------------------
  static dynamic getPath(Map obj, String path) {
    final parts = path.split('.');
    dynamic cur = obj;
    for (final p in parts) {
      if (cur == null) return null;
      if (p.endsWith('[]')) {
        final arrKey = p.substring(0, p.length - 2);
        if (cur is Map && cur.containsKey(arrKey) && cur[arrKey] is List) {
          var idx = 0;
          cur = cur[arrKey][idx];
        } else {
          return null;
        }
      } else if (cur is Map && cur.containsKey(p)) {
        cur = cur[p];
      } else {
        return null;
      }
    }
    return cur;
  }

  static void setPath(JsonMap obj, String path, dynamic value) {
    final parts = path.split('.');
    Map cur = obj;
    for (var i = 0; i < parts.length - 1; i++) {
      final p = parts[i];
      if (!cur.containsKey(p) || cur[p] is! Map) cur[p] = <String, dynamic>{};
      cur = cur[p] as Map;
    }
    cur[parts.last] = value;
  }

  Map<String, dynamic>? _evaluateValidation(
    Map<String, dynamic> rule,
    Map<String, dynamic> ctx,
  ) {
    // Retourne null si OK, sinon un objet d'erreur {id, field?, message, action}
    final id = rule['id'] as String? ?? 'unknown_validation';
    final scope = rule['scope'] as String? ?? 'field';
    final ruleType = rule['rule'] as String? ?? 'unknown';
    final action = _parseAction(rule['action'] as String?);
    final level = _parseLevel(rule['level'] as String?);

    try {
      if (ruleType == 'regex' && scope == 'field') {
        final field = rule['field'] as String;
        final pattern = rule['pattern'] as String;
        final val = getPath(ctx, field);
        if (val == null || val is! String || !RegExp(pattern).hasMatch(val)) {
          return {
            'id': id,
            'field': field,
            'message': 'regex_mismatch',
            'action': action.toString(),
            'level': level.toString(),
          };
        }
        return null;
      }

      if (ruleType == 'not_null' && scope == 'field') {
        final field = rule['field'] as String;
        final val = getPath(ctx, field);
        if (val == null) {
          return {
            'id': id,
            'field': field,
            'message': 'null_value',
            'action': action.toString(),
            'level': level.toString(),
          };
        }
        return null;
      }

      if (ruleType == 'cel') {
        final expr = rule['expression'] as String;
        final res = cel.eval(expr, ctx, timeout: Duration(milliseconds: 150));
        // Pour les validations CEL : on considère false comme violation
        if (res != true) {
          return {
            'id': id,
            'message': 'cel_failed',
            'expr': expr,
            'action': action.toString(),
            'level': level.toString(),
          };
        }
        return null;
      }

      // fallback: unknown rule type => log as warning
      return null;
    } catch (e) {
      // erreur d'évaluation => remonter comme violation (action configurable)
      return {
        'id': id,
        'message': 'eval_error',
        'error': e.toString(),
        'action': action.toString(),
        'level': level.toString(),
      };
    }
  }

  void _applyValidations(Map<String, dynamic> out) {
    final validations = (engineConfig['validations'] as List<dynamic>?) ?? [];
    for (final v in validations) {
      final rule = v as Map<String, dynamic>;
      final result = _evaluateValidation(rule, out);
      if (result != null) {
        // action handling
        final actionStr = rule['action'] as String? ?? 'dlq';
        final action = _parseAction(actionStr);
        // attach to _dlq or coerce depending on action
        if (action == ValidationAction.dlq) {
          out['_dlq'] = out['_dlq'] ?? [];
          (out['_dlq'] as List).add({'validation': result});
        } else if (action == ValidationAction.coerce_null) {
          // if field specified, set it to null
          final field = rule['field'] as String?;
          if (field != null) setPath(out, field, null);
          // also record warning
          out['_warnings'] = out['_warnings'] ?? [];
          (out['_warnings'] as List).add({'validation': result});
        } else if (action == ValidationAction.warn) {
          out['_warnings'] = out['_warnings'] ?? [];
          (out['_warnings'] as List).add({'validation': result});
        } else {
          // none: just log into warnings
          out['_warnings'] = out['_warnings'] ?? [];
          (out['_warnings'] as List).add({'validation': result});
        }
      }
    }
  }


  // -------------------------
  // Primitive transforms
  // -------------------------
  dynamic _applyTransform(dynamic value, Map t) {
    final name = t['name'] as String;
    final args = (t['args'] ?? {}) as Map;

    if (TransformRegistry.availableTransforms.isEmpty) {
      TransformRegistry.init();
    }

    final transform = TransformRegistry.availableTransforms[name];

    if (transform != null) {
      return transform.apply(value, args);
    }
    return value; // no-op if transform not found
  }

  // -------------------------
  // Conditional mappings
  // -------------------------
  bool _evalCondition(String condExpr, Map<String, dynamic> ctx) {
    try {
      final res = cel.eval(condExpr, ctx, timeout: Duration(milliseconds: 150));
      return res == true;
    } catch (e) {
      // log or attach to DLQ; default false
      return false;
    }
  }

  void _applyConditionalMappings(
    Map<String, dynamic> input,
    Map<String, dynamic> out,
  ) {
    final conds =
        (engineConfig['conditional_mappings'] as List<dynamic>?) ?? [];
    for (final c in conds) {
      final condExpr = c['condition'] as String;
      final thenList = (c['then'] as List<dynamic>?) ?? [];
      final elseList = (c['otherwise'] as List<dynamic>?) ?? [];

      bool ok;
      try {
        ok = _evalCondition(condExpr, input);
      } catch (e) {
        out['_dlq'] = out['_dlq'] ?? [];
        (out['_dlq'] as List).add({
          'rule': c['id'],
          'error': e.toString(),
          'expr': condExpr,
        });
        ok = false;
      }

      final applyList = ok ? thenList : elseList;
      for (final Map action in applyList) {
        final target = action['target'] as String;
        if (action.containsKey('value')) {
          setPath(out, target, action['value']);
        } else if (action.containsKey('source')) {
          final src = action['source'] as String;
          final val = getPath(out, src);
          setPath(out, target, val);
        } else if (action.containsKey('transform')) {
          dynamic val = getPath(out, action['source']);
          for (final t in (action['transform'] as List<dynamic>)) {
            val = _applyTransform(val, t as Map);
          }
          setPath(out, target, val);
        }
      }
    }
  }

  // -------------------------
  // Derived fields via CEL
  // -------------------------
  void _evaluateDerivedFields(Map<String, dynamic> out) {
    final derived = (engineConfig['derived_fields'] as List<dynamic>?) ?? [];
    for (final d in derived) {
      final target = d['target'] as String;
      final expr = d['expression'] as String;
      final onError = d['on_error'] as String? ?? 'dlq';
      try {
        final val = cel.eval(expr, out, timeout: Duration(milliseconds: 200));
        setPath(out, target, val);
      } catch (e) {
        if (onError == 'coerce_null') {
          setPath(out, target, null);
        } else {
          out['_dlq'] = out['_dlq'] ?? [];
          (out['_dlq'] as List).add({
            'derived': target,
            'error': e.toString(),
            'expr': expr,
          });
        }
      }
    }
  }

  // -------------------------
  // Main transform
  // -------------------------
  Future<JsonMap> transformRecordAsync(
    JsonMap input, {
    bool throwOnDlq = false,
  }) async {
    final out = <String, dynamic>{};
    final fields = engineConfig['fields'] as List<dynamic>? ?? [];
    for (final f in fields) {
      final source = f['source'] as String;
      final target = f['target'] as String;
      final transforms = (f['transforms'] as List<dynamic>?)?.cast<Map>() ?? [];
      dynamic val = getPath(input, source);
      try {
        for (final t in transforms) {
          val = _applyTransform(val, t);
        }
        setPath(out, target, val);
      } on TransformException catch (e) {
        if (throwOnDlq) rethrow;
        out['_dlq'] = out['_dlq'] ?? [];
        (out['_dlq'] as List).add({
          'field': source,
          'error': e.message,
          'details': e.details,
        });
      }
    }

    // après la boucle fields
    // 1) validations
    _applyValidations(out);

    // 3) enrichments (async)
    await enrichmentEngine.applyAll(out, engineConfig);

    // Conditional mappings (CEL)
    _applyConditionalMappings(input, out);

    // Derived fields (CEL)
    _evaluateDerivedFields(out);

    return out;
  }

  // Future<JsonMap> transformRecordAsync(JsonMap input, {bool throwOnDlq = false}) async {
  //   final out = <String, dynamic>{};
  //   // 1) fields (same as before)
  //   // ... existing code ...

  //   // 2) validations
  //   _applyValidations(out);

  //   // 3) enrichments (async)
  //   await enrichmentEngine.applyAll(out);

  //   // 4) conditional mappings
  //   _applyConditionalMappings(out);

  //   // 5) derived fields
  //   _evaluateDerivedFields(out);

  //   return out;
  // }

  Future<List<JsonMap>> transformBatch(
    List<JsonMap> inputs, {
    bool throwOnDlq = false,
  }) async {
    return await Future.wait(
      inputs.map((r) => transformRecordAsync(r, throwOnDlq: throwOnDlq)),
    );
  }
}

// -------------------------
// YAML loader helper
// -------------------------
Map<String, dynamic> loadMappingFromYaml(String yamlContent) {
  final doc = loadYaml(yamlContent);
  return jsonDecode(jsonEncode(doc)) as Map<String, dynamic>;
}
