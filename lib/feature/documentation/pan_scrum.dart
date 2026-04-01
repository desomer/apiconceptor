import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jsonschema/core/api/widget_api_helper.dart';
import 'package:jsonschema/core/export/export2avro.dart';
import 'package:jsonschema/core/export/export2dto_nestjs.dart';
import 'package:jsonschema/core/export/export2json_fake.dart';
import 'package:jsonschema/core/export/export2json_schema.dart';
import 'package:jsonschema/core/export/export2mongoose_nestjs.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:markdown_widget/markdown_widget.dart';

enum ScrumModeEnum { model, api }

class PanScrumModel extends StatefulWidget {
  const PanScrumModel({super.key, required this.mode, this.requestHelper});
  final ScrumModeEnum mode;
  final WidgetAPIHelper? requestHelper;
  @override
  State<PanScrumModel> createState() => _PanScrumModelState();
}

class _PanScrumModelState extends State<PanScrumModel> {
  DocumentationInfo info = DocumentationInfo();
  bool apiIsLoading = false;

  Future<WidgetAPIHelper> initAPI() async {
    var apiCallInfo = widget.requestHelper!.apiCallInfo;

    if (apiCallInfo.currentAPIRequest != null &&
        apiCallInfo.currentAPIResponse != null &&
        apiCallInfo.responseSchema != null) {
      apiIsLoading = true;
      return widget.requestHelper!;
    }

    info.showExampleAvro = false;
    info.showExampleDto = false;
    info.showExampleMongoose = false;

    var future1 = GoTo().getApiRequestModel(
      apiCallInfo,
      currentCompany.listAPI!.namespace!,
      apiCallInfo.attrApi.masterID!,
      withDelay: false,
    );

    var future2 = GoTo().getApiResponseModel(
      apiCallInfo,
      currentCompany.listAPI!.namespace!,
      apiCallInfo.attrApi.masterID!,
      withDelay: false,
    );

    var apiRequest = await future1;
    var apiResponse = await future2;

    apiCallInfo.responseSchema = await apiResponse.getSubSchema(subNode: 200);
    apiCallInfo.currentAPIRequest = apiRequest;
    apiCallInfo.currentAPIResponse = apiResponse;
    apiCallInfo.responseSchema?.headerName = 'Response 200';
    apiIsLoading = true;

    return widget.requestHelper!;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == ScrumModeEnum.api) {
      if (apiIsLoading) {
        return DocumentationOptions(
          state: this,
          context: context,
          info: info,
        ).getAPIDocumentation(widget.requestHelper);
      }

      return FutureBuilder(
        future: initAPI(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Text('Erreur : ${snapshot.error}');
          }

          return DocumentationOptions(
            state: this,
            context: context,
            info: info,
          ).getAPIDocumentation(widget.requestHelper);
        },
      );
    } else {
      if (currentCompany.currentModel == null) {
        return Text('select model first');
      }
      return DocumentationOptions(
        info: info,
        state: this,
        context: context,
      ).getModelDocumentation();
    }
  }
}

class DocumentationInfo {
  bool full = true;
  bool showExampleDto = true;
  bool showExampleMongoose = true;
  bool showExampleAvro = true;
}

class DocumentationOptions {
  final State state;
  final BuildContext context;
  final DocumentationInfo info;

  List<String> refDisplayed = [];

  DocumentationOptions({
    required this.state,
    required this.context,
    required this.info,
  });

