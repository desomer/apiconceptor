import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jsonschema/core/transform/engine.dart';

class TransformRegistry {
  static final Map<String, TransformAction> availableTransforms =
      <String, TransformAction>{};

  static void addTransform(TransformAction action) {
    availableTransforms[action.info.type] = action;
  }

  static void clear() {
    availableTransforms.clear();
  }

  static void init() {
    if (availableTransforms.isEmpty) {
      _init();
    }
  }

  static List<Map<String, Object>> getAllTransformsInfo() {
    if (availableTransforms.isEmpty) {
      _init();
    }

    return availableTransforms.entries.map((e) {
      return {'name': e.key, 'info': e.value};
    }).toList();
  }

  static void _init() {
    // Transforms personnalisés
    addTransform(
      TransformAction(
        (value, Map t) {
          return value ?? t['value'];
        },
        (value, Map t) => Text('default ${t['\$options'] ?? ''}'),
        info: TransformInfo(['any'], ['any'], 'default'),
        getForm: (value, param, ValueNotifier<int> valueChangeListenable) {
          return addArgText(
            param,
            valueChangeListenable,
            label: 'Default value',
            argKey: 'value',
          );
        },
      ),
    );

    addTransform(
      TransformAction(
        (value, Map t) {
          final side = t['side'] ?? 'both';
          if (value is String) {
            if (side == 'left') return value.trimLeft();
            if (side == 'right') return value.trimRight();
            return value.trim();
          }
          return value;
        },
        (value, Map t) => Text('trim ${t['\$options'] ?? 'both'}'),
        info: TransformInfo(['string'], ['string'], 'trim'),
        getForm: (value, param, ValueNotifier<int> valueChangeListenable) {
          return getArgChoise(
            param,
            valueChangeListenable,
            label: 'Trim side',
            argKey: 'side',
            options: ['both', 'left', 'right'],
          );
        },
      ),
    );

    addTransform(
      TransformAction(
        (value, Map t) {
          final side = t['side'] ?? 'both';
          final width = t['width'] as int? ?? 0;
          final fill = t['fill'] as String? ?? ' ';
          if (value is String) {
            if (side == 'left') {
              return value.padLeft(width, fill.isNotEmpty ? fill[0] : ' ');
            }
            if (side == 'right') {
              return value.padRight(width, fill.isNotEmpty ? fill[0] : ' ');
            }
            // pad both sides: split width evenly
            final leftWidth = (width / 2).floor();
            final rightWidth = width - leftWidth;
            return value
                .padLeft(
                  value.length + leftWidth,
                  fill.isNotEmpty ? fill[0] : ' ',
                )
                .padRight(
                  value.length + leftWidth + rightWidth,
                  fill.isNotEmpty ? fill[0] : ' ',
                );
          }
          return value;
        },
        (value, Map t) => Text('pad ${t['\$options'] ?? ''}'),
        info: TransformInfo(['string'], ['string'], 'pad'),
        getForm: (value, param, ValueNotifier<int> valueChangeListenable) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              getArgChoise(
                param,
                valueChangeListenable,
                label: 'Pad side',
                argKey: 'side',
                options: ['both', 'left', 'right'],
              ),
              addArgInt(
                param,
                valueChangeListenable,
                label: 'Pad width',
                argKey: 'width',
              ),
              addArgText(
                param,
                valueChangeListenable,
                label: 'Pad fill char',
                argKey: 'fill',
              ),
            ],
          );
        },
      ),
    );

    // Transforms de base
    addTransform(
      TransformAction(
        (value, Map t) {
          return value is String ? value.toLowerCase() : value;
        },
        (value, Map t) => Text('lowercase'),
        info: TransformInfo(['string'], ['string'], 'lowercase'),
        getForm: (value, param, ValueNotifier<int> valueChangeListenable) {
          return Text('No args needed'); // no args needed
        },
      ),
    );

    // Transforms de base
    addTransform(
      TransformAction(
        (value, Map t) {
          return value is String ? value.toUpperCase() : value;
        },
        (value, Map t) => Text('uppercase'),
        info: TransformInfo(['string'], ['string'], 'uppercase'),
        getForm: (value, param, ValueNotifier<int> valueChangeListenable) {
          return Text('No args needed'); // no args needed
        },
      ),
    );

    // Transforms de base
    addTransform(
      TransformAction(
        (value, Map t) {
          if (value is String && value.isNotEmpty) {
            return value[0].toUpperCase() + value.substring(1).toLowerCase();
          }
          return value;
        },
        (value, Map t) => Text('capitalize'),
        info: TransformInfo(['string'], ['string'], 'capitalize'),
        getForm: (value, param, ValueNotifier<int> valueChangeListenable) {
          return Text('No args needed'); // no args needed
        },
      ),
    );

    addTransform(
      TransformAction(
        (value, Map t) {
          if (value is String) {
            try {
              final format = t['format'] as String? ?? 'yyyy-MM-dd';
              final df = DateFormat(format);
              final dt = df.parseStrict(value);
              return DateFormat('yyyy-MM-dd').format(dt);
            } catch (_) {
              final onError = t['on_error'];
              if (onError == 'null') return null;
              if (onError == 'default') return t['default_value'];
              throw TransformException(
                'parse_date failed',
                details: {'value': value},
              );
            }
          }
          return null;
        },
        (value, Map t) => Text('parse_date'),
        info: TransformInfo(['string'], ['string'], 'parse_date'),
        getForm: (value, param, ValueNotifier<int> valueChangeListenable) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              addArgText(
                param,
                valueChangeListenable,
                label: 'Date format',
                argKey: 'format',
              ),
              getArgChoise(
                param,
                valueChangeListenable,
                label: 'On parse error',
                argKey: 'on_error',
                options: ['throw', 'null', 'default'],
              ),
              if (param['args']?['on_error'] == 'default')
                addArgText(
                  param,
                  valueChangeListenable,
                  label: 'Default value',
                  argKey: 'default_value',
                ),
            ],
          );
        },
      ),
    );

    // ... ajoute d'autres enrichments selon les besoins
    addTransform(
      TransformAction(
        (value, Map t) {
          final to = t['to'] as String? ?? 'string';
          try {
            switch (to) {
              case 'string':
                return value.toString();
              case 'int':
                return int.tryParse(value.toString());
              case 'double':
                return double.tryParse(value.toString());
              case 'bool':
                final s = value.toString().toLowerCase();
                return s == 'true' || s == '1';
              case 'date':
                return DateTime.parse(value.toString()).toIso8601String();
              default:
                return value;
            }
          } catch (_) {
            throw TransformException(
              'cast failed',
              details: {'value': value, 'to': to},
            );
          }
        },
        (value, Map t) => Text('cast ${t['\$options'] ?? ''}'),
        info: TransformInfo(['any'], ['any'], 'cast'),
        getForm: (value, param, ValueNotifier<int> valueChangeListenable) {
          return getArgChoise(
            param,
            valueChangeListenable,
            label: 'Cast to type',
            argKey: 'to',
            options: ['string', 'int', 'double', 'bool', 'date'],
          );
        },
      ),
    );

    addTransform(
      TransformAction(
        (value, Map t) {
          // stub: integration point for external lookup function
          return null;
        },
        (value, Map t) => Text('lookup'),
        info: TransformInfo(['any'], ['any'], 'lookup'),
        getForm: (value, param, ValueNotifier<int> valueChangeListenable) {
          return Text('No args needed'); // no args needed
        },
      ),
    );

    // Transforms personnalisés
    addTransform(
      TransformAction(
        (value, Map t) {
          if (value is String) return value.split('').reversed.join();
          if (value is List) return value.reversed.toList();
          return value;
        },
        (value, Map t) => Text('reverse'),
        info: TransformInfo(['string', 'list'], ['string', 'list'], 'reverse'),
        getForm: (value, param, ValueNotifier<int> valueChangeListenable) {
          return Text('No args needed'); // no args needed
        },
      ),
    );

    // Transforms personnalisés
    addTransform(
      TransformAction(
        (value, Map t) {
          if (value is String) return value.length;
          if (value is List) return value.length;
          return null;
        },
        (value, Map t) => Text('length'),
        info: TransformInfo(['string', 'list'], ['number'], 'length'),
        getForm: (value, param, ValueNotifier<int> valueChangeListenable) {
          return Text('No args needed'); // no args needed
        },
      ),
    );
    // ... ajoute d'autres transforms selon les besoins

    addTransform(
      TransformAction(
        (value, Map t) {
          if (value is String) {
            final search = t['search'] as String;
            return value.contains(search);
          }
          return false;
        },
        (value, Map t) => Text('contains ${t['\$options'] ?? ''}'),
        info: TransformInfo(['string'], ['bool'], 'contains'),
        getForm: (value, param, ValueNotifier<int> valueChangeListenable) {
          return addArgText(
            param,
            valueChangeListenable,
            label: 'Search string',
            argKey: 'search',
          );
        },
      ),
    );

    addTransform(
      TransformAction(
        (value, Map t) {
          final parts = (t['parts'] as List?) ?? [];
          return parts.map((p) {
            if (p is String && p.startsWith('\$')) {
              final ref = p.substring(1);
              final v = TransformEngine.getPath(value is Map ? value : {}, ref);
              return v?.toString() ?? '';
            }
            return p.toString();
          }).join();
        },
        (value, Map t) => Text('concat ${t['\$options'] ?? ''}'),
        info: TransformInfo(['any'], ['string'], 'concat'),
        getForm: (value, param, ValueNotifier<int> valueChangeListenable) {
          return addArgText(
            param,
            valueChangeListenable,
            label: 'Parts (use \$path for references)',
            argKey: 'parts',
          );
        },
      ),
    );

    addTransform(
      TransformAction(
        (value, Map t) {
          if (value is String) {
            final delimiter = t['delimiter'] as String? ?? ',';
            return value.split(delimiter);
          }
          return value;
        },
        (value, Map t) => Text('split ${t['\$options'] ?? ''}'),
        info: TransformInfo(['string'], ['list'], 'split'),
        getForm: (value, param, ValueNotifier<int> valueChangeListenable) {
          return addArgText(
            param,
            valueChangeListenable,
            label: 'Delimiter ( default: ",")',
            argKey: 'delimiter',
          );
        },
      ),
    );

    addTransform(
      TransformAction(
        (value, Map t) {
          if (value is List) {
            final delimiter = t['delimiter'] as String? ?? ',';
            return value.join(delimiter);
          }
          return value;
        },
        (value, Map t) => Text('join'),
        info: TransformInfo(['list'], ['string'], 'join'),
        getForm: (value, param, ValueNotifier<int> valueChangeListenable) {
          return addArgText(
            param,
            valueChangeListenable,
            label: 'Delimiter (default: ",")',
            argKey: 'delimiter',
          );
        },
      ),
    );

    addTransform(
      TransformAction(
        (value, Map t) {
          if (value is String) {
            final prefix = t['prefix'] as String;
            return value.startsWith(prefix);
          }
          return false;
        },
        (value, Map t) => Text('starts_with ${t['\$options'] ?? ''}'),
        info: TransformInfo(['string'], ['bool'], 'starts_with'),
        getForm: (value, param, ValueNotifier<int> valueChangeListenable) {
          return addArgText(
            param,
            valueChangeListenable,
            label: 'Prefix to check',
            argKey: 'prefix',
          );
        },
      ),
    );

    addTransform(
      TransformAction(
        (value, Map t) {
          if (value is String) {
            final suffix = t['suffix'] as String;
            return value.endsWith(suffix);
          }
          return false;
        },
        (value, Map t) => Text('ends_with ${t['\$options'] ?? ''}'),
        info: TransformInfo(['string'], ['bool'], 'ends_with'),
        getForm: (value, param, ValueNotifier<int> valueChangeListenable) {
          return addArgText(
            param,
            valueChangeListenable,
            label: 'Suffix to check',
            argKey: 'suffix',
          );
        },
      ),
    );

    addTransform(
      TransformAction(
        (value, Map t) {
          if (value is String) {
            final start = t['start'] as int? ?? 0;
            final length = t['length'] as int?;
            if (length != null) {
              return value.substring(start, start + length);
            }
            return value.substring(start);
          }
          return value;
        },
        (value, Map t) => Text('substring ${t['\$options'] ?? ''}'),
        info: TransformInfo(['string'], ['string'], 'substring'),
        getForm: (value, param, ValueNotifier<int> valueChangeListenable) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              addArgInt(
                param,
                valueChangeListenable,
                label: 'Start index',
                argKey: 'start',
              ),
              addArgInt(
                param,
                valueChangeListenable,
                label: 'Length (optional)',
                argKey: 'length',
              ),
            ],
          );
        },
      ),
    );

    addTransform(
      TransformAction(
        (value, Map t) {
          if (value is double) return value.ceil();
          if (value is int) return value;
          return value;
        },
        (value, Map t) => Text('ceil'),
        info: TransformInfo(['number'], ['number'], 'ceil'),
        getForm: (value, param, ValueNotifier<int> valueChangeListenable) {
          return Text('No args needed'); // no args needed
        },
      ),
    );

    addTransform(
      TransformAction(
        (value, Map t) {
          if (value is double) return value.floor();
          if (value is int) return value;
          return value;
        },
        (value, Map t) => Text('floor'),
        info: TransformInfo(['number'], ['number'], 'floor'),
        getForm: (value, param, ValueNotifier<int> valueChangeListenable) {
          return Text('No args needed'); // no args needed
        },
      ),
    );

    // ... ajoute d'autres transforms selon les besoins
    addTransform(
      TransformAction(
        (value, Map t) {
          if (value is double) {
            int precision = t['precision'] as int? ?? 0;
            final factor = pow(10, precision).toDouble();
            return (value * factor).round() / factor;
          }
          return value;
        },
        (value, Map t) => Text('round'),
        info: TransformInfo(['number'], ['number'], 'round'),
        getForm: (value, param, ValueNotifier<int> valueChangeListenable) {
          return addArgInt(
            param,
            valueChangeListenable,
            label: 'Precision',
            argKey: 'precision',
          );
        },
      ),
    );

    // Transforms personnalisés
    addTransform(
      TransformAction(
        (value, Map t) {
          return value is num ? value.abs() : value;
        },
        (value, Map t) => Text('abs'),
        info: TransformInfo(['number'], ['number'], 'abs'),
        getForm: (value, param, ValueNotifier<int> valueChangeListenable) {
          return Text('No args needed'); // no args needed
        },
      ),
    );

    // ... ajoute d'autres transforms selon les besoins
    addTransform(
      TransformAction(
        (value, Map t) {
          if (value is num) {
            final min = t['min'] as num?;
            return min != null && value < min ? min : value;
          }
          return value;
        },
        (value, Map t) => Text('min'),
        info: TransformInfo(['number'], ['number'], 'min'),
        getForm: (value, param, ValueNotifier<int> valueChangeListenable) {
          return addArgInt(
            param,
            valueChangeListenable,
            label: 'Min value',
            argKey: 'min',
          );
        },
      ),
    );

    // ... ajoute d'autres transforms selon les besoins
    addTransform(
      TransformAction(
        (value, Map t) {
          if (value is num) {
            final max = t['max'] as num?;
            return max != null && value > max ? max : value;
          }
          return value;
        },
        (value, Map t) => Text('max'),
        info: TransformInfo(['number'], ['number'], 'max'),
        getForm: (value, param, ValueNotifier<int> valueChangeListenable) {
          return addArgInt(
            param,
            valueChangeListenable,
            label: 'Max value',
            argKey: 'max',
          );
        },
      ),
    );

    addTransform(
      TransformAction(
        (value, Map t) {
          if (value is String) {
            final pattern = RegExp(t['pattern']);
            final ok = pattern.hasMatch(value);
            if (!ok) {
              final onError = t['on_error'] ?? 'dlq';
              if (onError == 'coerce_null') return null;
              throw TransformException(
                'validate_regex failed',
                details: {'value': value, 'pattern': t['pattern']},
              );
            }
          }
          return value;
        },
        (value, Map t) => Text('validate_regex ${t['\$options'] ?? ''}'),
        info: TransformInfo(['string'], ['string'], 'validate_regex'),
        getForm: (value, param, ValueNotifier<int> valueChangeListenable) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              addArgText(
                param,
                valueChangeListenable,
                label: 'Regex pattern',
                argKey: 'pattern',
              ),
              getArgChoise(
                param,
                valueChangeListenable,
                label: 'On validation error',
                argKey: 'on_error',
                options: ['throw', 'coerce_null'],
              ),
            ],
          );
        },
      ),
    );

    addTransform(
      TransformAction(
        (value, Map t) {
          if (value is String) {
            final pattern = RegExp(t['pattern']);
            final replacement = t['replacement'] ?? '';
            return value.replaceAll(pattern, replacement);
          }
          return value;
        },
        (value, Map t) => Text('regex_replace ${t['\$options'] ?? ''}'),
        info: TransformInfo(['string'], ['string'], 'regex_replace'),
        getForm: (value, param, ValueNotifier<int> valueChangeListenable) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              addArgText(
                param,
                valueChangeListenable,
                label: 'Regex pattern',
                argKey: 'pattern',
              ),
              addArgText(
                param,
                valueChangeListenable,
                label: 'Replacement string',
                argKey: 'replacement',
              ),
            ],
          );
        },
      ),
    );
  }

  static Row addArgInt(
    Map<dynamic, dynamic> param,
    ValueNotifier<int> valueChangeListenable, {
    required String label,
    required String argKey,
  }) {
    var args = param['args'] ?? {};
    return Row(
      spacing: 8,
      children: [
        Text('$label: '),
        Expanded(
          child: TextField(
            keyboardType: TextInputType.number,
            controller: TextEditingController(
              text: args[argKey]?.toString() ?? '',
            ),
            onChanged: (v) {
              final n = int.tryParse(v);
              if (n != null) {
                args[argKey] = n;
                param['args'] = args;
                param['\$options'] = '$argKey: $n';
                valueChangeListenable.value++;
              }
            },
          ),
        ),
      ],
    );
  }

  static Row getArgChoise(
    Map<dynamic, dynamic> param,
    ValueNotifier<int> valueChangeListenable, {
    required String label,
    required String argKey,
    required List<String> options,
  }) {
    var args = param['args'] ?? {};
    return Row(
      spacing: 8,
      children: [
        Text('$label: '),
        DropdownButton<String>(
          value: args[argKey] ?? options.first,
          items:
              options
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
          onChanged: (v) {
            args[argKey] = v;
            param['args'] = args;
            param['\$options'] = '$argKey: $v';
            valueChangeListenable.value++;
          },
        ),
      ],
    );
  }

  static Widget addArgText(
    Map<dynamic, dynamic> param,
    ValueNotifier<int> valueChangeListenable, {
    required String label,
    required String argKey,
  }) {
    var args = param['args'] ?? {};
    return Row(
      spacing: 8,
      children: [
        Text('$label: '),
        Expanded(
          child: TextField(
            controller: TextEditingController(
              text: args[argKey]?.toString() ?? '',
            ),
            onChanged: (v) {
              args[argKey] = v;
              param['args'] = args;
              param['\$options'] = '$argKey: $v';
              valueChangeListenable.value++;
            },
          ),
        ),
      ],
    );
  }
}
