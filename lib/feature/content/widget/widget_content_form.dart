import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:highlight/languages/json.dart';
import 'package:jsonschema/feature/content/widget/widget_content_helper.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/widget/widget_expansive.dart';
import 'package:jsonschema/widget/widget_float_dialog.dart';

typedef GetChild = List<Widget> Function(String pathData);

class WidgetContentForm extends StatefulWidget {
  const WidgetContentForm({
    super.key,
    required this.children,
    required this.info,
  });
  final GetChild children;
  final WidgetConfigInfo info;

  @override
  State<WidgetContentForm> createState() => _WidgetContentFormState();
}

class _WidgetContentFormState extends State<WidgetContentForm> {
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
            print("eeee");
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
    var pathValue = widget.info.pathValue!.replaceAll("/##__choise__##", '');
    return pathValue;
  }

  final delta = 2;
  int max = 0;
  int initial = 5;
  dynamic data;
  List<Widget> childrenByRowOfN = [];

  CodeEditorConfig? conf;

  String prettyPrintJson(dynamic input) {
    //const JsonDecoder decoder = JsonDecoder();
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(input);
  }

  @override
  Widget build(BuildContext context) {
    var pathValue = getPathValue();
    var dataContainer = widget.info.json2ui.getState(widget.info.pathData!);
    var mapData = dataContainer?.jsonData;
    if (mapData != data || data == null || widget.info.name != 'root') {
      data = mapData;
      if (data != null) {
        initial = 5;
      }
      childrenByRowOfN = widget.children(pathValue);

      if (widget.info.name == 'root') {
        if (conf == null) {
          conf = CodeEditorConfig(
            mode: json,
            getText: () {
              return prettyPrintJson(data);
            },
            onChange: (onChange, config) {},
            notifError: ValueNotifier(""),
          );
        } else {
          SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
            conf!.repaintCode();
          });
        }
      }
    } else {
      print("no reload chidren on infinite scroll");
    }

    max = childrenByRowOfN.length;

    var headers = <Widget>[
      Text(widget.info.name),
      Spacer(),
      if (widget.info.name == 'root')
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
              TextEditor(config: conf!, header: "json"),
            );
          },
          child: Icon(Icons.data_object), //settings
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

    if (widget.info.name == 'root' && inifiniScroll) {
      data = dataContainer?.jsonData;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (aScrollController.position.maxScrollExtent == 0 && initial != max) {
          setState(() {
            // augmente le nb element si pas d'ascenceur avec le initial
            initial = min(initial + delta, max);
          });
        }
      });

      return Column( 
        children: [
          Container(
            color: Colors.grey.shade700,
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
      Widget w = WidgetExpansive(
        color: Colors.grey.shade700,
        headers: headers,
        child: Column(
          spacing: 5,
          mainAxisSize: MainAxisSize.max,
          children: [...childrenByRowOfN, SizedBox(height: 1)],
        ),
      );

      if (widget.info.name == 'root') {
        w = SingleChildScrollView(child: w);
      }

      return w;
    }
  }
}
