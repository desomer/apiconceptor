import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/core/api/call_manager.dart';
import 'package:jsonschema/core/api/caller_api.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/core/export/export2json_fake.dart';
import 'package:jsonschema/core/export/export2ui.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/api/api_widget_request_helper.dart';
import 'package:jsonschema/feature/api/pan_api_example.dart';
import 'package:jsonschema/feature/content/browser_pan.dart';
import 'package:jsonschema/feature/content/json_to_ui.dart';
import 'package:jsonschema/feature/content/pan_to_ui.dart';
import 'package:jsonschema/feature/content/state_manager.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_logger.dart';

class PanResponseViewer extends StatefulWidget {
  const PanResponseViewer({
    super.key,
    required this.apiCallInfo,
    this.requestHelper,
    this.modeLegacy = true,
  });

  final APICallManager apiCallInfo;
  final WidgetRequestHelper? requestHelper;
  final bool modeLegacy;

  @override
  State<PanResponseViewer> createState() => _PanResponseViewerState();
}

class _PanResponseViewerState extends State<PanResponseViewer> {
  late GenericToUi json2uiCriteria;
  late GenericToUi json2ui;

  @override
  void initState() {
    if (widget.modeLegacy) {
      json2ui = JsonToUi(state: this);
      json2uiCriteria = JsonToUi(state: this);
    } else {
      json2ui = PanToUi(state: this);
      json2uiCriteria = PanToUi(state: this);
    }

    super.initState();
  }

  Future<Widget> getUI(dynamic data) async {
    json2ui.stateMgr.data = data;
    currentCompany.log.add("getUI");
    var modelLoaded = widget.apiCallInfo.responseSchema!;

    WidgetTyped ret = await _getWidgetTyped(
      modelLoaded,
      widget.apiCallInfo.currentAPIResponse,
      'root',
      json2uiCriteria,
    );

    // var ui = json2ui as JsonToUi;
    // var export = Export2UI();
    // ui.haveTemplate = false;
    // ui.modeTemplate = false;
    // ui.stateMgr.dispose();
    // ui.saveOnModel = widget.apiCallInfo.currentAPIResponse;
    // ui.stateMgr.loadJSonConfigLayout(ui.saveOnModel!);

    // await export.browseSync(modelLoaded, false, 0);

    // ui.context = context;
    // ui.modeTemplate = true;
    // ui.model = modelLoaded;
    // ui.stateMgr.jsonUI = export.json;
    // var ret =
    //     ui.browseJsonToWidget(
    //       'root',
    //       export.json,
    //       path: '',
    //       pathData: '',
    //       parentType: WidgetType.root,
    //     )!;

    // if (json2ui.stateMgr.dataEmpty == null) {
    //   var dataEmpty = Export2FakeJson(
    //     modeArray: ModeArrayEnum.anyInstance,
    //     mode: ModeEnum.empty,
    //   );
    //   await dataEmpty.browseSync(modelLoaded, false, 0);
    //   json2ui.stateMgr.dataEmpty = dataEmpty.json;
    // }

    // SchedulerBinding.instance.addPostFrameCallback((timeStamp) async {
    //   json2ui.haveTemplate = true;
    //   json2ui.modeTemplate = false;
    //   for (var element in json2ui.stateMgr.stateTemplate.entries) {
    //     currentCompany.log.add("template ${element.key} ${element.value}");
    //   }
    //   var data = json2ui.stateMgr.data;
    //   if (data != null) {
    //     // recharge les bonnes datas
    //     json2ui.loadData(data);
    //   }
    // });

    return ret.widget;
  }

  Future<Widget> getUIRequest() async {
    widget.apiCallInfo.currentAPIRequest ??= await GoTo().getApiRequestModel(
      widget.apiCallInfo,
      widget.apiCallInfo.api.masterID!,
      withDelay: false,
    );

    var modelLoaded = widget.apiCallInfo.currentAPIRequest!;

    WidgetTyped ret = await _getWidgetTyped(
      modelLoaded,
      modelLoaded,
      'search criteria',
      json2uiCriteria,
    );

    return ret.widget;
  }

