import 'dart:convert';

class Export2Avro {
  String jsonSchemaToAvro(Map<String, dynamic> schema) {
    final buffer = StringBuffer();
    final generatedTypes = <String, Map<String, dynamic>>{};
    final rootName = schema['title'] ?? 'RootRecord';

    final avroSchema = _generateAvro(schema, rootName, generatedTypes);
    buffer.write(_formatAvro(avroSchema));

    for (final entry in generatedTypes.entries) {
      buffer.writeln(',');
      buffer.write(_formatAvro(entry.value));
    }

    return '[\n${buffer.toString()}\n]';
  }

  Map<String, dynamic> _generateAvro(
    Map<String, dynamic> schema,
    String name,
    Map<String, Map<String, dynamic>> generatedTypes,
  ) {
    final fields = <Map<String, dynamic>>[];
    final requiredFields = List<String>.from(schema['required'] ?? []);
    final properties = schema['properties'] ?? {};

    properties.forEach((key, value) {
      final isRequired = requiredFields.contains(key);
      final avroType = _mapJsonTypeToAvro(value, key, generatedTypes);
      final fieldType = isRequired ? avroType : ['null', avroType];

      final field = {'name': key, 'type': fieldType};

      if (value.containsKey('default')) {
        field['default'] = value['default'];
      }

      fields.add(field);
    });

    return {'type': 'record', 'name': name, 'fields': fields};
  }

  dynamic _mapJsonTypeToAvro(
    Map<dynamic, dynamic> value,
    String key,
    Map<String, Map<String, dynamic>> types,
  ) {
    final type = value['type'];
    if (value.containsKey('enum')) {
      return {
        'type': 'enum',
        'name': '${_capitalize(key)}Enum',
        'symbols': List<String>.from(value['enum']),
      };
    }

    switch (type) {
      case 'string':
        return 'string';
      case 'number':
      case 'integer':
        return 'double';
      case 'boolean':
        return 'boolean';
      case 'array':
        final items = value['items'] ?? {};
        return {
          'type': 'array',
          'items': _mapJsonTypeToAvro(items, '${key}Item', types),
        };
      case 'object':
        final title = value['title'] ?? '${_capitalize(key)}Record';
        final nested = _generateAvro({...value, 'title': title}, title, types);
        types[title] = nested;
        return title;
      default:
        return 'string';
    }
  }

  // String _formatAvro(Map<String, dynamic> schema) {
  //   return const JsonEncoder.withIndent('  ').convert(schema);
  // }

  String _formatAvro(Map<String, dynamic> schema) {
    final buffer = StringBuffer();
    buffer.writeln('{');
    buffer.writeln('  "type"  : "${schema['type']}",');
    buffer.writeln('  "name"  : "${schema['name']}",');
    buffer.writeln('  "fields": [');

    final fields = schema['fields'] as List<dynamic>;
    for (int i = 0; i < fields.length; i++) {
      final field = fields[i] as Map<String, dynamic>;
      final name = field['name'];
      final type = field['type'];
      final defaultValue =
          field.containsKey('default')
              ? ', "default": ${json.encode(field['default'])}'
              : '';

      final typeStr =
          type is List
              ? '[${type.map((t) => t is String ? '"$t"' : json.encode(t)).join(', ')}]'
              : (type is String ? '"$type"' : json.encode(type));

      buffer.write('    { "name" : "$name",  "type" : $typeStr$defaultValue }');
      if (i < fields.length - 1) buffer.writeln(',');
    }

    buffer.writeln('\n  ]');
    buffer.write('}');
    return buffer.toString();
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
