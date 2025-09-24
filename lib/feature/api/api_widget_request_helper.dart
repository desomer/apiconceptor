import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:highlight/languages/json.dart' show json;
import 'package:json_schema/json_schema.dart';
import 'package:jsonschema/core/api/caller_api.dart';
import 'package:jsonschema/core/export/export2json_schema.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/api/call_manager.dart';
import 'package:jsonschema/feature/api/pan_api_doc_response.dart';
import 'package:jsonschema/feature/api/pan_api_response_status.dart';
import 'package:jsonschema/feature/api/widget_url.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/widget/widget_choise_env.dart';
import 'package:jsonschema/widget/widget_float_dialog.dart';
import 'package:jsonschema/widget/widget_glowing_halo.dart';
import 'package:jsonschema/widget/widget_keyvalue.dart';
import 'package:jsonschema/widget/widget_logger.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget/widget_overflow.dart';
import 'package:jsonschema/widget/widget_tab.dart';

class WidgetRequestHelper with WidgetHelper {
  WidgetRequestHelper({required this.apiCallInfo});

  final APICallManager apiCallInfo;

  String response = '';
  CodeEditorConfig? textConfigResponse;
  JsonSchema? jsonValidatorResponse;
  dynamic validateSchemaJson;

  bool callInProgress = false;
  GlobalKey keyResponseStatus = GlobalKey(debugLabel: 'keyResponseStatus');

  ValueNotifier<String> errorParseResponse = ValueNotifier('');
  ValueNotifier<int> changeUrl = ValueNotifier(0);
  ValueNotifier<int> changeResponse = ValueNotifier(0);
  ValueNotifier<int> changeScript = ValueNotifier(0);

  int calcUrl = -1;

