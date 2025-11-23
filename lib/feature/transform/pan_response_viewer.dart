import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/core/api/call_manager.dart';
import 'package:jsonschema/core/api/caller_api.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/core/export/export2json_fake.dart';
import 'package:jsonschema/core/export/export2ui.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/util.dart';
import 'package:jsonschema/feature/api/api_widget_request_helper.dart';
import 'package:jsonschema/feature/api/pan_api_example.dart';
import 'package:jsonschema/feature/content/pan_browser.dart';
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
    required this.requestHelper,
    this.modeLegacy = false,
    this.configApp,
  });

  final WidgetRequestHelper requestHelper;
  final bool modeLegacy;
  final ConfigApp? configApp;

  @override
  State<PanResponseViewer> createState() => _PanResponseViewerState();
}

class ConfigApp {
  String? name;
  AttributInfo? paramToLoad;
  ConfigBlock criteria = ConfigBlock();
  ConfigBlock data = ConfigBlock();
}

class ConfigLink {
  final String onPath;
  final String title;
  final String toDatasrc;

  ConfigLink({
    required this.onPath,
    required this.title,
    required this.toDatasrc,
  });
}

class ConfigBlock {
  List<String> dataDisplayPath = [];
  String? paginationVariable;
  int min = 0;
  List<ConfigLink> links = [];
}

