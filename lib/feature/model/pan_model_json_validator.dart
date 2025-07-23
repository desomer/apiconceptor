import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:highlight/languages/json.dart' show json;
import 'package:json_schema/json_schema.dart';
import 'package:jsonschema/core/export/export2json_fake.dart';
import 'package:jsonschema/core/export/export2json_schema.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/main.dart';

class WidgetJsonValidator extends StatefulWidget {
  const WidgetJsonValidator({super.key});

  @override
  State<WidgetJsonValidator> createState() => _WidgetJsonValidatorState();
}

class _WidgetJsonValidatorState extends State<WidgetJsonValidator> {
  late dynamic jsonSchema;
  late TextConfig textConfig;

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
                    TextButton(
                      onPressed: () {
                        textConfig.doRebind();
                      },
                      child: Text('Generate fake data'),
                    ),
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
      config: TextConfig(
        mode: json,
        readOnly: true,
        notifError: errorParse,
        onChange: (String json, TextConfig config) {},
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

    textConfig = TextConfig(
      mode: json,
      notifError: error,
      onChange: (String json, TextConfig config) {
        try {
          if (json != '' && jsonValidator != null) {
            var jsonMap = jsonDecode(removeComments(json));
            validateJsonSchemas(jsonValidator!, jsonMap, config.notifError);
            // ValidationResults r = jsonValidator!.validate(jsonMap);
            // // print("r= $r");
            // if (r.isValid) {
            //   config.notifError.value = '_VALID_';
            // } else {
            //   config.notifError.value = r.toString();
            // }
          } else {
            config.notifError.value = '';
          }
        } catch (e) {
          config.notifError.value = '$e';
        }
      },
      getText: () {
        var export =
            Export2FakeJson()..browse(currentCompany.currentModel!, false);
        var json = export.prettyPrintJson(export.json);

        return json;
      },
    );

    return TextEditor(header: "JSON example", config: textConfig);
  }
}
