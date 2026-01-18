import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:highlight/languages/json.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/core/api/call_api_manager.dart';
import 'package:jsonschema/feature/model/pan_model_import_dialog.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';


class PanSaveParam extends StatefulWidget {
  const PanSaveParam(this.api, this.jsonParam, {super.key});
  final dynamic jsonParam;
  final APICallManager api;

  @override
  State<PanSaveParam> createState() => _PanSaveParamState();
}

class _PanSaveParamState extends State<PanSaveParam> {

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double width = size.width * 0.5;
    double height = size.height * 0.8;

    return AlertDialog(
      title: const Text('Save example'),
      content: SizedBox(width: width, height: height, child: getPan()),
      actions: <Widget>[
        TextButton(
          child: const Text('save'),
          onPressed: () {
            bddStorage.addApiParam(
              widget.api.currentAPIRequest!,
              widget.api.selectedExample!.masterID!,
              'test',
              widget.jsonParam,
            );

            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: const Text('close'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  Map<String, String> info = {};

  Widget getPan() {
    var encoder = JsonEncoder.withIndent("  ");
    var text = encoder.convert(widget.jsonParam);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 80,
          width: 600,
          child: Row(
            spacing: 20,
            children: [
              Flexible(
                child: CellEditor(
                  acces: InfoAccess(map: info, name: 'category'),
                  inArray: false,
                ),
              ),
              Flexible(
                child: CellEditor(
                  acces: InfoAccess(map: info, name: 'name'),
                  inArray: false,
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: TextEditor(
            config: CodeEditorConfig(
              readOnly: true,
              mode: json,
              getText: () => text,
              onChange: (String json, CodeEditorConfig config) {
                // Handle changes if needed
              },
              notifError: ValueNotifier(''),
            ),
            header: 'Parameters',
          ),
        ),
      ],
    );
  }
}
