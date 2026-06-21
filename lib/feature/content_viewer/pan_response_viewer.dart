import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jsonschema/core/api/call_api_manager.dart';
import 'package:jsonschema/core/api/call_ds_manager.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/core/export/export2json_fake.dart';
import 'package:jsonschema/core/export/export2ui.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/util.dart';
import 'package:jsonschema/core/api/widget_api_helper.dart';
import 'package:jsonschema/feature/content/pan_browser.dart';
import 'package:jsonschema/feature/content/json_to_ui.dart';
import 'package:jsonschema/feature/content/pan_to_ui.dart';
import 'package:jsonschema/feature/content/state_manager.dart';
import 'package:jsonschema/pages/router_config.dart';

/// affiche la réponse d'une API en fonction d'un modelSchema de réponse
/// avec ou sans critria de recherche
///    getUI   ou   getUIPage avec les 2
class PanResponseViewer extends StatefulWidget {
  const PanResponseViewer({
    super.key,
    required this.requestHelper,
    this.modeLegacy = false,
    this.callerDatasource,
  });

  final WidgetAPIHelper requestHelper;
  final bool modeLegacy;
  final CallerDatasource? callerDatasource;

  @override
  State<PanResponseViewer> createState() => _PanResponseViewerState();
}

mixin UIMixin {
  Future<WidgetTyped> getRootWidgetTyped(
    ModelSchema? modelLoaded,
    ModelSchema? saveModel,
    String name,
    GenericToUi aJson2ui,
    bool widgetModeLegacy,
    BuildContext? context,
    ConfigBlock? config, {
    required bool withData,
  }) async {
    if (aJson2ui.aExport == null) {
      aJson2ui.aExport = Export2UI(config: BrowserConfig());
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

      ret = ui.browseJsonToWidget(
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
      var fakeGenerator = Export2FakeJson(
        config: BrowserConfig(),
        modeArray: ModeArrayEnum.anyInstance,
        mode: ModeEnum.empty,
        propMode: PropertyRequiredEnum.all,
      );
      await fakeGenerator.browseSync(modelLoaded!, false, 0);
      stateManager.dataEmpty = fakeGenerator.json;

      if (stateManager.data == null && withData) {
        // charge des datas vides pour les champs non obligatoire
        var fakeGenerator = Export2FakeJson(
          config: BrowserConfig(),
          modeArray: ModeArrayEnum.anyInstance,
          mode: ModeEnum.empty,
          propMode: PropertyRequiredEnum.all,
        );
        await fakeGenerator.browseSync(modelLoaded, false, 0);
        stateManager.data = fakeGenerator.json;
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
      ret = ui.getWidgetTyped(
        ui.stateMgr.browser.rootContext!.listPanOfJson.first,
        WidgetType.root,
        "",
        [],
      )!;
      SchedulerBinding.instance.addPostFrameCallback((timeStamp) async {
        var data = aJson2ui.stateMgr.data;
        if (data != null) {
          // recharge les bonnes datas
          aJson2ui.loadData(data);
        }
      });
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
    widget.requestHelper.callerDatasource = widget.callerDatasource;

    if (widget.modeLegacy) {
      json2ui = JsonToUi(state: this);
      json2uiCriteria = JsonToUi(state: this);
    } else {
      json2ui = PanToUi(state: this, withScroll: true);
      (json2ui as PanToUi).requestHelper = widget.requestHelper;
      json2uiCriteria = PanToUi(state: this, withScroll: true);
    }

    super.initState();
  }

  Future<Widget> getUI(dynamic data) async {
    json2ui.stateMgr.data = data;
    //currentCompany.log.add("getUI");
    var modelLoaded = apiCallInfo.responseSchema!;

    WidgetTyped ret = await getRootWidgetTyped(
      modelLoaded,
      apiCallInfo.currentAPIResponse,
      'root',
      json2ui,
      widget.modeLegacy,
      context,
      widget.callerDatasource?.dsConfig.criteria,
      withData: true,
    );

    return ret.widget;
  }

  Future<Widget> getUIRequest() async {
    apiCallInfo.currentAPIRequest ??= await ApiRequestNavigator()
        .getApiRequestModel(
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
      widget.callerDatasource?.dsConfig.criteria,
      withData: true,
    );

    return ret.widget;
  }

  Future<Widget> getUIResponse() async {
    apiCallInfo.currentAPIResponse ??= await ApiRequestNavigator()
        .getApiResponseModel(
          apiCallInfo,
          apiCallInfo.namespace,
          apiCallInfo.attrApi.masterID!,
          withDelay: false,
        );

    ModelSchema? modelLoaded = await apiCallInfo.currentAPIResponse!
        .getSubSchema(subNode: 200);

    if (modelLoaded == null) {
      return const Text('No response model for 200');
    }

    WidgetTyped ret = await getRootWidgetTyped(
      modelLoaded,
      apiCallInfo.currentAPIResponse,
      'response data',
      json2ui,
      widget.modeLegacy,
      // ignore: use_build_context_synchronously
      context,
      widget.callerDatasource?.dsConfig.data,
      withData: false,
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

    var paginationVariable =
        widget.callerDatasource?.dsConfig.criteria.paginationVariable;
    var paginationMin = widget.callerDatasource?.dsConfig.criteria.min ?? 0;

    List<Widget> saveWidget = [];
    if (widget.callerDatasource != null && widget.callerDatasource!.canSave()) {
      saveWidget.add(const Spacer());
      saveWidget.add(
        ElevatedButton.icon(
          icon: const Icon(Icons.add),
          onPressed: () {
            json2ui.stateMgr.data = jsonDecode(
              jsonEncode(json2ui.stateMgr.dataEmpty),
            );
            json2ui.loadData(json2ui.stateMgr.data);
          },
          label: const Text('Create'),
        ),
      );
      saveWidget.add(
        ElevatedButton.icon(
          icon: const Icon(Icons.save),
          onPressed: () {
            //startSearch(context);
            if (widget.callerDatasource != null &&
                widget.callerDatasource!.dsConfig.data.rowsVariable != null) {
              var dataToSave = json2ui
                  .stateMgr
                  .data[widget.callerDatasource!.dsConfig.data.rowsVariable];
              if (dataToSave is List) {
                for (var e in dataToSave) {
                  if (e is Map && e.containsKey(cstStorage)) {
                    if (e[cstStorage][cstStorageChange] != null) {
                      // update
                      bddStorage.saveData(
                        widget.callerDatasource!,
                        apiCallInfo.currentAPIResponse,
                        e,
                      );
                    } else {
                      // create
                      bddStorage.saveData(
                        widget.callerDatasource!,
                        apiCallInfo.currentAPIResponse,
                        e,
                      );
                    }
                    bddStorage.saveData(
                      widget.callerDatasource!,
                      apiCallInfo.currentAPIResponse,
                      e,
                    );
                  }
                }
              }
            } else {
              bddStorage.saveData(
                widget.callerDatasource,
                apiCallInfo.currentAPIResponse,
                json2ui.stateMgr.data,
              );
            }
            json2ui.stateMgr.clearDisplayedData();
          },
          label: const Text('Save'),
        ),
      );
    }

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
                icon: const Icon(Icons.search),
                onPressed: () {
                  startSearch(context);
                },
                label: const Text('Search'),
              ),

              if (paginationVariable != null)
                ElevatedButton.icon(
                  icon: const Icon(Icons.navigate_before),
                  onPressed: () {
                    doPrevPage(paginationVariable, paginationMin);
                    startSearch(context);
                  },
                  label: const Text('Previous'),
                ),
              if (paginationVariable != null)
                ElevatedButton.icon(
                  icon: const Icon(Icons.navigate_next),
                  onPressed: () {
                    doNextPage(paginationVariable);
                    startSearch(context);
                  },
                  label: const Text('Next'),
                ),
              ...saveWidget,
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
    Iterable<AttributInfo> examples = await apiCallInfo.getExamples();

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
            if (widget.callerDatasource?.dsConfig.paramToLoad != null &&
                firstLoad) {
              firstLoad = false;
              loadCriteria(widget.callerDatasource!.dsConfig.paramToLoad!).then(
                (value) {
                  // ignore: use_build_context_synchronously
                  startSearch(context);
                },
              );
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
    json2ui.stateMgr.clearDisplayedData();
    widget.requestHelper.startCancellableSearch(
      context,
      json2uiCriteria.stateMgr.data,
      () {
        json2ui.stateMgr.data = apiCallInfo.aResponse?.reponse?.data;
        json2ui.loadData(json2ui.stateMgr.data);
      },
    );
  }
}
