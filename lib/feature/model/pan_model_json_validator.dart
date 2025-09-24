import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:highlight/languages/json.dart' show json;
import 'package:json_schema/json_schema.dart';
import 'package:jsonschema/core/export/export2json_fake.dart';
import 'package:jsonschema/core/export/export2json_schema.dart';
import 'package:jsonschema/feature/model/widget_example_choiser.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/start_core.dart';

class WidgetJsonValidator extends StatefulWidget {
  const WidgetJsonValidator({super.key});

  @override
  State<WidgetJsonValidator> createState() => _WidgetJsonValidatorState();
}

class _WidgetJsonValidatorState extends State<WidgetJsonValidator> {
  late dynamic jsonSchema;
  late CodeEditorConfig textConfig;
  ExampleManager exampleManager = ExampleManager();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(child: getViewer()),
        Flexible(
          child: Column(
            children: [
              SizedBox(
                height: 30,
                child: Row(
                  children: [
                    TextButton.icon(
                      icon: Icon(Icons.casino_outlined),
                      onPressed: () {
                        exampleManager.jsonFake = null;
                        exampleManager.clearSelected();
                        textConfig.repaintCode();
                      },
                      label: Text('Generate fake data'),
                    ),
                    exampleManager,
                  ],
                ),
              ),
              Expanded(child: getEditor()),
            ],
          ),
        ),
      ],
    );
  }

  Widget getViewer() {
    if (currentCompany.currentModel == null) {
      return Text('select model first');
    }
    var export =
        Export2JsonSchema()..browse(currentCompany.currentModel!, false);
    jsonSchema = export.json;
    try {
      jsonValidator = JsonSchema.create(jsonSchema);
      errorParse.value = '';
    } catch (e) {
      errorParse.value = '$e';
    }
    return TextEditor(
      header: "JSON Schema",
      config: CodeEditorConfig(
        mode: json,
        readOnly: true,
        notifError: errorParse,
        onChange: (String json, CodeEditorConfig config) {},
        getText: () {
          return export.prettyPrintJson(export.json);
        },
      ),
    );
  }

  JsonSchema? jsonValidator;
  ValueNotifier<String> error = ValueNotifier('');
  ValueNotifier<String> errorParse = ValueNotifier('');

  Widget getEditor() {
    if (currentCompany.currentModel == null) {
      return Text('select model first');
    }

    textConfig = CodeEditorConfig(
      mode: json,
      notifError: error,
      onChange: (String json, CodeEditorConfig config) {
        try {
          if (json != '' && jsonValidator != null) {
            var jsonMap = jsonDecode(removeComments(json));
            validateJsonSchemas(jsonValidator!, jsonMap, config.notifError);
            exampleManager.jsonFake = json;
            // ValidationResults r = jsonValidator!.validate(jsonMap);
            // // print("r= $r");
            // if (r.isValid) {
            //   config.notifError.value = '_VALID_';
            // } else {
            //   config.notifError.value = r.toString();
            // }
          } else {
            config.notifError.value = '';
            exampleManager.jsonFake = json;
          }
        } catch (e) {
          config.notifError.value = '$e';
        }
      },
      getText: () {
        if (exampleManager.jsonFake == null) {
          var export = Export2FakeJson(
            modeArray: ModeArrayEnum.anyInstance,
            mode: ModeEnum.fake,
          )..browse(currentCompany.currentModel!, false);
          exampleManager.jsonFake = export.prettyPrintJson(export.json);
        }

        return exampleManager.jsonFake;
      },
    );

    exampleManager.onSelect = () {
      textConfig.repaintCode();
    };

    return TextEditor(header: "JSON example", config: textConfig);
  }
}
