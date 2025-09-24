import 'package:flutter/material.dart';
import 'package:jsonschema/feature/content/widget/widget_content_form.dart';
import 'package:jsonschema/feature/content/widget/widget_content_helper.dart';
import 'package:jsonschema/widget/widget_expansive.dart';

typedef GetChildRow =
    Widget Function(
      String pathData,
      dynamic data,
      int idx,
      Key? k,
      Function onDelete,
    );

class WidgetContentArray extends StatefulWidget {
  const WidgetContentArray({
    super.key,
    required this.getRow,
    required this.info,
    required this.children,
  });
  final GetChildRow getRow;
  final WidgetConfigInfo info;
  final GetChild children;

  @override
  State<WidgetContentArray> createState() => _WidgetContentArrayState();
}

class _WidgetContentArrayState extends State<WidgetContentArray> {
  @override
  void initState() {
    widget.info.json2ui.stateMgr.addContainer(widget.info.pathValue!, this);
    super.initState();
  }

  @override
  void dispose() {
    widget.info.json2ui.stateMgr.removeContainer(widget.info.pathValue!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var dataContainer = widget.info.json2ui.getState(widget.info.pathData!);
    List? items;
    if (dataContainer != null) {
      items = dataContainer.jsonData[widget.info.name];
    }

    List<Widget> children = [];
    if (items != null) {
      for (var i = 0; i < items.length; i++) {
        children.add(
          widget.getRow(widget.info.pathValue!, items[i], i, null, () {
            setState(() {
              items!.removeAt(i);
            });
          }),
        );
      }
      // bouton d'ajout
      var addWidget = SizedBox(
        height: 30,
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  dynamic newRow = {};
                  var key = '${widget.info.pathValue}[0]';
                  var template =
                      widget.info.json2ui.stateMgr.stateTemplate[key];
                  if (template != null) {
                    newRow = getValueFromPath(
                      widget.info.json2ui.stateMgr.dataEmpty,
                      key.substring(1),
                    );
                  } else {
                    // si tableau de String
                    newRow = '';
                  }

                  items?.add(newRow);
                  final currentPath =
                      '${widget.info.pathValue}[${items!.length - 1}]';
                  widget.info.json2ui.loadDataInContainer(
                    newRow,
                    pathData: currentPath,
                  );
                });
              },
              child: Container(
                width: 50,
                color: Colors.blue,
                child: Center(child: Icon(Icons.add_circle_outline)),
              ),
            ),
            Spacer(),
          ],
        ),
      );
      children.add(addWidget);
    }

    return WidgetExpansive(
      //key : ValueKey(widget.info.pathValue!),
      color: Colors.blue,
      headers: [
        Text(widget.info.name),
        Spacer(),
        InkWell(
          onTap: () async {
            if (widget.info.onTapSetting != null) {
              widget.info.onTapSetting!();
            }
          },
          child: Icon(Icons.tune), //settings
        ),
      ],
      child: Column(
        spacing: 5,
        mainAxisSize: MainAxisSize.max,
        children: [...children, SizedBox(height: 1)],
      ),
    );
  }

  dynamic getValueFromPath(Map<String, dynamic> json, String path) {
    final regex = RegExp(r'([^[.\]]+)|\[(\d+)\]');
    dynamic current = json;

    for (final match in regex.allMatches(path)) {
      final key = match.group(1);
      final index = match.group(2);

      if (key != null) {
        if (current is Map<String, dynamic>) {
          current = current[key];
        } else {
          throw Exception('Clé "$key" introuvable dans un objet non-map');
        }
      } else if (index != null) {
        final i = int.parse(index);
        if (current is List) {
          current = current[i];
        } else {
          throw Exception('Index [$i] utilisé sur un objet non-liste');
        }
      }
    }

    return current;
  }
}
