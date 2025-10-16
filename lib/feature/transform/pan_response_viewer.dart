import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jsonschema/core/api/call_manager.dart';
import 'package:jsonschema/core/export/export2json_fake.dart';
import 'package:jsonschema/core/export/export2ui.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/api/api_widget_request_helper.dart';
import 'package:jsonschema/feature/content/json_to_ui.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/start_core.dart';

class PanResponseViewer extends StatefulWidget {
  const PanResponseViewer({
    super.key,
    required this.apiCallInfo,
    this.requestHelper,
  });

  final APICallManager apiCallInfo;
  final WidgetRequestHelper? requestHelper;

  @override
  State<PanResponseViewer> createState() => _PanResponseViewerState();
}

class _PanResponseViewerState extends State<PanResponseViewer> {
  late JsonToUi json2uiCriteria;
  late JsonToUi json2ui;

  @override
  void initState() {
    json2uiCriteria = JsonToUi(state: this);
    json2ui = JsonToUi(state: this);
    super.initState();
  }

  Future<Widget> getUI(dynamic data) async {
    json2ui.stateMgr.data = data;
    currentCompany.log.add("getUI");

    var modelLoaded = widget.apiCallInfo.responseSchema!;
    var export = Export2UI();
    json2ui.haveTemplate = false;
    json2ui.modeTemplate = false;
    json2ui.stateMgr.dispose();
    json2ui.saveOnModel = widget.apiCallInfo.currentAPIResponse;
    json2ui.stateMgr.loadJSonConfigLayout(json2ui.saveOnModel!);

    await export.browseSync(modelLoaded, false, 0);

    json2ui.context = context;
    json2ui.modeTemplate = true;
    json2ui.model = modelLoaded;
    var ret =
        json2ui.browseJsonToWidget(
          'root',
          export.json,
          path: '',
          pathData: '',
          parentType: WidgetType.root,
        )!;

    if (json2ui.stateMgr.dataEmpty == null) {
      var dataEmpty = Export2FakeJson(
        modeArray: ModeArrayEnum.anyInstance,
        mode: ModeEnum.empty,
      );
      await dataEmpty.browseSync(modelLoaded, false, 0);
      json2ui.stateMgr.dataEmpty = dataEmpty.json;
    }

    SchedulerBinding.instance.addPostFrameCallback((timeStamp) async {
      json2ui.haveTemplate = true;
      json2ui.modeTemplate = false;
      for (var element in json2ui.stateMgr.stateTemplate.entries) {
        currentCompany.log.add("template ${element.key} ${element.value}");
      }
      var data = json2ui.stateMgr.data;
      if (data != null) {
        // recharge les bonnes datas
        json2ui.loadData(data);
      }
    });

    return ret.widget;
  }

  Future<Widget> getUIRequest() async {
    widget.apiCallInfo.currentAPIRequest ??= await GoTo().getApiRequestModel(
      widget.apiCallInfo,
      widget.apiCallInfo.api.masterID!,
      withDelay: false,
    );

    json2uiCriteria.stateMgr.data = null;

    var modelLoaded = widget.apiCallInfo.currentAPIRequest!;
    var export = Export2UI();
    json2uiCriteria.haveTemplate = false;
    json2uiCriteria.modeTemplate = false;
    json2uiCriteria.stateMgr.dispose();
    json2uiCriteria.saveOnModel = widget.apiCallInfo.currentAPIRequest;
    json2uiCriteria.stateMgr.loadJSonConfigLayout(json2uiCriteria.saveOnModel!);

    await export.browseSync(modelLoaded, false, 0);

    json2uiCriteria.context = context;
    json2uiCriteria.modeTemplate = true;
    json2uiCriteria.model = modelLoaded;
    var ret =
        json2uiCriteria.browseJsonToWidget(
          'search criteria',
          export.json,
          path: '',
          pathData: '',
          parentType: WidgetType.root,
        )!;

    if (json2uiCriteria.stateMgr.dataEmpty == null) {
      var dataEmpty = Export2FakeJson(
        modeArray: ModeArrayEnum.anyInstance,
        mode: ModeEnum.empty,
      );
      await dataEmpty.browseSync(modelLoaded, false, 0);
      json2uiCriteria.stateMgr.dataEmpty = dataEmpty.json;

      var data = Export2FakeJson(
        modeArray: ModeArrayEnum.anyInstance,
        mode: ModeEnum.empty,
      );
      await data.browseSync(modelLoaded, false, 0);
      json2uiCriteria.stateMgr.data = data.json;
    }

    SchedulerBinding.instance.addPostFrameCallback((timeStamp) async {
      json2uiCriteria.haveTemplate = true;
      json2uiCriteria.modeTemplate = false;
      for (var element in json2uiCriteria.stateMgr.stateTemplate.entries) {
        currentCompany.log.add("template ${element.key} ${element.value}");
      }
      var data = json2uiCriteria.stateMgr.data;
      if (data != null) {
        // recharge les bonnes datas
        json2uiCriteria.loadData(data);
      }
    });

    return ret.widget;
  }

