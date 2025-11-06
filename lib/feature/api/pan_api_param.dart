import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:highlight/languages/json.dart' show json;
import 'package:json_schema/json_schema.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/core/export/export2json_fake.dart';
import 'package:jsonschema/core/export/export2json_schema.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/repaint_manager.dart';
import 'package:jsonschema/core/api/call_manager.dart';
import 'package:jsonschema/feature/api/api_widget_request_helper.dart';
import 'package:jsonschema/feature/api/pan_api_param_array.dart';
import 'package:jsonschema/feature/api/pan_api_save_param.dart';
import 'package:jsonschema/feature/api/pan_api_script.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/widget/widget_keyvalue.dart';
import 'package:jsonschema/widget/widget_tab.dart';
import 'package:jsonschema/widget/widget_vertical_sep.dart';
import 'package:jsonschema/widget/widget_overflow.dart';

enum Separator { none, left, right }

class ApiParamConfig {
  final Separator modeSeparator;
  final bool withBtnAddMock;
  final bool modeMock;
  final Widget? action;

  ApiParamConfig({
    required this.action,
    required this.modeSeparator,
    required this.withBtnAddMock,
    required this.modeMock,
  });
}

class PanApiParam extends StatefulWidget {
  const PanApiParam({
    super.key,
    required this.requestHelper,
    required this.config,
  });

  final WidgetRequestHelper requestHelper;
  final ApiParamConfig config;

  @override
  State<PanApiParam> createState() => _PanApiParamState();
}

class _PanApiParamState extends State<PanApiParam> {
  CodeEditorConfig? textConfigBody;
  JsonSchema? jsonValidator;

  GlobalKey keyResquestParam = GlobalKey(debugLabel: 'keyResquestParam');
  GlobalKey keyBtnSave = GlobalKey(debugLabel: 'keyBtnSave');

  @override
  Widget build(BuildContext context) {
    repaintManager.addTag(ChangeTag.apiparam, "_PanApiParamState", this, () {
      // Future.delayed(Duration(milliseconds: 100)).then((_) {
      textConfigBody!.repaintCode();
      if (keyBtnSave.currentState?.mounted ?? false) {
        keyBtnSave.currentState?.setState(() {});
      }
      //});

      return false;
    });

    return getContent(context);
  }

  // Widget getBtnMockCall() {
  //   return TextButton.icon(
  //     icon: Icon(Icons.text_snippet),
  //     onPressed: () async {},
  //     label: Text('Add mock'),
  //   );
  // }

  Widget getBtnScript(BuildContext context) {
    return TextButton.icon(
      icon: Icon(Icons.code),
      onPressed: () async {
        await showScriptDialog(context);
        widget.requestHelper.changeScript.value++;
      },
      label: ValueListenableBuilder(
        valueListenable: widget.requestHelper.changeScript,
        builder: (context, value, child) {
          bool hasScript =
              widget.requestHelper.apiCallInfo.postResponseStr.isNotEmpty ||
              widget.requestHelper.apiCallInfo.preRequestStr.isNotEmpty;
          return hasScript
              ? Badge(
                backgroundColor: Colors.blue,
                offset: Offset(10, -5),
                label: Text('1'),
                padding: EdgeInsets.all(0),
                child: Text('Script & Variables'),
              )
              : Text('Script & Variables');
        },
      ),
    );
  }

