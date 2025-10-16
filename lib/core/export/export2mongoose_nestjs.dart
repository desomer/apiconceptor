class Export2DtoMongooseNestjs {
  String jsonSchemaToNestMongoose(Map<String, dynamic> schema) {
    final buffer = StringBuffer();
    final generatedSchemas = <String, String>{};
    _generateSchema(schema, buffer, generatedSchemas);

    return "import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';\nimport { Document } from 'mongoose';\n\n$buffer";
  }

  void _generateSchema(
    Map<String, dynamic> schema,
    StringBuffer buffer,
    Map<String, String> generatedSchemas,
  ) {
    final title = schema['title'] ?? 'GeneratedSchema';
    if (generatedSchemas.containsKey(title)) return;

    final Map<dynamic, dynamic> properties = schema['properties'] ?? {};
    final requiredFields = List<String>.from(schema['required'] ?? []);

    final classBuffer = StringBuffer();
    classBuffer.writeln("@Schema()");
    classBuffer.writeln("export class $title extends Document {");

    properties.forEach((key, value) {
      final isRequired = requiredFields.contains(key);
      final tsType = _mapJsonTypeToTs(value, key, buffer, generatedSchemas);
      final propOptions = _buildPropOptions(value, isRequired);

      classBuffer.writeln('  @Prop($propOptions)');
      classBuffer.writeln('  $key: $tsType;\n');
    });

    classBuffer.writeln("}");
    classBuffer.writeln("export const ${title}Schema = SchemaFactory.createForClass($title);\n");

    generatedSchemas[title] = classBuffer.toString();
    buffer.write(classBuffer.toString());
  }

  String _buildPropOptions(Map<String, dynamic> value, bool isRequired) {
    final options = <String>[];

    if (isRequired) options.add('required: true');
    if (value['default'] != null) options.add("default: ${value['default']}");

    if (value['enum'] != null && value['type'] == 'string') {
      final enumValues = (value['enum'] as List).map((e) => "'$e'").join(', ');
      options.add("enum: [$enumValues]");
    }

    return options.isEmpty ? '' : '{ ${options.join(', ')} }';
  }

  String _mapJsonTypeToTs(
    Map<dynamic, dynamic> value,
    String key,
    StringBuffer buffer,
    Map<String, String> schemas,
  ) {
    final type = value['type'];
    if (type == 'array') {
      final items = value['items'] ?? {};
      return '${_mapJsonTypeToTs(items, '${key}Item', buffer, schemas)}[]';
    } else if (type == 'object') {
      final title = value['title'] ?? '${key[0].toUpperCase()}${key.substring(1)}Schema';
      _generateSchema({...value, 'title': title}, buffer, schemas);
      return title;
    }

    switch (type) {
      case 'string':
        return 'string';
      case 'number':
        return 'number';
      case 'boolean':
        return 'boolean';
      default:
        return 'any';
    }
  }
}