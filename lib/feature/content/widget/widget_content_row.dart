import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:jsonschema/feature/content/json_to_ui.dart';
import 'package:jsonschema/feature/content/widget/widget_content_helper.dart';
import 'package:jsonschema/pages/apps/data_sources_link_viewer.dart';
import 'package:jsonschema/pages/router_config.dart' show Pages;

class WidgetContentRow extends StatefulWidget {
  const WidgetContentRow({
    super.key,
    required this.ctxRow,
    required this.info,
    required this.rowIdx,
  });

  final UIParamContext ctxRow;
  final WidgetConfigInfo info;
  final int rowIdx;

  @override
  State<WidgetContentRow> createState() => _WidgetContentRowState();
}

class _WidgetContentRowState extends State<WidgetContentRow> {
  @override
  Widget build(BuildContext context) {
    var value = widget.ctxRow.data;

    List<Widget> cells = [];
    addCell(
      cells,
      widget.info.pathData!,
      widget.info.pathValue!,
      widget.info.name,
      value,
      0,
    );

    cells.add(
      ElevatedButton.icon(
        icon: Icon(Icons.arrow_circle_right_outlined),
        onPressed: () {
          var w = widget.info.json2ui.getFormOfRow(
            widget.ctxRow.infoTemplate?.anyOf ?? false,
            widget.rowIdx,
            widget.ctxRow,
            widget.info.panInfo,
          );
          String key = '${w.hashCode}';
          cacheLinkPage.put(key, w);
          context.push(Pages.appPageDetail.id(key));

          //showDetailDialog(w, context);
        },
        label: Text('View'),
      ),
    );

    return Row(spacing: 10, children: cells);
  }

  int addCell(
    List<Widget> cells,
    String pathData,
    String pathValue,
    String name,
    dynamic v,
    int i,
  ) {
    if (i > 5) return i;

    if (v is Map) {
      v.forEach((key, value) {
        // les attributs d'un objet
        if (value is Map) {
          i = addCell(
            cells,
            '$pathData/$key',
            '$pathValue/$key',
            key,
            value,
            i,
          );
        } else {
          i++;
          i = addCell(cells, pathData, '$pathValue/$key', key, value, i);
        }
      });
    } else if (v is List) {
    } else {
      var ctxCell = widget.ctxRow.clone(
        aAttrName: name,
        aPath: pathValue,
        aPathData: pathData,
      )..data = v;

      cells.add(
        Flexible(
          child:
              widget.info.json2ui
                  .getObjectInput(
                    widget.info.json2ui,
                    widget.info.panInfo,
                    ctxCell,
                  )
                  .widget,
        ),
      );
    }

    return i;
  }

  Future<void> showDetailDialog(Widget detail, BuildContext ctx) async {
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
            child: SingleChildScrollView(
              primary: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(title: Text('Row details')),
                  Container(color: Colors.black, child: detail),
                ],
              ),
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
}
