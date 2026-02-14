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

class ObjectMD {
  final String jsonPath;
  final String title;
  final StringBuffer md = StringBuffer();
  final List<ObjectMD> children = [];
  Map<dynamic, dynamic> root;
  bool toDisplay = true;

  ObjectMD({required this.jsonPath, required this.title, required this.root});
}

class _PanScrumState extends State<PanScrum> {
  bool full = true;
  bool showExampleDto = true;
  bool showExampleMongoose = true;
  bool showExampleAvro = true;
  List<String> refDisplayed = [];

  @override
  Widget build(BuildContext context) {
    if (currentCompany.currentModel == null) {
      return Text('select model first');
    }
    refDisplayed.clear();
    var exportSchema =
        Export2JsonSchema()..browse(currentCompany.currentModel!, false);

    StringBuffer md = StringBuffer();

    ObjectMD omd = jsonSchemaToMarkdown(
      currentCompany.currentModel!.headerName,
      exportSchema.json,
    );

    md.writeln('# 📘 Global structure\n');
    md.write(buildTreeMarkdown(omd));

    writeObjectExplain(md, omd);

    var exportFake = Export2FakeJson(
      modeArray: ModeArrayEnum.anyInstance,
      mode: ModeEnum.fake,
      propMode: PropertyRequiredEnum.required,
    )..browse(currentCompany.currentModel!, false);
    var json = exportFake.prettyPrintJson(exportFake.json);

    md.writeln('# 📘 exemple JSON : only required properties\n');
    md.writeln("```json\n$json");
    md.writeln("```");

    exportFake = Export2FakeJson(
      modeArray: ModeArrayEnum.anyInstance,
      mode: ModeEnum.fake,
      propMode: PropertyRequiredEnum.all,
    )..browse(currentCompany.currentModel!, false);
    json = exportFake.prettyPrintJson(exportFake.json);

    md.writeln('# 📘 exemple JSON : all properties\n');
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

  void writeObjectExplain(StringBuffer md, ObjectMD omd) {
    md.write(omd.md.toString());
    for (var child in omd.children) {
      if (child.toDisplay) {
        writeObjectExplain(md, child);
      }
    }
  }

  String buildTreeMarkdown(ObjectMD tree) {
    final buffer = StringBuffer();

    buffer.writeln('`${tree.jsonPath}`');

    void walk(ObjectMD node, {String prefix = ''}) {
      final entries = node.children;
      for (var i = 0; i < entries.length; i++) {
        final isLast = i == entries.length - 1;
        var jsonPath = entries[i].jsonPath;
        var split = jsonPath.split('.');
        String name = split.isNotEmpty ? split.last : jsonPath;
        final key = '`$name`';

        var title = entries[i].title;

        final connector = isLast ? '└── ' : '├── ';
        var prefixconnectorkey = '$prefix$connector$key';
        StringBuffer tab = StringBuffer();
        var nbSpace = 60 - prefixconnectorkey.length;
        if (nbSpace < 3) {
          nbSpace = 3;
        }
        for (var i = 0; i < nbSpace; i++) {
          tab.write(' ');
        }
        buffer.writeln('$prefixconnectorkey$tab$title');

        final newPrefix = prefix + (isLast ? '    ' : '│   ');
        walk(entries[i], prefix: newPrefix);
      }
    }

    walk(tree);
    return buffer.toString();
  }

  ObjectMD jsonSchemaToMarkdown(String name, Map<dynamic, dynamic> schema) {
    var objectMD = ObjectMD(
      jsonPath: name,
      title: schema['title'] ?? '',
      root: schema,
    );
    final buffer = objectMD.md;

    buffer.writeln('# 📘 Documentation du schéma JSON\n');

    //if (schema.containsKey('title')) buffer.writeln('## ${schema['title']}\n');
    if (schema.containsKey('description')) {
      buffer.writeln('${schema['description']}\n');
    }

    final globalRequired = schema['required'] ?? [];

    addTableHeader(buffer, name);
    processObject(objectMD, schema, '', globalRequired);

    return objectMD;
  }

  void addTableHeader(StringBuffer buffer, String name) {
    if (name.isNotEmpty) {
      buffer.writeln('## 🧩 Object $name\n');
    }
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
  }

  void processAttr(
    ObjectMD objectMD,
    Map<dynamic, dynamic> entry,
    String jsonPath,
    String isRequired, {
    bool isInArray = false,
  }) {
    // Handle combinators
    if (entry.containsKey('anyOf')) {
      for (int i = 0; i < entry['anyOf'].length; i++) {
        final option = entry['anyOf'][i];
        processAttr(objectMD, option, '$jsonPath (anyOf ${i + 1})', isRequired);
      }
      return;
    }
    if (entry.containsKey('oneOf')) {
      for (int i = 0; i < entry['oneOf'].length; i++) {
        final option = entry['oneOf'][i];
        processAttr(objectMD, option, '$jsonPath (oneOf ${i + 1})', isRequired);
      }
      return;
    }
    if (entry.containsKey('allOf')) {
      final merged = <String, dynamic>{};
      for (final part in entry['allOf']) {
        merged.addAll(part);
      }
      processAttr(objectMD, merged, jsonPath, isRequired);
      return;
    }

    final type =
        entry['type'] ?? (entry.containsKey(r'$ref') ? r'$ref' : 'inconnu');

    String description = entry['description'] ?? '';
    description = description.replaceAll('\n', '<br>');
    // Handle $ref
    if (type == r'$ref') {
      String nameRef = entry[r'$ref'];
      nameRef = nameRef.replaceFirst('#/\$def/', '\$');
      description = 'Ref. to `$nameRef`';
      isRequired = '';
    }

    final title = entry['title'] ?? '';
    final defaultValue =
        entry.containsKey('default') ? '`${entry['default']}`' : '';
    final enumValues =
        entry.containsKey('enum')
            ? entry['enum'].map((e) => '`$e`').join(', ')
            : '';

    String path = jsonPath.replaceAll(".", ">");
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
      'format',
    ]) {
      if (entry.containsKey(field)) {
        String f;
        if (field == 'pattern') {
          f = '`RegExp`';
        } else {
          f = '`${entry[field]}`';
        }
        if (field == 'format') {
          if (validations.contains('pattern: `RegExp` ')) {
            validations.remove('pattern: `RegExp` ');
          }
        }

        validations.add('$field: $f ');
      }
    }
    final validationStr = validations.join(', ');
    var buffer = objectMD.md;

