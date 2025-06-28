import 'dart:convert';

String generateSqlFromJsonSchema(
  String jsonSchemaStr,
  String mainTableName, {
  String parentIdField = 'parent_id',
}) {
  final schema = jsonDecode(jsonSchemaStr);
  final buffer = StringBuffer();
  _generateTable(schema, mainTableName, buffer, parentIdField);
  return buffer.toString();
}

void _generateTable(
  Map<String, dynamic> schema,
  String tableName,
  StringBuffer buffer,
  String parentIdField,
  [String? parentTable]
) {
  final properties = schema['properties'] as Map<String, dynamic>;
  buffer.writeln('CREATE TABLE $tableName (');
  buffer.writeln('  id INTEGER PRIMARY KEY,');

  if (parentTable != null) {
    buffer.writeln('  $parentIdField INTEGER,');
    buffer.writeln(
        '  FOREIGN KEY ($parentIdField) REFERENCES $parentTable(id),');
  }

  properties.forEach((key, value) {
    final type = value['type'];
    if (type == 'object') {
      final childTableName = '${tableName}_$key';
      _generateTable(value, childTableName, buffer, parentIdField, tableName);
    } else {
      final sqlType = _mapJsonTypeToSql(type, value);
      buffer.writeln('  $key $sqlType,');
    }
  });

  var result = buffer.toString().trimRight();
  buffer.clear();
  result = result.replaceFirst(RegExp(r',$'), '');
  buffer.writeln('$result\n);');
}

String _mapJsonTypeToSql(String type, Map<String, dynamic> constraints) {
  switch (type) {
    case 'string':
      if (constraints.containsKey('maxLength')) {
        return 'VARCHAR(${constraints['maxLength']})';
      }
      return 'TEXT';
    case 'integer':
      return 'INTEGER';
    case 'number':
      return 'REAL';
    case 'boolean':
      return 'BOOLEAN';
    default:
      return 'TEXT';
  }
}