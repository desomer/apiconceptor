import 'dart:convert' as codec;

import 'package:flutter/material.dart';
import 'package:highlight/languages/json.dart' show json;
import 'package:json_schema/json_schema.dart';
import 'package:jsonschema/export/export2json.dart';
import 'package:jsonschema/export/export2json_schema.dart';
import 'package:jsonschema/editor/text_editor.dart';
import 'package:jsonschema/main.dart';

class WidgetJsonValidator extends StatefulWidget {
  const WidgetJsonValidator({super.key});

  @override
  State<WidgetJsonValidator> createState() => _WidgetJsonValidatorState();
}



class _WidgetJsonValidatorState extends State<WidgetJsonValidator> {

  late dynamic jsonSchema;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [Flexible(child: getViewer()), Flexible(child: getEditor())],
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
      errorParse.value='';
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

  late JsonSchema jsonValidator;
  ValueNotifier<String> error = ValueNotifier('');
  ValueNotifier<String> errorParse = ValueNotifier('');

  Widget getEditor() {
    if (currentCompany.currentModel == null) {
      return Text('select model first');
    }

    return TextEditor(
      header: "JSON example", 
      config: TextConfig(
        mode: json,
        notifError: error,
        onChange: (String json, TextConfig config) {
          try {
            var jsonMap = codec.jsonDecode(json);
            ValidationResults r = jsonValidator.validate(jsonMap);
            // print("r= $r");
            if (r.isValid) {
              config.notifError.value = '_VALID_';
            } else {
              config.notifError.value = r.toString();
            }
          } catch (e) {
            config.notifError.value = '$e';
          }
        },
        getText: () {
          var export =
              Export2Json()..browse(currentCompany.currentModel!, false);
          var json = export.prettyPrintJson(export.json);

          return json;
        },
      ),
    );
  }
}