  Widget getAPIWidgetPath(BuildContext context, String mode) {
    return ValueListenableBuilder(
      valueListenable: changeUrl,
      builder: (context, value, child) {
        var attr = currentCompany.listAPI!.selectedAttr;

        if (attr != null) {
          //String httpOpe = attr.info.name.toLowerCase();
          apiCallInfo.url = '';
          List<Widget> wpath = [];
          Widget wOpe = getHttpOpe(apiCallInfo.httpOperation) ?? Container();

          wpath.add(wOpe);

          var nd = attr.parent;
          apiCallInfo.urlParamFromNode.clear();

          while (nd != null) {
            var n = nd.info.name; // getKeyParamFromYaml(nd.yamlNode.key);
            if (nd.info.properties?['\$server'] != null) {
              var urlserv = nd.info.properties?['\$server'];

              urlserv = apiCallInfo.replaceVarInRequest(urlserv);
              var hasParam =
                  apiCallInfo.extractParameters(urlserv, true).isNotEmpty;
              if (!hasParam) {
                hasParam =
                    apiCallInfo.extractParameters(urlserv, false).isNotEmpty;
              }
              if (hasParam && calcUrl != changeUrl.value) {
                apiCallInfo.fillVar().then((value) {
                  changeUrl.value++;
                  calcUrl = changeUrl.value;
                });
              }

              apiCallInfo.url = '$urlserv${apiCallInfo.url}';
              wpath.insert(
                1,
                Padding(
                  padding: EdgeInsets.fromLTRB(10, 0, 0, 0),
                  child: Text(urlserv, style: TextStyle(color: Colors.white60)),
                ),
              );
              break;
            }
            var path = _getPathWidgetFormNode(n);

            wpath.insertAll(1, path);
            if (!n.endsWith('/')) {
              apiCallInfo.url = '/${apiCallInfo.url}';
              wpath.insert(1, Text('/'));
            }

            nd = nd.parent;
          }

          wpath.add(WidgetApiParam(apiCallInfo: apiCallInfo));

          wpath.add(
            Padding(
              padding: EdgeInsetsGeometry.symmetric(horizontal: 10),
              child: IconButton.filledTonal(
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(
                      text: apiCallInfo.addParametersOnUrl(apiCallInfo.url),
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('URL copied to clipboard')),
                  );
                },
                icon: Icon(Icons.copy),
              ),
            ),
          );

          return Card(
            elevation: 10,
            child: ListTile(
              leading: Icon(Icons.api),
              title: NoOverflowErrorFlex(
                direction: Axis.horizontal,
                children: wpath,
              ),
              trailing: IntrinsicWidth(child: WidgetChoiseEnv(widgetRequestHelper: this)),
            ),
          );
        } else {
          return Container();
        }
      },
    );
  }

  List<Widget> _getPathWidgetFormNode(String name) {
    List<Widget> wpath = [];
    List<String> path = name.split('/');
    StringBuffer urlStr = StringBuffer();
    int i = 0;
    for (var element in path) {
      bool isLast = i == path.length - 1;
      if (element.startsWith('{')) {
        String v = element.substring(1, element.length - 1);
        wpath.add(getChip(Text(v), color: null));

        apiCallInfo.urlParamFromNode.insert(0, v);

        //urlParamId.insert(0, v);
        urlStr.write(element);
        if (!isLast) {
          wpath.add(Text('/'));
          urlStr.write('/');
        }
      } else {
        if (element != '') {
          wpath.add(
            Text(
              element + (!isLast ? '/' : ''),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          );
          urlStr.write(element + (!isLast ? '/' : ''));
        }
      }
      i++;
    }
    apiCallInfo.url = urlStr.toString() + apiCallInfo.url;
    return wpath;
  }

  //-------------------------------------------------
  Widget getPanResponse(BuildContext ctx) {
    return Column(
      children: [
        SizedBox(
          height: 30,
          child: NoOverflowErrorFlex(
            direction: Axis.horizontal,
            children: [
              PanApiResponseStatus(key: keyResponseStatus, requestHelper: this),
              Spacer(),
              InkWell(
                onTap: () {
                  //print(validateSchemaJson);
                },
                child: Chip(label: Text('Compliant report')),
              ),
            ],
          ),
        ),

        Expanded(
          child: WidgetTab(
            listTab: [
              Tab(text: 'Response'),
              Tab(text: 'Headers'),
              Tab(text: 'Logs'),
            ],
            listTabCont: [
              _getResponseJson(ctx),
              KeyValueTable(
                change: changeResponse,
                fct: () {
                  return apiCallInfo.aResponse?.headers;
                },
              ),
              LogViewer(
                fct: () {
                  return apiCallInfo.logs;
                },
                change: changeResponse,
              ),
            ],
            heightTab: 30,
          ),
        ),
      ],
    );
  }

  //----------------------------------------

  Widget getBtnExecuteCall() {
    return TextButton.icon(
      icon: Icon(Icons.send),
      onPressed: () async {
        await doSend();
      },
      label: GlowingHalo(child: Text('Execute API')),
    );
  }

  Future<void> doSend() async {
    doClearResponse(inProgress: true); // vide la response
    await doExecuteRequest();
    doDisplayResponse();

    changeResponse.value++;

    // sauv en resp car validation async
    APIResponse? responseData = apiCallInfo.aResponse;
    Future.delayed(Duration(milliseconds: 100)).then((value) {
      doValidateResponse(responseData);
    });
  }

  Future<void> doExecuteRequest() async {
    //await CallerApi().callGraph();
    apiCallInfo.logs.add(
      '----------- ${DateTime.now().toIso8601String()} -------------',
    );
    await CallScript().callPreRequest(apiCallInfo);

    final cancelToken = CancelToken();
    apiCallInfo.aResponse = await CallerApi().call(apiCallInfo, cancelToken);
  }

  void doClearResponse({required bool inProgress}) {
    response = '';

    apiCallInfo.aResponse = null;
    callInProgress = inProgress;
    errorParseResponse.value = '';
    jsonValidatorResponse = null;
    // ignore: invalid_use_of_protected_member
    keyResponseStatus.currentState?.setState(() {});
    textConfigResponse!.repaintCode(); // vide la response
  }

  void doDisplayResponse() {
    callInProgress = false;
    // ignore: invalid_use_of_protected_member
    keyResponseStatus.currentState?.setState(() {});

    if (apiCallInfo.aResponse!.toDisplayError == null &&
        apiCallInfo.aResponse!.reponse?.data is String) {
      response = apiCallInfo.aResponse!.reponse!.data.toString();
    } else {
      var encoder = JsonEncoder.withIndent("  ");
      response = encoder.convert(
        apiCallInfo.aResponse!.toDisplayError ??
            apiCallInfo.aResponse!.reponse?.data ??
            {},
      );
    }
    textConfigResponse!.repaintCode();
  }

  void doValidateResponse(APIResponse? resp) {
    if (apiCallInfo.aResponse?.reponse?.statusCode != null) {
      int code = apiCallInfo.aResponse!.reponse!.statusCode!;
      apiCallInfo.currentAPIResponse!.validateSchema(
        subNode: code,
        validateFct: (ModelSchema aSchema) async {
          apiCallInfo.responseSchema = aSchema;
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

  Widget _getResponseJson(BuildContext ctx) {
    textConfigResponse = CodeEditorConfig(
      mode: json,
      notifError: errorParseResponse,
      readOnly: true,
      onChange: (String json, CodeEditorConfig config) {},
      getText: () {
        return response;
      },
    );

    return TextEditor(
      header: "Response",
      config: textConfigResponse!,
      actions: [
        TextButton(
          onPressed: () {
            var w = PanApiDocResponse(
              key: ObjectKey(apiCallInfo),
              showable: () {
                return apiCallInfo.responseSchema != null;
              },
              getSchemaFct: () async {
                return apiCallInfo.responseSchema!;
              },
            );

            Size size = MediaQuery.of(ctx).size;
            double width = size.width * 0.4;
            double height = size.height * 0.8;

            showFloatingNotification(
              ctx,
              Offset(50, 100),
              Size(width, height),
              w,
            );
          },
          child: Text('Show Doc.'),
        ),
      ],
    );
  }
}