  Widget getAPIDocumentation(final WidgetAPIHelper? requestHelper) {
    refDisplayed.clear();
    var apiCallInfo = requestHelper!.apiCallInfo;
    Export2JsonSchema? exportSchema;

    if (apiCallInfo.responseSchema != null) {
      exportSchema = Export2JsonSchema(
        config: BrowserConfig(
          isGet: apiCallInfo.httpOperation == 'get',
          isApi: true,
        ),
      )..browse(apiCallInfo.responseSchema!, false);
    }

    StringBuffer md = StringBuffer();

    md.writeln('# 🔗 API Specification\n');

    md.writeln(
      getDocAccessor(apiCallInfo.currentAPIRequest!).get() ??
          'No documentation',
    );

    //     md.writeln('## API objective');
    //     md.writeln('''
    // - Décrire l API permettant de [objectif fonctionnel].
    //   Exemple : Permettre à un client de récupérer ses informations de profil.
    //       ''');

    //     md.writeln('''## Context
    // - Pourquoi cette API est nécessaire
    // - À qui elle sert (utilisateurs, services, applications)
    // - Problème résolu / valeur ajoutée
    // ''');

    //     md.writeln('''## Functional description
    // - Ce que l’API doit faire (vue métier)
    // - Données manipulées
    // - Règles métier importantes
    // - Restrictions éventuelles
    // ''');

    md.writeln('## Endpoint');
    md.writeln('#### Method');
    md.writeln("`${apiCallInfo.httpOperation.toUpperCase()}`");

    md.writeln('#### URL');
    var url = apiCallInfo.getURLfromNode(
      currentCompany.listAPI!.getNodeByMasterIdPath(
        apiCallInfo.attrApi.masterID!,
      )!,
    );
    md.writeln('`$url `');

    md.writeln('### Parameters');
    md.writeln(
      '''
| Type  | Name       | Required    | Default | enum | valid. | title    | Desc.            |
|-------|------------|-------------|---------|------|--------|----------|------------------|''',
    );

    apiCallInfo.initParamsForDoc();
    for (var param in apiCallInfo.params) {
      var info = param.info!;
      var entry = info.properties ?? {};
      bool required = (entry['required'] == true);
      String title = entry['title'] ?? '';
      String description = entry['description'] ?? '';
      final defaultValue =
          entry.containsKey('default') ? '`${entry['default']}`' : '';
      String enumValues = getEnumMD(entry);

      // if (enumValues.length > 50) {
      //   print(enumValues);
      // }
      String validationStr = doValidationMD(entry);
      md.writeln(
        '| `${param.type}` | `${param.name}` | ${required ? '✅ Yes' : '❌ No'} | $defaultValue | $enumValues | $validationStr | $title | $description |',
      );
    }

    md.writeln('### Request example');
    md.writeln('`${apiCallInfo.httpOperation.toUpperCase()} $url`');

    md.writeln('# Response HTTP 200');
    if (apiCallInfo.responseSchema == null) {
      md.writeln('No response schema');
    } else {
      getMarkdownModel(
        apiCallInfo.responseSchema!,
        exportSchema!,
        md,
        apiCallInfo.httpOperation == 'get',
      );
    }

    return getWidgetToDisplay(md);
  }

  String getEnumMD(Map entry) {
    String enumValues = '';
    if (entry.containsKey('enum')) {
      if (entry['enum'] is String) {
        String en = entry['enum'].toString();
        enumValues = en
            .split('\n')
            .map((e) => '`$e`')
            .join(', ')
            .replaceAll(RegExp(r'\r\n?'), '');
      } else if (entry['enum'] is List) {
        enumValues = (entry['enum'] as List)
            .map((e) => '`$e`')
            .join(', ')
            .replaceAll(RegExp(r'\r\n?'), '');
      }
    }
    return enumValues;
  }

  ModelAccessorAttr getDocAccessor(ModelSchema model) {
    var examplesNode = model.getExtendedNode("#doc");

    var access = ModelAccessorAttr(
      node: examplesNode,
      schema: model,
      propName: '#doc',
    );
    return access;
  }

  Widget getModelDocumentation() {
    refDisplayed.clear();
    var exportSchema = Export2JsonSchema(
      config: BrowserConfig(
        isApi: currentCompany.currentModel!.readOnly != null,
      ),
    )..browse(currentCompany.currentModel!, false);

    StringBuffer md = StringBuffer();

    md.writeln('# 🔗 Model Specification\n');
    md.writeln(
      getDocAccessor(currentCompany.currentModel!).get() ?? 'No documentation',
    );

    getMarkdownModel(currentCompany.currentModel!, exportSchema, md, null);

    return getWidgetToDisplay(md);
  }