  Future<Widget> getUIResponse() async {
    widget.apiCallInfo.currentAPIResponse ??= await GoTo().getApiResponseModel(
      widget.apiCallInfo,
      widget.apiCallInfo.api.masterID!,
      withDelay: false,
    );

    ModelSchema? modelLoaded = await widget.apiCallInfo.currentAPIResponse!
        .getSubSchema(subNode: 200);

    WidgetTyped ret = await _getWidgetTyped(
      modelLoaded,
      widget.apiCallInfo.currentAPIResponse,
      'response data',
      json2ui,
    );

    return ret.widget;
  }

  Future<WidgetTyped> _getWidgetTyped(
    ModelSchema? modelLoaded,
    ModelSchema? saveModel,
    String name,
    GenericToUi aJson2ui,
  ) async {
    var export = Export2UI();
    await export.browseSync(modelLoaded!, false, 0);

    late WidgetTyped ret;
    StateManager stateManager;

    if (widget.modeLegacy) {
      var ui = aJson2ui as JsonToUi;
      ui.haveTemplate = false;
      ui.stateMgr.dispose();
      ui.saveOnModel = saveModel;
      ui.stateMgr.loadJSonConfigLayout(ui.saveOnModel!);
      ui.context = context;
      ui.modeTemplate = true;
      ui.model = modelLoaded;
      ui.stateMgr.jsonUI = export.json;
      stateManager = ui.stateMgr;

      ret =
          ui.browseJsonToWidget(
            name,
            export.json,
            path: '',
            pathData: '',
            parentType: WidgetType.root,
          )!;
    } else {
      var ui = aJson2ui as PanToUi;
      var ctx = PanContext(name: '', level: 0, path: '')..data = export.json;
      var browser = BrowserPan();
      browser.browseAttr(ctx, '');
      ui.panContext = ctx;
      stateManager = ui.stateMgr;
    }

    if (stateManager.dataEmpty == null) {
      var dataEmpty = Export2FakeJson(
        modeArray: ModeArrayEnum.anyInstance,
        mode: ModeEnum.empty,
      );
      await dataEmpty.browseSync(modelLoaded, false, 0);
      stateManager.dataEmpty = dataEmpty.json;

      if (stateManager.data == null) {
        var data = Export2FakeJson(
          modeArray: ModeArrayEnum.anyInstance,
          mode: ModeEnum.empty,
        );
        await data.browseSync(modelLoaded, false, 0);
        stateManager.data = data.json;
      }
    }

    if (widget.modeLegacy) {
      SchedulerBinding.instance.addPostFrameCallback((timeStamp) async {
        aJson2ui.haveTemplate = true;
        aJson2ui.modeTemplate = false;
        var data = aJson2ui.stateMgr.data;
        if (data != null) {
          // recharge les bonnes datas
          aJson2ui.loadData(data);
        }
      });
    } else {
      var ui = aJson2ui as PanToUi;
      //(ui.panContext!.listPanOfJson.first).attrName = name;
      ret =
          ui.getWidget(
            ui.panContext!.listPanOfJson.first,
            WidgetType.root,
            "",
          )!;
    }
    return ret;
  }

