class Export2DtoNestjs {
  // import { IsString, IsEmail, IsNotEmpty, MinLength } from 'class-validator';
  // import { ApiProperty } from '@nestjs/swagger';

  // export class CreateUserDto {
  //   @ApiProperty({ description: 'The full name of the user', example: 'John Doe' })
  //   @IsString()
  //   @IsNotEmpty()
  //   readonly name: string;

  //   @ApiProperty({ description: 'The email address of the user', example: 'john.doe@example.com' })
  //   @IsEmail()
  //   @IsNotEmpty()
  //   readonly email: string;

  //   @ApiProperty({ description: 'The password of the user (min 8 characters)', example: 'password123' })
  //   @IsString()
  //   @MinLength(8)
  //   readonly password: string;
  // }

  //   String jsonSchemaToNestDto(Map<String, dynamic> schema) {
  //     final buffer = StringBuffer();

  //     final generatedDtos = <String, String>{};
  //     _generateDto(schema, buffer, generatedDtos);

  //     return "import { IsString, IsNumber, IsBoolean, IsArray, IsOptional, Matches, ValidateIf } from 'class-validator';\n\n$buffer";
  //   }

  //   void _generateDto(
  //     Map<String, dynamic> schema,
  //     StringBuffer buffer,
  //     Map<String, String> generatedDtos,
  //   ) {
  //     final title = schema['title'] ?? 'GeneratedDto';
  //     if (generatedDtos.containsKey(title)) return;

  //     final Map properties = schema['properties'] ?? {};
  //     final requiredFields = List<String>.from(schema['required'] ?? []);
  //     final Map<String, dynamic> dependentRequired = schema['dependentRequired'] ?? {};

  //     final classBuffer = StringBuffer();
  //     classBuffer.writeln("export class $title {");

  //     properties.forEach((key, value) {
  //       final type = value['type'];
  //       final isRequired = requiredFields.contains(key);
  //       final tsType = _mapJsonTypeToTs(value, key, buffer, generatedDtos);
  //       final decorators = _collectDecorators(
  //         value,
  //         type,
  //         isRequired,
  //         key,
  //         dependentRequired,
  //       );

  //       for (final decorator in decorators) {
  //         classBuffer.writeln('  $decorator');
  //       }

  //       classBuffer.writeln('  ${isRequired ? '' : ''}$key: $tsType;\n');
  //     });

  //     classBuffer.writeln('}');
  //     generatedDtos[title] = classBuffer.toString();
  //     buffer.write(classBuffer.toString());
  //     buffer.writeln();
  //   }

  //   List<String> _collectDecorators(
  //     Map<String, dynamic> value,
  //     dynamic type,
  //     bool isRequired,
  //     String key,
  //     Map<String, dynamic> dependentRequired,
  //   ) {
  //     final decorators = <String>[];

  //     // conditionnel si champ requis sous dépendance
  //     dependentRequired.forEach((depField, requiredList) {
  //       if (requiredList.contains(key)) {
  //         decorators.add("@ValidateIf(o => o.$depField != null)");
  //       }
  //     });

  //     if (!isRequired) decorators.add('@IsOptional()');

  //     switch (type) {
  //       case 'string':
  //         decorators.add('@IsString()');
  //         if (value.containsKey('pattern')) {
  //           final pattern = value['pattern'].toString().replaceAll(r'\', r'\\');
  //           decorators.add('@Matches(RegExp(r\'$pattern\'))');
  //         }
  //         break;
  //       case 'number':
  //         decorators.add('@IsNumber()');
  //         break;
  //       case 'boolean':
  //         decorators.add('@IsBoolean()');
  //         break;
  //       case 'array':
  //         decorators.add('@IsArray()');
  //         break;
  //     }

  //     return decorators;
  //   }

  //   String _mapJsonTypeToTs(
  //     Map<String, dynamic> value,
  //     String key,
  //     StringBuffer buffer,
  //     Map<String, String> dtos,
  //   ) {
  //     final type = value['type'];
  //     if (type == 'array') {
  //       final items = value['items'] ?? {};
  //       return '${_mapJsonTypeToTs(items, '${key[0].toUpperCase()}${key.substring(1)}Item', buffer, dtos)}[]';
  //     } else if (type == 'object') {
  //       final title =
  //           value['title'] ?? '${key[0].toUpperCase()}${key.substring(1)}Dto';
  //       _generateDto({...value, 'title': title}, buffer, dtos);
  //       return title;
  //     }
  //     switch (type) {
  //       case 'string':
  //         return 'string';
  //       case 'number':
  //         return 'number';
  //       case 'boolean':
  //         return 'boolean';
  //       default:
  //         return 'any';
  //     }
  //   }
  // }