  Column getWidgetToDisplay(StringBuffer md) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: !info.full,
              onChanged: (value) {
                // ignore: invalid_use_of_protected_member
                state.setState(() {
                  info.full = !(value ?? true);
                });
              },
            ),
            const Text('dense markdown table'),
            const SizedBox(width: 20),
            Checkbox(
              value: info.showExampleDto,
              onChanged: (value) {
                // ignore: invalid_use_of_protected_member
                state.setState(() {
                  info.showExampleDto = value ?? true;
                });
              },
            ),
            const Text('Show DTO example'),
            const SizedBox(width: 20),
            Checkbox(
              value: info.showExampleMongoose,
              onChanged: (value) {
                // ignore: invalid_use_of_protected_member
                state.setState(() {
                  info.showExampleMongoose = value ?? true;
                });
              },
            ),
            const Text('Show Mongoose example'),
            const SizedBox(width: 20),
            Checkbox(
              value: info.showExampleAvro,
              onChanged: (value) {
                // ignore: invalid_use_of_protected_member
                state.setState(() {
                  info.showExampleAvro = value ?? true;
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

  void getMarkdownModel(
    ModelSchema modelschema,
    Export2JsonSchema<Map<String, dynamic>> exportSchema,
    StringBuffer md,
    bool? readOnly,
  ) {
    ObjectMD omd = jsonSchemaToMarkdown(
      modelschema,
      modelschema.headerName,
      exportSchema.json,
    );

    md.writeln('# 📘 Global structure\n');
    md.write(buildTreeMarkdown(omd));

    writeObjectExplain(md, omd);

    var exportFake = Export2FakeJson(
      modeArray: ModeArrayEnum.anyInstance,
      mode: ModeEnum.fake,
      propMode: PropertyRequiredEnum.required,
      config: BrowserConfig(isGet: readOnly, isApi: readOnly != null),
    )..browse(modelschema, false);
    var json = exportFake.prettyPrintJson(exportFake.json);

    md.writeln('# 📘 exemple JSON : only required properties\n');
    md.writeln("```json\n$json");
    md.writeln("```");

    exportFake = Export2FakeJson(
      modeArray: ModeArrayEnum.anyInstance,
      mode: ModeEnum.fake,
      propMode: PropertyRequiredEnum.all,
      config: BrowserConfig(isGet: readOnly, isApi: readOnly != null),
    )..browse(modelschema, false);
    json = exportFake.prettyPrintJson(exportFake.json);

    md.writeln('# 📘 exemple JSON : all properties\n');
    md.writeln("```json\n$json");
    md.writeln("```");

    if (info.showExampleDto) {
      var exportJS = Export2DtoNestjs().jsonSchemaToNestDto(exportSchema.json);
      md.writeln('---');
      md.writeln('# 📘 exemple DTO\n');
      md.writeln("```typescript\n$exportJS");
      md.writeln("```");
    }

    if (info.showExampleMongoose) {
      var exportMongoose = Export2DtoMongooseNestjs().jsonSchemaToNestMongoose(
        exportSchema.json,
      );
      md.writeln('---');
      md.writeln('# 📘 exemple Mongoose\n');
      md.writeln("```typescript\n$exportMongoose");
      md.writeln("```");
    }

    if (info.showExampleAvro) {
      var exportAvro = Export2Avro().jsonSchemaToAvro(exportSchema.json);
      md.writeln('---');
      md.writeln('# 📘 exemple avro\n');
      md.writeln("```json\n$exportAvro");
      md.writeln("```");
    }
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

  ObjectMD jsonSchemaToMarkdown(
    ModelSchema modelschema,
    String name,
    Map<dynamic, dynamic> schema,
  ) {
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

    addTableHeader(buffer, 'root', name, schema['title'] ?? '');
    processObject(modelschema, objectMD, schema, '', globalRequired);

    return objectMD;
  }

  void addTableHeader(
    StringBuffer buffer,
    String type,
    String name,
    String title,
  ) {
    if (type == "sub") {
      buffer.writeln('#### Bloc $name - $title');
    } else if (type == "ref") {
      buffer.writeln('## 🧩 Definition $name - $title\n');
    } else {
      buffer.writeln('## 🧩 Object $name - $title\n');
    }

    if (info.full) {
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
    ModelSchema schema,
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
        processAttr(
          schema,
          objectMD,
          option,
          '$jsonPath (anyOf ${i + 1})',
          isRequired,
        );
      }
      return;
    }
    if (entry.containsKey('oneOf')) {
      for (int i = 0; i < entry['oneOf'].length; i++) {
        final option = entry['oneOf'][i];
        processAttr(
          schema,
          objectMD,
          option,
          '$jsonPath (oneOf ${i + 1})',
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
      processAttr(schema, objectMD, merged, jsonPath, isRequired);
      return;
    }

    String type = '';
    if (entry['type'] is List) {
      type = (entry['type'] as List).join(', ');
    } else {
      type =
          entry['type'] ?? (entry.containsKey(r'$ref') ? r'$ref' : 'inconnu');
    }

    String description = entry['description'] ?? '';
    description = description.replaceAll('\n', '<br>');
    String? nameRef;

    // Handle $ref
    if (type == r'$ref') {
      nameRef = entry[r'$ref'];
      nameRef = nameRef!.replaceFirst('#/\$def/', '\$');
      description = 'Ref. to `$nameRef`';
    }

    String title = entry['title'] ?? '';
    final defaultValue =
        entry.containsKey('default') ? '`${entry['default']}`' : '';
    final enumValues = getEnumMD(entry);

    String path = jsonPath.replaceAll(".", ">");
    var n = schema.mapInfoByJsonPath['root>$path'];

    var t = n?.properties?['#tag'];
    var tags = '';
    if (t is List) {
      for (var element in t) {
        tags = '$tags[$element]';
      }
    }

    String validationStr = doValidationMD(entry);
    var buffer = objectMD.md;

    var split = jsonPath.split('.');
    String name = split.isNotEmpty ? split.last : jsonPath;

    if (isInArray && type == 'object') {
      // ajoute pas la ligne d'object dans un tableau, mais traite directement les propriétés de l'objet
    } else {
      var typeDisplay = nameRef ?? type;

      if (info.full) {
        buffer.writeln(
          '| `$name` | `$typeDisplay` | $isRequired | $defaultValue | $enumValues | $validationStr | $title | $description | $tags |',
        );
      } else {
        buffer.writeln(
          '| `$name` | `$typeDisplay` | $isRequired | $enumValues | $validationStr | $title | $description |',
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
      addTableHeader(childMD.md, 'sub', jsonPath, title);
      processObject(schema, childMD, entry, jsonPath, nestedRequired);
    }

    if (type == r'$ref') {
      var childMD = ObjectMD(
        jsonPath: jsonPath,
        title: title,
        root: objectMD.root,
      );
      String nameRef = entry[r'$ref'];
      if (!refDisplayed.contains(nameRef)) {
        refDisplayed.add(nameRef);
      } else {
        // deja affiché, on évite la récursivité infinie
        childMD.toDisplay = false;
      }

      objectMD.children.add(childMD);
      nameRef = nameRef.replaceFirst('#/\$def/', '\$');
      Map def = getObjectFromPath(objectMD.root, entry[r'$ref']);
      final nestedRequired = def['required'] ?? [];
      if (title.isEmpty) {
        title = def['title'] ?? '';
      }
      addTableHeader(childMD.md, 'ref', nameRef, title);
      processObject(schema, childMD, def, nameRef, nestedRequired);
    }

    // Handle array
    if (type == 'array' && entry.containsKey('items')) {
      Map<dynamic, dynamic> items = entry['items'];
      items['title'] = title;
      processAttr(
        schema,
        objectMD,
        items,
        '$jsonPath[]',
        '❌ No',
        isInArray: true,
      );
    }
  }

  String doValidationMD(Map<dynamic, dynamic> entry) {
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
    return validationStr;
  }

  void processObject(
    ModelSchema schema,
    ObjectMD objectMD,
    Map<dynamic, dynamic> node,
    String path,
    List requiredFields,
  ) {
    if (node.containsKey('properties')) {
      node['properties'].forEach((key, value) {
        final fullPath = path.isEmpty ? key : '$path.$key';
        final isRequired = requiredFields.contains(key) ? '✅ Yes' : '❌ No';
        processAttr(schema, objectMD, value, fullPath, isRequired);
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

class ObjectMD {
  final String jsonPath;
  final String title;
  final StringBuffer md = StringBuffer();
  final List<ObjectMD> children = [];
  Map<dynamic, dynamic> root;
  bool toDisplay = true;

  ObjectMD({required this.jsonPath, required this.title, required this.root});
}