  Future<Widget> getUIPage() async {
    List<Widget> paramSelector = await getAllExampleSelectorBtn();
    Widget criteria = await getUIRequest();
    Widget data = await getUIResponse();

    return SingleChildScrollView(
      child: Column(
        children: [
          Row(children: paramSelector),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(child: criteria),
              ElevatedButton.icon(
                icon: Icon(Icons.search),
                onPressed: () {
                  startSearch(context);
                },
                label: Text('Search'),
              ),
            ],
          ),
          data,
        ],
      ),
    );
  }

  Future<List<Widget>> getAllExampleSelectorBtn() async {
    List<Widget> paramSelector = <Widget>[];
    var exampleModel = ModelSchema(
      category: Category.exampleApi,
      headerName: 'example',
      id: 'example/temp/${widget.apiCallInfo.api.masterID!}',
      infoManager: InfoManagerApiExample(),
      ref: null,
    );
    await exampleModel.loadYamlAndProperties(
      cache: false,
      withProperties: true,
    );

    var a = BrowseSingle();
    a.browse(exampleModel, false);

    var examples = exampleModel.mapInfoByJsonPath.values.where((e) {
      return e.type == 'example';
    });

    for (var element in examples) {
      paramSelector.add(
        ElevatedButton(
          onPressed: () async {
            var requesthelper = widget.requestHelper!;
            requesthelper.apiCallInfo.selectedExample = element;
            var jsonParam = await bddStorage.getAPIParam(
              requesthelper.apiCallInfo.currentAPIRequest!,
              element.masterID!,
            );

            requesthelper.apiCallInfo.clearRequest();

            if (jsonParam != null) {
              requesthelper.apiCallInfo.initWithParamJson(jsonParam);
              var data = json2uiCriteria.stateMgr.data;
              for (var element in requesthelper.apiCallInfo.params) {
                if (element.toSend) {
                  data[element.type][element.name] = element.value;
                } else {
                  data[element.type][element.name] =
                      json2uiCriteria.stateMgr.dataEmpty[element.type][element
                          .name];
                }
              }
              if (data != null) {
                // recharge les bonnes datas
                json2uiCriteria.loadData(data);
              }
            }
          },
          child: Text(element.name),
        ),
      );
    }
    return paramSelector;
  }

  @override
  Widget build(BuildContext context) {
    Response? reponse = widget.apiCallInfo.aResponse?.reponse;
    Map? retJson;
    if (widget.requestHelper == null && reponse?.data is Map) {
      if (widget.apiCallInfo.responseSchema != null) {
        return FutureBuilder(
          key: GlobalKey(),
          future: getUI(reponse?.data),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return snapshot.data!;
            } else if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            } else {
              return Center(child: CircularProgressIndicator());
            }
          },
        );
      } else {
        retJson = reponse?.data;
        var ui = json2ui as JsonToUi;
        ui.context = context;
        var w = ui.browseJsonToWidget(
          'root',
          retJson,
          path: '',
          pathData: '',
          parentType: WidgetType.root,
        );

        json2ui.loadData(reponse?.data);
        return w!.widget;
      }
    } else if (widget.requestHelper != null) {
      return FutureBuilder(
        key: GlobalKey(),
        future: getUIPage(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return snapshot.data!;
          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      );
    } else {
      return Text('No data');
    }
  }

  void startSearch(BuildContext context) async {
    bool isCancelled = false;
    final cancelToken = CancelToken();

    showDownloadDialog(context, () {
      isCancelled = true;
      cancelToken.cancel('Request cancelled by user');
    });

    widget.requestHelper!.apiCallInfo.initListParams(
      paramJson: json2uiCriteria.stateMgr.data,
    );
    widget.requestHelper!.initUrl(context);

    await widget.requestHelper!.doExecuteRequest(cancelToken);

    if (!isCancelled && dialogCtx?.mounted == true) {
      Navigator.of(dialogCtx!).pop(); // ferme la boîte si pas annulé
    }

    if (widget.requestHelper!.apiCallInfo.aResponse?.reponse?.statusCode ==
        200) {
      json2ui.stateMgr.data =
          widget.requestHelper!.apiCallInfo.aResponse?.reponse?.data;
      json2ui.loadData(json2ui.stateMgr.data);
    } else {
      showErrorDialog(
        // ignore: use_build_context_synchronously
        context,
        widget.requestHelper!.apiCallInfo.aResponse!,
      );
    }
  }

  BuildContext? dialogCtx;

  void showErrorDialog(BuildContext context, APIResponse res) {
    var message = widget.requestHelper!.getStringResponse();
    Size size = MediaQuery.of(context).size;
    double width = size.width * 0.5;
    double height = size.height * 0.5;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Error', style: TextStyle(color: Colors.red)),
          content: SizedBox(
            height: height,
            width: width,
            child: Column(
              spacing: 10,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                Expanded(
                  child: LogViewer(
                    fct: () {
                      return widget.requestHelper!.apiCallInfo.logs;
                    },
                    change: ValueNotifier<int>(0),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> showDownloadDialog(BuildContext context, VoidCallback onCancel) {
    return showDialog(
      context: context,
      barrierDismissible:
          false, // empêche la fermeture en cliquant à l'extérieur
      builder: (BuildContext ctx) {
        dialogCtx = ctx;
        return AlertDialog(
          title: Text('sending request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Wait while the request is being sent...'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop(); // ferme la boîte de dialogue
                onCancel(); // appelle la fonction d'annulation
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}