  String jsonSchemaToNestDto(Map<String, dynamic> schema) {
    final buffer = StringBuffer();

    final generatedDtos = <String, String>{};
    _generateDto(schema, buffer, generatedDtos);

    return "import { IsString, IsNumber, IsBoolean, IsArray, IsOptional, Matches, ValidateIf } from 'class-validator';\n\n$buffer";
  }

  void _generateDto(
    Map<String, dynamic> schema,
    StringBuffer buffer,
    Map<String, String> generatedDtos,
  ) {
    final title = schema['title'] ?? 'GeneratedDto';
    if (generatedDtos.containsKey(title)) return;

    final Map<dynamic, dynamic> properties = schema['properties'] ?? {};
    final requiredFields = List<String>.from(schema['required'] ?? []);
    final Map<String, dynamic> dependentRequired =
        schema['dependentRequired'] ?? {};

    final classBuffer = StringBuffer();
    classBuffer.writeln("export class $title {");

    properties.forEach((key, value) {
      final isAnyOf = value.containsKey('anyOf');
      final isRequired = requiredFields.contains(key);
      final tsType = _mapJsonTypeToTs(value, key, buffer, generatedDtos);
      final decorators =
          isAnyOf
              ? _handleAnyOfDecorators(value['anyOf'], isRequired, key)
              : _collectDecorators(
                value,
                value['type'],
                isRequired,
                key,
                dependentRequired,
              );

      for (final decorator in decorators) {
        classBuffer.writeln('  $decorator');
      }

      classBuffer.writeln('  ${isRequired ? '' : '?'}$key: $tsType;\n');
    });

    classBuffer.writeln('}');
    generatedDtos[title] = classBuffer.toString();
    buffer.write(classBuffer.toString());
    buffer.writeln();
  }

  List<String> _handleAnyOfDecorators(
    List<dynamic> schemas,
    bool isRequired,
    String key,
  ) {
    final decorators = <String>[];
    final patterns = <String>[];

    for (var i = 0; i < schemas.length; i++) {
      final subSchema = schemas[i];
      if (subSchema['type'] == 'string' && subSchema.containsKey('pattern')) {
        patterns.add(subSchema['pattern']);
      }
    }

    if (!isRequired) decorators.add('@IsOptional()');
    decorators.add('@IsString()');

    for (final pattern in patterns) {
      final sanitized = pattern.replaceAll(r'\', r'\\');
      decorators.add(
        "@ValidateIf(o => RegExp(r'$sanitized').hasMatch(o.$key ?? ''))",
      );
      decorators.add("@Matches(RegExp(r'$sanitized'))");
    }

    return decorators;
  }

  List<String> _collectDecorators(
    Map<String, dynamic> value,
    dynamic type,
    bool isRequired,
    String key,
    Map<String, dynamic> dependentRequired,
  ) {
    final decorators = <String>[];

    dependentRequired.forEach((depField, requiredList) {
      if (requiredList.contains(key)) {
        decorators.add("@ValidateIf(o => o.$depField != null)");
      }
    });

    if (!isRequired) decorators.add('@IsOptional()');

    switch (type) {
      case 'string':
        decorators.add('@IsString()');
        if (value.containsKey('pattern')) {
          final pattern = value['pattern'].toString().replaceAll(r'\', r'\\');
          decorators.add('@Matches(RegExp(r\'$pattern\'))');
        }
        break;
      case 'number':
        decorators.add('@IsNumber()');
        break;
      case 'boolean':
        decorators.add('@IsBoolean()');
        break;
      case 'array':
        decorators.add('@IsArray()');
        break;
    }

    return decorators;
  }

  String _mapJsonTypeToTs(
    Map<dynamic, dynamic> value,
    String key,
    StringBuffer buffer,
    Map<String, String> dtos,
  ) {
    if (value.containsKey('anyOf')) {
      List any = value['anyOf'];
      int i = 0;
      var iter = any.map<String>((s) {
        i++;
        return _mapJsonTypeToTs(s, '$key$i', buffer, dtos);
      });

      final types = iter.toSet().toList();
      return types.join(' | ');
    }

    final type = value['type'];
    if (type == 'array') {
      final Map<dynamic, dynamic> items = value['items'] ?? {};
      return '${_mapJsonTypeToTs(items, '${key[0].toUpperCase()}${key.substring(1)}Item', buffer, dtos)}[]';
    } else if (type == 'object') {
      final title =
          value['title'] ?? '${key[0].toUpperCase()}${key.substring(1)}Dto';
      _generateDto({...value, 'title': title}, buffer, dtos);
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