mixin UIMixin {
  Future<WidgetTyped> getRootWidgetTyped(
    ModelSchema? modelLoaded,
    ModelSchema? saveModel,
    String name,
    GenericToUi aJson2ui,
    bool widgetModeLegacy,
    BuildContext? context,
    ConfigBlock? config,
  ) async {
    if (aJson2ui.aExport == null) {
      aJson2ui.aExport = Export2UI();
      await aJson2ui.aExport!.browseSync(modelLoaded!, false, 0);
    }
    Export2UI export = aJson2ui.aExport!;
    late WidgetTyped ret;
    StateManager stateManager;

    if (widgetModeLegacy) {
      var ui = aJson2ui as JsonToUi;
      ui.haveTemplate = false;
      ui.stateMgr.dispose();
      ui.saveOnModel = saveModel;
      if (saveModel != null) {
        ui.stateMgr.loadJSonConfigLayout(ui.saveOnModel!);
      }

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
      ui.stateMgr.jsonUI = export.json;
      ui.model = modelLoaded;
      ui.saveOnModel = saveModel;
      if (saveModel != null) {
        ui.stateMgr.loadJSonConfigLayout(ui.saveOnModel!);
      }
      ui.context = context;
      ui.stateMgr.config = config;
      if (ui.stateMgr.browser.rootContext == null) {
        if (config != null && config.dataDisplayPath.isNotEmpty) {
          ui.stateMgr.browser.listPathPan.addAll(config.dataDisplayPath);
        }
        var ctx = PanContext(name: '', level: 0, path: '')..data = export.json;
        ui.stateMgr.browser.browseAttr(ctx, '', 'root');
      }
      stateManager = ui.stateMgr;
    }

    if (stateManager.dataEmpty == null) {
      var dataEmpty = Export2FakeJson(
        modeArray: ModeArrayEnum.anyInstance,
        mode: ModeEnum.empty,
      );
      await dataEmpty.browseSync(modelLoaded!, false, 0);
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

    if (widgetModeLegacy) {
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
      ui.labelRoot = name;
      ret =
          ui.getWidgetTyped(
            ui.stateMgr.browser.rootContext!.listPanOfJson.first,
            WidgetType.root,
            "",
            [],
          )!;
    }
    return ret;
  }
}

class _PanResponseViewerState extends State<PanResponseViewer> with UIMixin {
  late GenericToUi json2uiCriteria;
  late GenericToUi json2ui;
  late APICallManager apiCallInfo;

  @override
  void initState() {
    apiCallInfo = widget.requestHelper.apiCallInfo;

    if (widget.modeLegacy) {
      json2ui = JsonToUi(state: this);
      json2uiCriteria = JsonToUi(state: this);
    } else {
      json2ui = PanToUi(state: this, withScroll: true);
      json2uiCriteria = PanToUi(state: this, withScroll: true);
    }

    super.initState();
  }

  Future<Widget> getUI(dynamic data) async {
    json2ui.stateMgr.data = data;
    currentCompany.log.add("getUI");
    var modelLoaded = apiCallInfo.responseSchema!;

    WidgetTyped ret = await getRootWidgetTyped(
      modelLoaded,
      apiCallInfo.currentAPIResponse,
      'root',
      json2uiCriteria,
      widget.modeLegacy,
      context,
      widget.configApp?.criteria,
    );

    return ret.widget;
  }

  Future<Widget> getUIRequest() async {
    apiCallInfo.currentAPIRequest ??= await GoTo().getApiRequestModel(
      apiCallInfo,
      apiCallInfo.namespace,
      apiCallInfo.attrApi.masterID!,
      withDelay: false,
    );

    var modelLoaded = apiCallInfo.currentAPIRequest!;

    WidgetTyped ret = await getRootWidgetTyped(
      modelLoaded,
      modelLoaded,
      'search criteria',
      json2uiCriteria,
      widget.modeLegacy,
      // ignore: use_build_context_synchronously
      context,
      widget.configApp?.criteria,
    );

    return ret.widget;
  }

  Future<Widget> getUIResponse() async {
    apiCallInfo.currentAPIResponse ??= await GoTo().getApiResponseModel(
      apiCallInfo,
      apiCallInfo.namespace,
      apiCallInfo.attrApi.masterID!,
      withDelay: false,
    );

    ModelSchema? modelLoaded = await apiCallInfo.currentAPIResponse!
        .getSubSchema(subNode: 200);

    if (modelLoaded == null) {
      return Text('No response model for 200');
    }

    WidgetTyped ret = await getRootWidgetTyped(
      modelLoaded,
      apiCallInfo.currentAPIResponse,
      'response data',
      json2ui,
      widget.modeLegacy,
      // ignore: use_build_context_synchronously
      context,
      widget.configApp?.data,
    );

    return ret.widget;
  }

  Future<Widget> getUIPage() async {
    if (!widget.modeLegacy) {
      (json2ui as PanToUi).withScroll = false;
      (json2uiCriteria as PanToUi).withScroll = false;
    }

    List<Widget> paramSelector = await getAllExampleSelectorBtn();
    Widget criteria = await getUIRequest();
    Widget data = await getUIResponse();

    var paginationVariable = widget.configApp?.criteria.paginationVariable;
    var paginationMin = widget.configApp?.criteria.min ?? 0;

    return SingleChildScrollView(
      child: Column(
        children: [
          Row(children: paramSelector),
          criteria,
          // Row(
          //   crossAxisAlignment: CrossAxisAlignment.start,
          //   mainAxisAlignment: MainAxisAlignment.start,
          //   children: [Expanded(child: criteria)],
          // ),
          Row(
            children: [
              ElevatedButton.icon(
                icon: Icon(Icons.search),
                onPressed: () {
                  startSearch(context);
                },
                label: Text('Search'),
              ),
              if (paginationVariable != null)
                ElevatedButton.icon(
                  icon: Icon(Icons.navigate_before),
                  onPressed: () {
                    doPrevPage(paginationVariable, paginationMin);
                    startSearch(context);
                  },
                  label: Text('Previous'),
                ),
              if (paginationVariable != null)
                ElevatedButton.icon(
                  icon: Icon(Icons.navigate_next),
                  onPressed: () {
                    doNextPage(paginationVariable);
                    startSearch(context);
                  },
                  label: Text('Next'),
                ),
            ],
          ),
          data,
        ],
      ),
    );
  }

  void doNextPage(String paginationVariable) {
    var criteria = (json2uiCriteria as PanToUi).stateMgr.data;
    var page = findValueByKey(criteria, paginationVariable);
    dynamic numpage = 0;
    if (page is String) {
      numpage = int.tryParse(page) ?? 0;
      numpage = numpage + 1;
      numpage = "$numpage";
    } else {
      numpage = page;
      numpage = numpage + 1;
    }

    findValueByKey(criteria, paginationVariable, valueToSet: numpage);
    (json2uiCriteria as PanToUi).loadData(criteria);
  }

  void doPrevPage(String paginationVariable, int min) {
    var criteria = (json2uiCriteria as PanToUi).stateMgr.data;
    var page = findValueByKey(criteria, paginationVariable);
    dynamic numpage = 0;
    if (page is String) {
      numpage = int.tryParse(page) ?? 0;
      numpage = numpage - 1;
      if (numpage <= min) numpage = min;
      numpage = "$numpage";
    } else {
      numpage = page;
      numpage = numpage - 1;
      if (numpage <= min) numpage = min;
    }

    findValueByKey(criteria, paginationVariable, valueToSet: numpage);
    (json2uiCriteria as PanToUi).loadData(criteria);
  }

  Future<List<Widget>> getAllExampleSelectorBtn() async {
    List<Widget> paramSelector = <Widget>[];
    var exampleModel = ModelSchema(
      category: Category.exampleApi,
      headerName: 'example',
      id: 'example/temp/${apiCallInfo.attrApi.masterID!}',
      infoManager: InfoManagerApiExample(),
      ref: null,
    )..namespace = apiCallInfo.namespace;
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
            await loadCriteria(element);
          },
          child: Text(element.name),
        ),
      );
    }
    return paramSelector;
  }

  Future<void> loadCriteria(AttributInfo element) async {
    apiCallInfo.selectedExample = element;
    var jsonParam = await bddStorage.getAPIParam(
      apiCallInfo.currentAPIRequest!,
      element.masterID!,
    );

    apiCallInfo.clearRequest();

    if (jsonParam != null) {
      apiCallInfo.initWithParamJson(jsonParam);
      var data = json2uiCriteria.stateMgr.data;
      for (var element in apiCallInfo.params) {
        if (element.toSend) {
          data[element.type][element.name] = element.value;
        } else {
          data[element.type][element.name] =
              json2uiCriteria.stateMgr.dataEmpty[element.type][element.name];
        }
      }
      if (data != null) {
        // recharge les bonnes datas
        json2uiCriteria.loadData(data);
      }
    }
  }

  bool firstLoad = true;

  @override
  Widget build(BuildContext context) {
    Response? reponse = apiCallInfo.aResponse?.reponse;
    Map? retJson;
    if ((apiCallInfo.modeAPIResponse == null ||
            apiCallInfo.modeAPIResponse == true) &&
        reponse?.data is Map) {
      apiCallInfo.modeAPIResponse ??= true;
      // si api avec reponse
      return getWidgetAPIResponse(reponse, retJson, context);
    } else {
      // sinon page
      apiCallInfo.modeAPIResponse ??= false;
      return FutureBuilder(
        key: GlobalKey(),
        future: getUIPage(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            if (widget.configApp?.paramToLoad != null && firstLoad) {
              firstLoad = false;
              loadCriteria(widget.configApp!.paramToLoad!).then((value) {
                // ignore: use_build_context_synchronously
                startSearch(context);
              });
            }

            return snapshot.data!;
          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      );
    }
  }

  Widget getWidgetAPIResponse(
    Response<dynamic>? reponse,
    Map<dynamic, dynamic>? retJson,
    BuildContext context,
  ) {
    if (apiCallInfo.responseSchema != null) {
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
  }

  void startSearch(BuildContext context) async {
    bool isCancelled = false;
    final cancelToken = CancelToken();

    showDownloadDialog(context, () {
      isCancelled = true;
      cancelToken.cancel('Request cancelled by user');
    });

    apiCallInfo.initListParams(paramJson: json2uiCriteria.stateMgr.data);
    widget.requestHelper.initUrl(context);

    await widget.requestHelper.doExecuteRequest(cancelToken);

    if (!isCancelled && dialogCtx?.mounted == true) {
      Navigator.of(dialogCtx!).pop(); // ferme la boîte si pas annulé
    }

    if (apiCallInfo.aResponse?.reponse?.statusCode == 200) {
      json2ui.stateMgr.data = apiCallInfo.aResponse?.reponse?.data;
      json2ui.loadData(json2ui.stateMgr.data);
    } else {
      showErrorDialog(
        // ignore: use_build_context_synchronously
        context,
        apiCallInfo.aResponse,
      );
    }
  }

  BuildContext? dialogCtx;

  void showErrorDialog(BuildContext context, APIResponse? res) {
    var message = widget.requestHelper.getStringResponse();
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
                      return widget.requestHelper.apiCallInfo.logs;
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