  Future<Widget> getUIResponse() async {
    json2ui.stateMgr.data = null;
    currentCompany.log.add("getUI");

    widget.apiCallInfo.currentAPIResponse ??= await GoTo().getApiResponseModel(
      widget.apiCallInfo,
      widget.apiCallInfo.api.masterID!,
      withDelay: false,
    );

    ModelSchema? modelLoaded = await widget.apiCallInfo.currentAPIResponse!
        .getSubSchema(subNode: 200);

    var export = Export2UI();
    json2ui.haveTemplate = false;
    json2ui.modeTemplate = false;
    json2ui.stateMgr.dispose();
    json2ui.saveOnModel = widget.apiCallInfo.currentAPIResponse;
    json2ui.stateMgr.loadJSonConfigLayout(json2ui.saveOnModel!);

    await export.browseSync(modelLoaded!, false, 0);

    json2ui.context = context;
    json2ui.modeTemplate = true;
    json2ui.model = modelLoaded;
    var ret =
        json2ui.browseJsonToWidget(
          'data',
          export.json,
          path: '',
          pathData: '',
          parentType: WidgetType.root,
        )!;

    if (json2ui.stateMgr.dataEmpty == null) {
      var dataEmpty = Export2FakeJson(
        modeArray: ModeArrayEnum.anyInstance,
        mode: ModeEnum.empty,
      );
      await dataEmpty.browseSync(modelLoaded, false, 0);
      json2ui.stateMgr.dataEmpty = dataEmpty.json;

      var data = Export2FakeJson(
        modeArray: ModeArrayEnum.anyInstance,
        mode: ModeEnum.empty,
      );
      await data.browseSync(modelLoaded, false, 0);
      json2ui.stateMgr.data = data.json;
    }

    SchedulerBinding.instance.addPostFrameCallback((timeStamp) async {
      json2ui.haveTemplate = true;
      json2ui.modeTemplate = false;
      for (var element in json2ui.stateMgr.stateTemplate.entries) {
        currentCompany.log.add("template ${element.key} ${element.value}");
      }
      var data = json2ui.stateMgr.data;
      if (data != null) {
        // recharge les bonnes datas
        json2ui.loadData(data);
      }
    });

    return ret.widget;
  }

  Future<Widget> getUIPage() async {
    Widget criteria = await getUIRequest();
    Widget data = await getUIResponse();

    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(child: criteria),
              ElevatedButton.icon(
                icon: Icon(Icons.search),
                onPressed: () async {
                  widget.requestHelper!.apiCallInfo.initListParams(
                    paramJson: json2uiCriteria.stateMgr.data,
                  );
                  widget.requestHelper!.initUrl(context);
                  await widget.requestHelper!.doExecuteRequest();
                  print(widget.requestHelper!.apiCallInfo.aResponse?.reponse);
                  if (widget
                          .requestHelper!
                          .apiCallInfo
                          .aResponse
                          ?.reponse
                          ?.statusCode ==
                      200) {
                    json2ui.stateMgr.data =
                        widget.requestHelper!.apiCallInfo.aResponse?.reponse?.data;
                        json2ui.loadData(json2ui.stateMgr.data);
                  }
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

  @override
  Widget build(BuildContext context) {
    Response? reponse = widget.apiCallInfo.aResponse?.reponse;
    Map? retJson;
    if (reponse?.data is Map) {
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
        currentCompany.log.add("no getUI with template");
        retJson = reponse?.data;
        json2ui.context = context;
        var w = json2ui.browseJsonToWidget(
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
}
