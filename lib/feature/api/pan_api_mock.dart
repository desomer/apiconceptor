import 'dart:convert' show jsonDecode;

import 'package:flutter/material.dart';
import 'package:highlight/languages/json.dart' show json;
import 'package:json_schema/json_schema.dart';
import 'package:jsonschema/core/export/export2json_fake.dart';
import 'package:jsonschema/core/export/export2json_schema.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/repaint_manager.dart';
import 'package:jsonschema/feature/api/api_widget_request_helper.dart';
import 'package:jsonschema/feature/api/pan_api_param.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/widget/widget_split.dart';

class WidgetApiMock extends StatefulWidget {
  const WidgetApiMock({
    super.key,
    required this.requestHelper,
    required this.idApi,
  });
  final WidgetRequestHelper requestHelper;
  final String idApi;

  @override
  State<WidgetApiMock> createState() => WidgetApiMockState();
}

class WidgetApiMockState extends State<WidgetApiMock> {
  CodeEditorConfig? textConfigResponse;
  ValueNotifier<String> errorParseResponse = ValueNotifier('');
  JsonSchema? jsonValidator;

  @override
  initState() {
    super.initState();
  }

  Widget getLeftPan(BuildContext ctx) {
    return PanApiParam(
      config: ApiParamConfig(
        action: null,
        modeSeparator: Separator.right,
        withBtnAddMock: true,
        modeMock: false,
      ),
      requestHelper: widget.requestHelper,
    );
  }

  @override
  Widget build(BuildContext context) {
    repaintManager.addTag(ChangeTag.apiparam, "WidgetApiMockState", this, () {
      // Future.delayed(Duration(milliseconds: 500)).then((_) {
      //   textConfigBody!.repaintYaml();
      //   keyBtnSave.currentState?.setState(() {});
      // });

      GoTo()
          .getApiRequestModel(
            widget.requestHelper.apiCallInfo,
            currentCompany.listAPI!.namespace!,
            widget.idApi,
            withDelay: false,
          )
          .then((value) {
            widget.requestHelper.apiCallInfo.currentAPIRequest = value;
          });

      GoTo()
          .getApiResponseModel(
            widget.requestHelper.apiCallInfo,
            currentCompany.listAPI!.namespace!,
            widget.idApi,
            withDelay: false,
          )
          .then((value) {
            widget.requestHelper.apiCallInfo.currentAPIResponse = value;
          });

      return false;
    });

    return SplitView(
      primaryWidth: -1,
      children: [getLeftPan(context), getResponseEditor()],
    );
  }

  Widget getResponseEditor() {
    textConfigResponse = CodeEditorConfig(
      // mode: graphql,
      mode: json,
      notifError: errorParseResponse,
      onChange: (String json, CodeEditorConfig config) {
        widget.requestHelper.apiCallInfo.mock = null;
        widget.requestHelper.apiCallInfo.mockStr = json;

        try {
          if (json != '') {
            widget.requestHelper.apiCallInfo.mock = jsonDecode(
              removeComments(json),
            );
          }
          if (jsonValidator != null &&
              widget.requestHelper.apiCallInfo.mock != null) {
            validateJsonSchemas(
              jsonValidator!,
              widget.requestHelper.apiCallInfo.mock,
              config.notifError,
            );
          } else {
            config.notifError.value = '';
          }
        } catch (e) {
          config.notifError.value = '$e';
        }
      },
      getText: () {
        return widget.requestHelper.apiCallInfo.mockStr;
      },
    );

    return TextEditor(
      header: "Mock response body",
      actions: [
        TextButton(
          onPressed: () async {
            widget.requestHelper.apiCallInfo.currentAPIResponse!.validateSchema(
              subNode: 200,
              validateFct: (ModelSchema aSchema) {
                initMockValidator(aSchema);
                var export = Export2FakeJson(
                  modeArray: ModeArrayEnum.anyInstance,
                  mode: ModeEnum.fake,
                )..browse(aSchema, false);
                widget.requestHelper.apiCallInfo.mock = export.json;
                widget.requestHelper.apiCallInfo.mockStr = export
                    .prettyPrintJson(export.json);
                textConfigResponse!.repaintCode();
              },
            );
          },
          child: Text('load fake'),
        ),
      ],
      config: textConfigResponse!,
    );
  }

  Future<void> initMockValidator(ModelSchema aSchema) async {
    var export = Export2JsonSchema();
    await export.browseSync(aSchema, false, 0);
    try {
      if ((export.json['properties'] as Map).isNotEmpty) {
        jsonValidator = JsonSchema.create(export.json);
      }
      errorParseResponse.value = '';
    } catch (e) {
      errorParseResponse.value = '$e';
    }
  }
}
