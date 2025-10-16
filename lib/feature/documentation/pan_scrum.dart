import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jsonschema/core/export/export2avro.dart';
import 'package:jsonschema/core/export/export2dto_nestjs.dart';
import 'package:jsonschema/core/export/export2json_fake.dart';
import 'package:jsonschema/core/export/export2json_schema.dart';
import 'package:jsonschema/core/export/export2mongoose_nestjs.dart';
import 'package:jsonschema/start_core.dart';
import 'package:markdown_widget/markdown_widget.dart';

class PanScrum extends StatefulWidget {
  const PanScrum({super.key});

  @override
  State<PanScrum> createState() => _PanScrumState();
}

class _PanScrumState extends State<PanScrum> {
  bool full = true;
  bool showExampleDto = true;
  bool showExampleMongoose = true;
  bool showExampleAvro = true;

  @override
  Widget build(BuildContext context) {
    if (currentCompany.currentModel == null) {
      return Text('select model first');
    }
    var exportSchema =
        Export2JsonSchema()..browse(currentCompany.currentModel!, false);

    StringBuffer md = jsonSchemaToMarkdown(exportSchema.json);

    var exportFake = Export2FakeJson(
      modeArray: ModeArrayEnum.anyInstance,
      mode: ModeEnum.fake,
    )..browse(currentCompany.currentModel!, false);
    var json = exportFake.prettyPrintJson(exportFake.json);

    md.writeln('# 📘 exemple JSON\n');
    md.writeln("```json\n$json");
    md.writeln("```");

    if (showExampleDto) {
      var exportJS = Export2DtoNestjs().jsonSchemaToNestDto(exportSchema.json);
      md.writeln('---');
      md.writeln('# 📘 exemple DTO\n');
      md.writeln("```typescript\n$exportJS");
      md.writeln("```");
    }

    if (showExampleMongoose) {
      var exportMongoose = Export2DtoMongooseNestjs().jsonSchemaToNestMongoose(
        exportSchema.json,
      );
      md.writeln('---');
      md.writeln('# 📘 exemple Mongoose\n');
      md.writeln("```typescript\n$exportMongoose");
      md.writeln("```");
    }

    if (showExampleAvro) {
      var exportAvro = Export2Avro().jsonSchemaToAvro(exportSchema.json);
      md.writeln('---');
      md.writeln('# 📘 exemple avro\n');
      md.writeln("```json\n$exportAvro");
      md.writeln("```");
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: !full,
              onChanged: (value) {
                setState(() {
                  full = !(value ?? true);
                });
              },
            ),
            const Text('dense markdown table'),
            const SizedBox(width: 20),
            Checkbox(
              value: showExampleDto,
              onChanged: (value) {
                setState(() {
                  showExampleDto = value ?? true;
                });
              },
            ),
            const Text('Show DTO example'),
            const SizedBox(width: 20),
            Checkbox(
              value: showExampleMongoose,
              onChanged: (value) {
                setState(() {
                  showExampleMongoose = value ?? true;
                });
              },
            ),
            const Text('Show Mongoose example'),
            const SizedBox(width: 20),
            Checkbox(
              value: showExampleAvro,
              onChanged: (value) {
                setState(() {
                  showExampleAvro = value ?? true;
                });
              },
            ),
            const Text('Show Avro example'),
          ],
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.copy),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: md.toString()));
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('copied to clipboard')));
          },
          label: Text('Generate User story in clipboard'),
        ),
        Expanded(
          child: MarkdownWidget(
            data: md.toString(),
            config: MarkdownConfig.darkConfig,
          ),
        ),
      ],
    );
  }

  StringBuffer jsonSchemaToMarkdown(Map<dynamic, dynamic> schema) {
    final buffer = StringBuffer();

    buffer.writeln('# 📘 Documentation du schéma JSON\n');

    if (schema.containsKey('title')) buffer.writeln('## ${schema['title']}\n');
    if (schema.containsKey('description')) {
      buffer.writeln('${schema['description']}\n');
    }

    buffer.writeln('## 🧩 Propriétés\n');
    if (full) {
      buffer.writeln(
        '| Name | Type | Required | Default | Enum | Valid. | title | Desc. | Tags |',
      );
      buffer.writeln(
        '|------|------|----------|---------|------|--------|-------|-------|------|',
      );
    } else {
      buffer.writeln(
        '| Name | Type | Required | Enum | Valid. | Title | Desc. |',
      );
      buffer.writeln(
        '|------|------|----------|------|--------|-------|-------|',
      );
    }

    final globalRequired = schema['required'] ?? [];

    processNode(buffer, schema, '', globalRequired);

    return buffer;
  }

  void processSchemaEntry(
    StringBuffer buffer,
    Map<dynamic, dynamic> entry,
    String name,
    String isRequired, {
    bool isInArray = false,
  }) {
    // Handle combinators
    if (entry.containsKey('anyOf')) {
      for (int i = 0; i < entry['anyOf'].length; i++) {
        final option = entry['anyOf'][i];
        processSchemaEntry(
          buffer,
          option,
          '$name (anyOf ${i + 1})',
          isRequired,
        );
      }
      return;
    }
    if (entry.containsKey('oneOf')) {
      for (int i = 0; i < entry['oneOf'].length; i++) {
        final option = entry['oneOf'][i];
        processSchemaEntry(
          buffer,
          option,
          '$name (oneOf ${i + 1})',
          isRequired,
        );
      }
      return;
    }
    if (entry.containsKey('allOf')) {
      final merged = <String, dynamic>{};
      for (final part in entry['allOf']) {
        merged.addAll(part);
      }
      processSchemaEntry(buffer, merged, name, isRequired);
      return;
    }

    final type =
        entry['type'] ?? (entry.containsKey(r'$ref') ? r'$ref' : 'inconnu');
    String description = entry['description'] ?? '';
    description = description.replaceAll('\n', '<br>');

    final title = entry['title'] ?? '';
    final defaultValue =
        entry.containsKey('default') ? '`${entry['default']}`' : '';
    final enumValues =
        entry.containsKey('enum')
            ? entry['enum'].map((e) => '`$e`').join(', ')
            : '';

    String path = name.replaceAll(".", ">");
    var n = currentCompany.currentModel!.mapInfoByJsonPath['root>$path'];
    var t = n?.properties?['#tag'];
    var tags = '';
    if (t is List) {
      for (var element in t) {
        tags = '$tags[$element]';
      }
    }

    final validations = <String>[];
    for (final field in [
      'minLength',
      'maxLength',
      'minimum',
      'maximum',
      'pattern',
    ]) {
      if (entry.containsKey(field)) {
        validations.add('$field: `${entry[field]}`');
      }
    }
    final validationStr = validations.join(', ');

    if (isInArray && type == 'object') {
      // ajoute pas la ligne d'object
    } else {
      if (full) {
        buffer.writeln(
          '| `$name` | `$type` | $isRequired | $defaultValue | $enumValues | $validationStr | $title | $description | $tags |',
        );
      } else {
        buffer.writeln(
          '| `$name` | `$type` | $isRequired | $enumValues | $validationStr | $title | $description |',
        );
      }
    }

    // Handle nested object
    if (type == 'object' && entry.containsKey('properties')) {
      final nestedRequired = entry['required'] ?? [];
      processNode(buffer, entry, name, nestedRequired);
    }

    // Handle array
    if (type == 'array' && entry.containsKey('items')) {
      Map<dynamic, dynamic> items = entry['items'];
      processSchemaEntry(buffer, items, '$name[]', '❌ No', isInArray: true);
    }

    // Handle $ref
    if (entry.containsKey(r'$ref')) {
      buffer.writeln(
        '| `$name` | `\$ref` | ❌ No |  |  |  |  | Ref. to `${entry[r'$ref']}` |',
      );
    }
  }

  void processNode(
    StringBuffer buffer,
    Map<dynamic, dynamic> node,
    String path,
    List requiredFields,
  ) {
    if (node.containsKey('properties')) {
      node['properties'].forEach((key, value) {
        final fullPath = path.isEmpty ? key : '$path.$key';
        final isRequired = requiredFields.contains(key) ? '✅ Yes' : '❌ No';
        processSchemaEntry(buffer, value, fullPath, isRequired);
      });
    }
  }
}