  Future<void> showScriptDialog(BuildContext ctx) async {
    widget.requestHelper.apiCallInfo.initUsedVariables();

    return showDialog<void>(
      context: ctx,
      barrierDismissible: true, // user must tap button!
      builder: (BuildContext context) {
        Size size = MediaQuery.of(ctx).size;
        double width = size.width * 0.9;
        double height = size.height * 0.8;
        return AlertDialog(
          content: SizedBox(
            width: width,
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 300,
                  child: KeyValueTable(
                    fct: () {
                      return widget.requestHelper.apiCallInfo.variablesId
                          .map((e) => {'key': e, 'value': ''})
                          .toList();
                    },
                    change: ValueNotifier<int>(0),
                  ),
                ),
                Expanded(
                  child: WidgetTab(
                    listTab: [
                      Tab(text: 'Pre request'),
                      Tab(text: 'Post response'),
                    ],
                    listTabCont: [
                      PanApiScript(
                        api: widget.requestHelper.apiCallInfo,
                        type: ScriptType.pre,
                      ),
                      PanApiScript(
                        api: widget.requestHelper.apiCallInfo,
                        type: ScriptType.post,
                      ),
                    ],
                    heightTab: 40,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
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

  Widget getBody() {
    textConfigBody = CodeEditorConfig(
      // mode: graphql,
      mode: json,
      notifError: errorParseBody,
      onChange: (String json, CodeEditorConfig config) {
        widget.requestHelper.apiCallInfo.body = null;
        widget.requestHelper.apiCallInfo.bodyStr = json;
        try {
          if (json != '') {
            widget.requestHelper.apiCallInfo.body = jsonDecode(
              removeComments(json),
            );
          }
          if (jsonValidator != null &&
              widget.requestHelper.apiCallInfo.body != null) {
            validateJsonSchemas(
              jsonValidator!,
              widget.requestHelper.apiCallInfo.body,
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
        return widget.requestHelper.apiCallInfo.bodyStr;
      },
    );

    return TextEditor(
      header: "Request body",
      actions: [
        TextButton(
          onPressed: () {
            ModelSchema? aSchema = widget
                .requestHelper
                .apiCallInfo
                .currentAPIRequest!
                .validateSchema(
                  subNode: 'body',
                  validateFct: (ModelSchema aSchema) {
                    initBodyValidator(aSchema);
                  },
                );

            if (aSchema != null) {
              var export = Export2FakeJson(
                modeArray: ModeArrayEnum.anyInstance,
                mode: ModeEnum.fake,
              )..browse(aSchema, false);
              widget.requestHelper.apiCallInfo.body = export.json;
              widget.requestHelper.apiCallInfo.bodyStr = export.prettyPrintJson(
                export.json,
              );
              textConfigBody!.repaintCode();
            }
          },
          child: Text('load fake'),
        ),
      ],
      config: textConfigBody!,
    );
  }

  Widget getContent(BuildContext ctx) {
    return Row(
      children: [
        if (widget.config.modeSeparator == Separator.left) VerticalSep(),
        Flexible(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                children: [
                  SizedBox(
                    height: 40,
                    child: NoOverflowErrorFlex(
                      direction: Axis.horizontal,
                      children: [
                        BtnApiSave(
                          key: keyBtnSave,
                          apiCallInfo: widget.requestHelper.apiCallInfo,
                        ),
                        Spacer(),
                        getBtnScript(context),
                        //if (widget.config.withBtnAddMock) getBtnMockCall(),
                        if (widget.config.action != null) widget.config.action!,
                      ],
                    ),
                  ),
                  WidgetArrayParam(
                    config: widget.config,
                    constraints: constraints,
                    key: keyResquestParam,
                    requestHelper: widget.requestHelper,
                  ),
                  Flexible(child: getBody()),
                ],
              );
            },
          ),
        ),
        if (widget.config.modeSeparator == Separator.right) VerticalSep(),
      ],
    );
  }

  //TODO a faire marché
  Future<void> showSaveParamDialog(dynamic json, BuildContext ctx) async {
    return showDialog<void>(
      context: ctx,
      barrierDismissible: true, // user must tap button!
      builder: (BuildContext context) {
        return PanSaveParam(widget.requestHelper.apiCallInfo, json);
      },
    );
  }
}

//-----------------------------------------------------------------------
class BtnApiSave extends StatefulWidget {
  const BtnApiSave({super.key, required this.apiCallInfo});
  final APICallManager apiCallInfo;

  @override
  State<BtnApiSave> createState() => _BtnApiSaveState();
}

class _BtnApiSaveState extends State<BtnApiSave> {
  bool isEditable() {
    return widget.apiCallInfo.selectedExample != null;
  }

  @override
  Widget build(BuildContext context) {
    String name = widget.apiCallInfo.selectedExample?.name ?? '';
    return TextButton.icon(
      icon: Icon(Icons.save_alt_rounded),
      onPressed:
          isEditable()
              ? () async {
                var jsonParam = widget.apiCallInfo.toParamJson();
                bddStorage.addApiParam(
                  widget.apiCallInfo.currentAPIRequest!,
                  widget.apiCallInfo.selectedExample!.masterID!,
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
