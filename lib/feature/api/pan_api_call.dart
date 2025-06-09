import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:highlight/languages/json.dart' show json;
import 'package:json_schema/json_schema.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/core/caller_api.dart';
import 'package:jsonschema/editor/code_editor.dart';
import 'package:jsonschema/export/export2json.dart';
import 'package:jsonschema/export/export2json_schema.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/feature/api/pan_api_editor.dart';
import 'package:jsonschema/feature/api/pan_api_param_array.dart';

import '../../widget_state/widget_md_doc.dart';

class WidgetApiCall extends StatefulWidget {
  const WidgetApiCall({super.key, required this.apiCallInfo});
  final APICallInfo apiCallInfo;

  @override
  State<WidgetApiCall> createState() => _WidgetApiCallState();
}

class _WidgetApiCallState extends State<WidgetApiCall> {
  dynamic responseJson = '';
  String response = '';
  late TextConfig textConfig;
  JsonSchema? jsonValidator;

  Widget getBtnExecuteCall() {
    return TextButton.icon(
      icon: Icon(Icons.send),
      onPressed: () async {
        response = '';
        textConfig.doRebind();

        //await CallerApi().callGraph();
        responseJson = await CallerApi().call(widget.apiCallInfo) ?? '';
        var encoder = JsonEncoder.withIndent("  ");
        response = encoder.convert(responseJson);
        textConfig.doRebind();
      },
      label: Text('Execute API'),
    );
  }

  Widget getBtnSave() {
    return TextButton.icon(
      icon: Icon(Icons.save_alt_rounded),
      onPressed: () async {},
      label: Text('Save example'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Column(
            children: [
              SizedBox(height: 40, child: Row(children: [getBtnSave()])),
              WidgetArray(apiCallInfo: widget.apiCallInfo),
              Flexible(child: getBody()),
            ],
          ),
        ),
        Container(
          width: 10,
          height: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(width: 1, color: Colors.white),
          ),
        ),
        Flexible(
          child: Column(
            children: [
              SizedBox(
                height: 40,
                child: Row(
                  children: [
                    getBtnExecuteCall(),
                    Spacer(),
                    Chip(label: Text('Compliant')),
                  ],
                ),
              ),
              Expanded(child: getResponse()),
            ],
          ),
        ),
      ],
    );
  }

  ValueNotifier<String> errorParse = ValueNotifier('');

  Widget getBody() {
    ModelSchemaDetail? aSchema;

    var mapModelYaml = widget.apiCallInfo.currentAPI!.mapModelYaml['body'];
    if (mapModelYaml != null) {
      if (mapModelYaml is String) {
        if (mapModelYaml.startsWith('\$')) {
          var refName = mapModelYaml.substring(1);
          var listModel = currentCompany.listComponent.mapInfoByName[refName];
          listModel ??= currentCompany.listModel.mapInfoByName[refName];

          if (listModel != null) {
            String masterIdRef = listModel.first.properties?[constMasterID];
            aSchema = ModelSchemaDetail(
              type: YamlType.model,
              name: refName,
              id: masterIdRef,
              infoManager: InfoManagerModel(typeMD: TypeMD.model),
            );

            aSchema.loadYamlAndProperties(cache: false).then((value) {
              initBodyValidator(aSchema!);
            });
          }
        }
      } else {
        aSchema = ModelSchemaDetail(
          id: '?',
          type: YamlType.model,
          name: '',
          infoManager: InfoManagerModel(typeMD: TypeMD.model),
        )..autoSave = false;

        aSchema.loadSubSchema('body', widget.apiCallInfo.currentAPI!);
        initBodyValidator(aSchema);
      }
    }


    var textConfig = TextConfig(
      // mode: graphql,
      mode: json,
      notifError: errorParse,
      onChange: (String json, TextConfig config) {
        widget.apiCallInfo.body = null;
        widget.apiCallInfo.bodyStr = json;
        try {
          if (json != '') {
            widget.apiCallInfo.body = jsonDecode(json);
          }
          if (jsonValidator != null && widget.apiCallInfo.body != null) {
            widget.apiCallInfo.body = widget.apiCallInfo.body;
            ValidationResults r = jsonValidator!.validate(
              widget.apiCallInfo.body,
            );
            // print("r= $r");
            if (r.isValid) {
              config.notifError.value = '_VALID_';
            } else {
              config.notifError.value = r.toString();
            }
          } else {
            config.notifError.value = '';
          }
        } catch (e) {
          config.notifError.value = '$e';
        }
      },
      getText: () {
        return widget.apiCallInfo.bodyStr;
      },
    );

    return TextEditor(
      header: "Request body",
      actions: [
        TextButton(
          onPressed: () {
            if (aSchema != null) {
              var export = Export2Json()..browse(aSchema, false);
              widget.apiCallInfo.body = export.json;
              widget.apiCallInfo.bodyStr = export.prettyPrintJson(export.json);
              textConfig.doRebind();
            }
          },
          child: Text('load fake'),
        ),
      ],
      config: textConfig,
    );
  }

  void initBodyValidator(ModelSchemaDetail aSchema) {
    var export = Export2JsonSchema()..browse(aSchema, false);
    try {
      if ((export.json['properties'] as Map).isNotEmpty) {
        jsonValidator = JsonSchema.create(export.json);
      }
      errorParse.value = '';
    } catch (e) {
      errorParse.value = '$e';
    }
  }

  ValueNotifier<String> error = ValueNotifier('');

  Widget getResponse() {
    textConfig = TextConfig(
      mode: json,
      notifError: error,
      readOnly: true,
      onChange: (String json, TextConfig config) {},
      getText: () {
        return response;
      },
    );

    return TextEditor(header: "Response", config: textConfig);
  }
}
