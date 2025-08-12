import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:highlight/languages/json.dart' show json;
import 'package:json_schema/json_schema.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/core/caller_api.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/repaint_manager.dart';
import 'package:jsonschema/feature/api/pan_api_doc_response.dart';
import 'package:jsonschema/feature/api/pan_api_save_param.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/core/export/export2json_fake.dart';
import 'package:jsonschema/core/export/export2json_schema.dart';
import 'package:jsonschema/feature/api/pan_api_response_status.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/feature/api/pan_api_editor.dart';
import 'package:jsonschema/feature/api/pan_api_param_array.dart';
import 'package:jsonschema/widget/widget_glowing_halo.dart';
import 'package:jsonschema/widget/widget_split.dart';
import 'package:jsonschema/widget/widget_tab.dart';
import 'package:jsonschema/widget_state/state_api.dart';

import '../../widget/widget_md_doc.dart';

GlobalKey keyResquestParam = GlobalKey();
GlobalKey keyBtnSave = GlobalKey();

class WidgetApiCall extends StatefulWidget {
  const WidgetApiCall({super.key, required this.apiCallInfo});
  final APICallInfo apiCallInfo;

  @override
  State<WidgetApiCall> createState() => WidgetApiCallState();
}

class WidgetApiCallState extends State<WidgetApiCall> {
  String response = '';
  late YamlEditorConfig textConfigBody;
  late YamlEditorConfig textConfigResponse;
  JsonSchema? jsonValidator;
  JsonSchema? jsonValidatorResponse;

  dynamic validateSchemaJson;

  bool callInProgress = false;

  Widget getBtnMockCall() {
    return TextButton.icon(
      icon: Icon(Icons.text_snippet),
      onPressed: () async {},
      label: Text('Add mock'),
    );
  }

  Widget getBtnExecuteCall() {
    return TextButton.icon(
      icon: Icon(Icons.send),
      onPressed: () async {
        response = '';

        widget.apiCallInfo.aResponse = null;
        callInProgress = true;
        errorParseResponse.value = '';
        jsonValidatorResponse = null;
        stateApi.keyResponseStatus.currentState?.setState(() {});
        textConfigResponse.repaintYaml(); // vide la responce
        final cancelToken = CancelToken();
        //await CallerApi().callGraph();
        // await Future.delayed(Duration(seconds: 3));
        widget.apiCallInfo.aResponse = await CallerApi().call(
          widget.apiCallInfo,
          cancelToken,
        );
        callInProgress = false;
        stateApi.keyResponseStatus.currentState?.setState(() {});

        if (widget.apiCallInfo.aResponse!.toDisplay == null &&
            widget.apiCallInfo.aResponse!.reponse?.data is String) {
          response = widget.apiCallInfo.aResponse!.reponse!.data.toString();
        } else {
          var encoder = JsonEncoder.withIndent("  ");
          response = encoder.convert(
            widget.apiCallInfo.aResponse!.toDisplay ??
                widget.apiCallInfo.aResponse!.reponse?.data ??
                {},
          );
        }

        textConfigResponse.repaintYaml();

        if (widget.apiCallInfo.aResponse?.reponse?.statusCode != null) {
          int code = widget.apiCallInfo.aResponse!.reponse!.statusCode!;
          var resp =
              widget.apiCallInfo.aResponse; // sauv en resp car validation async
          validateSchema(
            source: widget.apiCallInfo.currentAPIResponse!,
            subNode: code,
            validateFct: (ModelSchema aSchema) async {
              widget.apiCallInfo.responseSchema = aSchema;
              await initResponseValidator(aSchema);
              if (jsonValidatorResponse != null) {
                validateJsonSchemas(
                  jsonValidatorResponse!,
                  resp!.reponse?.data,
                  errorParseResponse,
                );
              }
            },
          );
        }
      },
      label: GlowingHalo(child: Text('Execute API')),
    );
  }

  Future<void> showSaveParamDialog(dynamic json, BuildContext ctx) async {
    return showDialog<void>(
      context: ctx,
      barrierDismissible: true, // user must tap button!
      builder: (BuildContext context) {
        return PanSaveParam(widget.apiCallInfo, json);
      },
    );
  }

  Widget getLeftPan(BuildContext ctx) {
    return WidgetTab(
      listTab: [Tab(text: 'Parameters'), Tab(text: 'Response documentation')],
      listTabCont: [getLeftParamPan(ctx), getLeftDocParamPan(ctx)],
      heightTab: 40,
    );
  }

  Widget getLeftDocParamPan(BuildContext ctx) {
    return PanApiDocResponse(
      key: ValueKey(currentCompany.apiCallInfo),
      showable: () {
        return widget.apiCallInfo.responseSchema != null;
      },
      getSchemaFct: () async {
        return widget.apiCallInfo.responseSchema!;
      },
    );
  }