    var split = jsonPath.split('.');
    String name = split.isNotEmpty ? split.last : jsonPath;

    if (isInArray && type == 'object') {
      // ajoute pas la ligne d'object dans un tableau, mais traite directement les propriétés de l'objet
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
      var childMD = ObjectMD(
        jsonPath: jsonPath,
        title: title,
        root: objectMD.root,
      );
      objectMD.children.add(childMD);
      addTableHeader(childMD.md, jsonPath);
      processObject(childMD, entry, jsonPath, nestedRequired);
    }

    if (type == r'$ref') {
      final nestedRequired = entry['required'] ?? [];
      var childMD = ObjectMD(
        jsonPath: jsonPath,
        title: title,
        root: objectMD.root,
      );
      String nameRef = entry[r'$ref'];
      if (!refDisplayed.contains(nameRef)) {
        refDisplayed.add(nameRef);
      } else {
        childMD.toDisplay = false;
      }

      objectMD.children.add(childMD);
      nameRef = nameRef.replaceFirst('#/\$def/', '\$');
      childMD.md.writeln('## 🧩 Definition $nameRef\n');
      addTableHeader(childMD.md, '');
      Map def = getObjectFromPath(objectMD.root, entry[r'$ref']);
      processObject(childMD, def, nameRef, nestedRequired);
    }

    // Handle array
    if (type == 'array' && entry.containsKey('items')) {
      Map<dynamic, dynamic> items = entry['items'];
      items['title'] = title;
      processAttr(objectMD, items, '$jsonPath[]', '❌ No', isInArray: true);
    }
  }

  void processObject(
    ObjectMD objectMD,
    Map<dynamic, dynamic> node,
    String path,
    List requiredFields,
  ) {
    if (node.containsKey('properties')) {
      node['properties'].forEach((key, value) {
        final fullPath = path.isEmpty ? key : '$path.$key';
        final isRequired = requiredFields.contains(key) ? '✅ Yes' : '❌ No';
        processAttr(objectMD, value, fullPath, isRequired);
      });
    }
  }

  dynamic getObjectFromPath(Map<dynamic, dynamic> root, String path) {
    // On enlève le "#/" au début si présent
    if (path.startsWith("#/")) {
      path = path.substring(2);
    }

    // On découpe le chemin
    final parts = path.split('/');

    dynamic current = root;

    for (final part in parts) {
      if (current is Map<dynamic, dynamic> && current.containsKey(part)) {
        current = current[part];
      } else {
        return null; // chemin invalide
      }
    }

    return current;
  }
}
