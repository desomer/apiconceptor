import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jsonschema/core/export/export2json_fake.dart';
import 'package:jsonschema/core/export/export2json_schema.dart';
import 'package:jsonschema/start_core.dart';
import 'package:markdown_widget/markdown_widget.dart';

class PanScrum extends StatefulWidget {
  const PanScrum({super.key});

  @override
  State<PanScrum> createState() => _PanScrumState();
}

class _PanScrumState extends State<PanScrum> {
  @override
  Widget build(BuildContext context) {
    if (currentCompany.currentModel == null) {
      return Text('select model first');
    }
    var exportSchema =
        Export2JsonSchema()..browse(currentCompany.currentModel!, false);

    StringBuffer md = jsonSchemaToMarkdown(exportSchema.json);

    var exportFake =
        Export2FakeJson()..browse(currentCompany.currentModel!, false);
    var json = exportFake.prettyPrintJson(exportFake.json);

    md.writeln('# 📘 exemple JSON\n');
    md.writeln("```json\n$json```");

    return Column(
      children: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: md.toString()));
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('copied to clipboard')));
          },
          child: Text('export'),
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
    buffer.writeln(
      '| Nom | Type | Requis | Défaut | Enum | Validation | Description |',
    );
    buffer.writeln(
      '|-----|------|--------|--------|------|------------|-------------|',
    );

    final globalRequired = schema['required'] ?? [];

    processNode(buffer, schema, '', globalRequired);

    return buffer;
  }

  void processSchemaEntry(
    StringBuffer buffer,
    Map<dynamic, dynamic> entry,
    String name,
    String isRequired,
  ) {
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
    final description = entry['description'] ?? '';
    final defaultValue =
        entry.containsKey('default') ? '`${entry['default']}`' : '';
    final enumValues =
        entry.containsKey('enum')
            ? entry['enum'].map((e) => '`$e`').join(', ')
            : '';

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

    buffer.writeln(
      '| `$name` | `$type` | $isRequired | $defaultValue | $enumValues | $validationStr | $description |',
    );

    // Handle nested object
    if (type == 'object' && entry.containsKey('properties')) {
      final nestedRequired = entry['required'] ?? [];
      processNode(buffer, entry, name, nestedRequired);
    }

    // Handle array
    if (type == 'array' && entry.containsKey('items')) {
      Map<dynamic, dynamic> items = entry['items'];
      processSchemaEntry(buffer, items, '$name[]', '❌ Non');
    }

    // Handle $ref
    if (entry.containsKey(r'$ref')) {
      buffer.writeln(
        '| `$name` | `\$ref` | ❌ Non |  |  |  | Référence vers `${entry[r'$ref']}` |',
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
        final isRequired = requiredFields.contains(key) ? '✅ Oui' : '❌ Non';
        processSchemaEntry(buffer, value, fullPath, isRequired);
      });
    }
  }
}
