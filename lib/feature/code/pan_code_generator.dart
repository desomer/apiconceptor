import 'package:flutter/material.dart';
import 'package:highlight/languages/typescript.dart';
import 'package:jsonschema/core/export/export2dto_nestjs.dart';
import 'package:jsonschema/core/export/export2json_schema.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';

class PanCodeGenerator extends StatefulWidget {
  const PanCodeGenerator({super.key});

  @override
  State<PanCodeGenerator> createState() => _PanCodeGeneratorState();
}

class _PanCodeGeneratorState extends State<PanCodeGenerator> {
  @override
  Widget build(BuildContext context) {
    return getCodeWidget();
  }

  Widget getCodeWidget() {
    if (currentCompany.currentModel == null) return Container();
    var export =
        Export2JsonSchema()..browse(currentCompany.currentModel!, false);
    String code = Export2DtoNestjs().jsonSchemaToNestDto(export.json);
    return _getCode(code);
  }

  Widget _getCode(String code) {
    return TextEditor(
      config: CodeEditorConfig(
        mode: typescript,
        getText: () {
          return code;
        },
        onChange: (String json, CodeEditorConfig config) {},
        notifError: ValueNotifier(''),
      ),
      header: 'code',
    );
  }
}
