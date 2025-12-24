import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:highlight/languages/json.dart';
import 'package:jsonschema/core/api/sessionStorage.dart';
import 'package:jsonschema/core/export/export2ui.dart';
import 'package:jsonschema/core/designer/core/widget_selectable.dart';
import 'package:jsonschema/feature/content/json_to_ui.dart';
import 'package:jsonschema/feature/content/pan_to_ui.dart';
import 'package:jsonschema/feature/content/widget/widget_content_helper.dart';
import 'package:jsonschema/feature/transform/pan_response_viewer.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/widget/widget_expansive.dart';
import 'package:jsonschema/widget/widget_float_dialog.dart';

typedef GetChild = List<Widget> Function(String pathData);

class WidgetContentForm extends StatefulWidget {
  const WidgetContentForm({
    super.key,
    required this.children,
    required this.info,
    required this.ctx,
  });
  final GetChild children;
  final WidgetConfigInfo info;
  final UIParamContext ctx;

  @override
  State<WidgetContentForm> createState() => _WidgetContentFormState();
}

class _WidgetContentFormState extends State<WidgetContentForm>
    with NameMixin, WidgetUIHelper {
  late ScrollController aScrollController;

  @override
  void initState() {
    widget.info.json2ui.stateMgr.addContainer(widget.info.pathValue!, this);

    aScrollController = ScrollController(initialScrollOffset: 0.0);

    aScrollController.addListener(() {
      if (aScrollController.position.pixels >=
          aScrollController.position.maxScrollExtent - 100) {
        if (initial < max) {
          setState(() {
            initial = min(initial + delta, max);
          });
        }
      }
    });

    super.initState();
  }

  @override
  void dispose() {
    aScrollController.dispose();
    widget.info.json2ui.stateMgr.removeContainer(widget.info.pathValue!);
    super.dispose();
  }

  String getPathValue() {
    var pathValue = widget.info.pathValue!.replaceAll("/$cstAnyChoice", '');
    return pathValue;
  }

  final delta = 2;
  int max = 0;
  int initial = 5;
  dynamic data;
  List<Widget> childrenByRowOfN = [];
  CodeEditorConfig? jsonViewerConf;

  String prettyPrintJson(dynamic input) {
    //const JsonDecoder decoder = JsonDecoder();
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(input);
  }

  @override
  Widget build(BuildContext context) {
    var pathValue = getPathValue();
    var pathGeneric = replaceAllIndexes(pathValue);
    var configBloc = widget.info.json2ui.stateMgr.config;
    List<ConfigLink> links = [];
    if (configBloc != null) {
      for (var e in configBloc.links) {
        if (e.onPath == pathGeneric) links.add(e);
      }
    }

    var dataContainer = widget.info.json2ui.getStateContainer(
      widget.info.pathData!,
    );
    var mapData = dataContainer?.jsonData;
    if (mapData != data || data == null || widget.info.name != 'root') {
      data = mapData;
      if (data != null) {
        initial = 5;
      }
      childrenByRowOfN = widget.children(pathValue);

      if (widget.ctx.parentType == WidgetType.root) {
        if (jsonViewerConf == null) {
          jsonViewerConf = CodeEditorConfig(
            mode: json,
            getText: () {
              var dataContainer = widget.info.json2ui.getStateContainer(
                widget.info.pathData!,
              );
              var mapData = dataContainer?.jsonData;
              return prettyPrintJson(mapData);
            },
            onChange: (onChange, config) {},
            notifError: ValueNotifier(""),
          );
        } else {
          SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
            jsonViewerConf!.repaintCode();
          });
        }
      }
    } else {
      print("no reload chidren on infinite scroll");
    }

    max = childrenByRowOfN.length;

    List<Widget> listLinkBtn =
        links.map((e) {
          return ElevatedButton(
            style: ButtonStyle(
              minimumSize: WidgetStateProperty.all(Size(64, 26)),
              padding: WidgetStateProperty.all(
                EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              ),
            ),
            onPressed: () async {
              var pages = await loadDataSource("all", false);
              BrowseSingle().browse(pages, false);
              var attr = pages.mapInfoByName[e.toDatasrc];
              if (attr?.isNotEmpty ?? false) {
                PageData pageData = PageData(
                  data: widget.info.json2ui.stateMgr.data,
                  path: pathValue,
                );

                sessionStorage.put('${pageData.hashCode}', pageData);
                // ignore: use_build_context_synchronously
                context.push(
                  Pages.appPage.param(
                    attr!.first.masterID!,
                    "param=${pageData.hashCode}",
                  ),
                );
              }
            },
            child: Text(e.title),
          );
        }).toList();

    var headers = <Widget>[
      Text(camelCaseToWordsCapitalized(widget.info.name)),
      SizedBox(width: 10),
      ...listLinkBtn,
      Spacer(),
      if (widget.ctx.parentType == WidgetType.root)
        InkWell(
          onTap: () async {
            // view data
            Size size = MediaQuery.of(context).size;
            double width = size.width * 0.4;
            double height = size.height * 0.8;

            showFloatingNotification(
              context,
              Offset(50, 100),
              Size(width, height),
              TextEditor(config: jsonViewerConf!, header: "json"),
            );
          },
          child: Icon(Icons.data_object), //settings
        ),

      if (widget.ctx.parentType == WidgetType.root)
        InkWell(
          onTap: () async {
            widget.info.json2ui.showConfigPanDialog(context);
          },
          child: Icon(Icons.account_tree_outlined), //settings
        ),

      InkWell(
        onTap: () async {
          if (widget.info.onTapSetting != null) {
            widget.info.onTapSetting!();
          }
        },
        child: Icon(Icons.tune), //settings
      ),
    ];

    bool inifiniScroll = true;
    bool isRootWithScroll = widget.info.name == 'root';

    if (isRootWithScroll && widget.info.json2ui is PanToUi) {
      PanToUi ui = widget.info.json2ui as PanToUi;
      isRootWithScroll = ui.withScroll;
    }

    Widget cachableWidget;

    if (widget.info.panInfo != null &&
        widget.info.panInfo!.subtype == 'RowDetail') {
      cachableWidget = Column(
        spacing: 5,
        mainAxisSize: MainAxisSize.max,
        children: [...childrenByRowOfN, SizedBox(height: 1)],
      );
    } else if (isRootWithScroll && inifiniScroll) {
      // avec infini scroll sur le root

      data = dataContainer?.jsonData;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (aScrollController.position.maxScrollExtent == 0 && initial != max) {
          setState(() {
            // augmente le nb element si pas d'ascenceur avec le initial
            initial = min(initial + delta, max);
          });
        }
      });

      cachableWidget = Column(
        children: [
          Container(
            color: Colors.lightBlueAccent.shade700,
            child: Row(
              spacing: 10,
              children: [Icon(Icons.auto_awesome_mosaic_rounded), ...headers],
            ),
          ),
          Expanded(
            child: ListView.builder(
              primary: false,
              scrollDirection: Axis.vertical,
              controller: aScrollController,
              shrinkWrap: true,
              itemCount: min(initial, max),
              itemBuilder: (context, index) {
                return childrenByRowOfN[index];
              },
            ),
          ),
        ],
      );
    } else {
      // sans infini scroll
      Widget w = WidgetExpansive(
        color: Colors.grey.shade700,
        headers: headers,
        child: Column(
          spacing: 5,
          mainAxisSize: MainAxisSize.max,
          children: [...childrenByRowOfN, SizedBox(height: 1)],
        ),
      );

      if (isRootWithScroll) {
        w = SingleChildScrollView(child: w);
      }

      cachableWidget = WidgetSelectable(
        withDragAndDrop: false,
        slotConfig: null,
        panInfo: widget.info.panInfo,
        child: w,
      );
    }

    return cachableWidget;
  }
}