  Widget getLeftParamPan(BuildContext ctx) {
    return Row(
      children: [
        Flexible(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                children: [
                  SizedBox(
                    height: 40,
                    child: Row(
                      children: [
                        BtnApiSave(
                          key: keyBtnSave,
                          apiCallInfo: widget.apiCallInfo,
                        ),
                        Spacer(),
                        getBtnMockCall(),
                        getBtnExecuteCall(),
                      ],
                    ),
                  ),
                  WidgetArrayParam(
                    constraints: constraints,
                    key: keyResquestParam,
                    apiCallInfo: widget.apiCallInfo,
                  ),
                  Flexible(child: getBody()),
                ],
              );
            },
          ),
        ),
        Container(
          width: 5,
          height: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(width: 1, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget getRightPan() {
    return Column(
      children: [
        SizedBox(
          height: 40,
          child: Row(
            children: [
              PanApiResponseStatus(
                key: stateApi.keyResponseStatus,
                stateResponse: this,
              ),
              Spacer(),
              InkWell(
                onTap: () {
                  print(validateSchemaJson);
                },
                child: Chip(label: Text('Compliant report')),
              ),
            ],
          ),
        ),
        Expanded(child: getResponse()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    repaintManager.addTag(ChangeTag.apiparam, "WidgetApiCallState", this, () {
      textConfigBody.repaintYaml();
      keyBtnSave.currentState?.setState(() {});
      return false;
    });

    return SplitView(
      primaryWidth: -1,
      children: [getLeftPan(context), getRightPan()],
    );
  }

  ValueNotifier<String> errorParseBody = ValueNotifier('');

  Future<void> initBodyValidator(ModelSchema aSchema) async {
    var export = Export2JsonSchema();
    await export.browseSync(aSchema, false, 0);
    try {
      if ((export.json['properties'] as Map).isNotEmpty) {
        jsonValidator = JsonSchema.create(export.json);
      }
      errorParseBody.value = '';
    } catch (e) {
      errorParseBody.value = '$e';
    }
  }

  ModelSchema? validateSchema({
    required ModelSchema source,
    required dynamic subNode,
    required Function validateFct,
  }) {
    ModelSchema? aSchema;
    var mapModelYaml = source.mapModelYaml[subNode];
    if (mapModelYaml != null) {
      if (mapModelYaml is String) {
        if (mapModelYaml.startsWith('\$')) {
          var refName = mapModelYaml.substring(1);
          var aModelByName = source.getModelByRefName(refName);

          if (aModelByName != null) {
            String masterIdRef = aModelByName.first.properties?[constMasterID];
            aSchema = ModelSchema(
              category: Category.model,
              headerName: refName,
              id: masterIdRef,
              infoManager: InfoManagerModel(typeMD: TypeMD.model),
            );
            aSchema.autoSaveProperties = false;
            aSchema
                .loadYamlAndProperties(cache: false, withProperties: true)
                .then((value) {
                  validateFct(aSchema!);
                });
          }
        }
      } else {
        aSchema = ModelSchema(
          id: '?',
          category: Category.model,
          headerName: '',
          infoManager: InfoManagerModel(typeMD: TypeMD.model),
        )..autoSaveProperties = false;

        aSchema.loadSubSchema(subNode, source);
        validateFct(aSchema);
      }
    }
    return aSchema;
  }

  Widget getBody() {
    ModelSchema? aSchema = validateSchema(
      source: widget.apiCallInfo.currentAPI!,
      subNode: 'body',
      validateFct: (ModelSchema aSchema) {
        initBodyValidator(aSchema);
      },
    );

    textConfigBody = YamlEditorConfig(
      // mode: graphql,
      mode: json,
      notifError: errorParseBody,
      onChange: (String json, YamlEditorConfig config) {
        widget.apiCallInfo.body = null;
        widget.apiCallInfo.bodyStr = json;
        try {
          if (json != '') {
            widget.apiCallInfo.body = jsonDecode(removeComments(json));
          }
          if (jsonValidator != null && widget.apiCallInfo.body != null) {
            validateJsonSchemas(
              jsonValidator!,
              widget.apiCallInfo.body,
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
        return widget.apiCallInfo.bodyStr;
      },
    );

    return TextEditor(
      header: "Request body",
      actions: [
        TextButton(
          onPressed: () {
            if (aSchema != null) {
              var export = Export2FakeJson()..browse(aSchema, false);
              widget.apiCallInfo.body = export.json;
              widget.apiCallInfo.bodyStr = export.prettyPrintJson(export.json);
              textConfigBody.repaintYaml();
            }
          },
          child: Text('load fake'),
        ),
      ],
      config: textConfigBody,
    );
  }

  Future<void> initResponseValidator(ModelSchema aSchema) async {
    var export = Export2JsonSchema();
    await export.browseSync(aSchema, false, 0);
    try {
      if ((export.json['properties'] as Map).isNotEmpty) {
        validateSchemaJson = export.json;
        jsonValidatorResponse = JsonSchema.create(validateSchemaJson);
      }
      errorParseResponse.value = '';
    } catch (e) {
      errorParseResponse.value = '$e';
    }
  }

  ValueNotifier<String> errorParseResponse = ValueNotifier('');

  Widget getResponse() {
    textConfigResponse = YamlEditorConfig(
      mode: json,
      notifError: errorParseResponse,
      readOnly: true,
      onChange: (String json, YamlEditorConfig config) {},
      getText: () {
        return response;
      },
    );

    return TextEditor(header: "Response", config: textConfigResponse);
  }
}

class BtnApiSave extends StatefulWidget {
  const BtnApiSave({super.key, required this.apiCallInfo});
  final APICallInfo apiCallInfo;

  @override
  State<BtnApiSave> createState() => _BtnApiSaveState();
}

class _BtnApiSaveState extends State<BtnApiSave> {
  bool isEditable() {
    return widget.apiCallInfo.selectedExample != null;
  }

  @override
  Widget build(BuildContext context) {
    String name = widget.apiCallInfo.selectedExample?.info.name ?? '';
    return TextButton.icon(
      icon: Icon(Icons.save_alt_rounded),
      onPressed:
          isEditable()
              ? () async {
                var jsonParam = widget.apiCallInfo.toJson();
                bddStorage.addApiParam(
                  widget.apiCallInfo.currentAPI!,
                  widget.apiCallInfo.selectedExample!.info.masterID!,
                  'test',
                  jsonParam,
                );

                //showSaveParamDialog(jsonParam, ctx);
                //widget.apiCallInfo.initWithJson(jsonParam);
              }
              : null,
      label: Text('Save example $name'),
    );
  }
}
