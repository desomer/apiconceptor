import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jsonschema/core/api/call_manager.dart';
import 'package:jsonschema/core/export/export2json_fake.dart';
import 'package:jsonschema/core/export/export2ui.dart';
import 'package:jsonschema/feature/content/json_to_ui.dart';
import 'package:jsonschema/start_core.dart';

class PanRepsonseViewer extends StatefulWidget {
  const PanRepsonseViewer({super.key, required this.apiCallInfo});
  final APICallManager apiCallInfo;

  @override
  State<PanRepsonseViewer> createState() => _PanRepsonseViewerState();
}

class _PanRepsonseViewerState extends State<PanRepsonseViewer> {
  late JsonToUi json2ui;

  @override
  void initState() {
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
    } else {
      return Container();
    }
  }
}
