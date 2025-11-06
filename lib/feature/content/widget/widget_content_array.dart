import 'package:flutter/material.dart';
import 'package:jsonschema/feature/content/json_to_ui.dart';
import 'package:jsonschema/feature/content/widget/widget_content_form.dart';
import 'package:jsonschema/feature/content/widget/widget_content_helper.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/widget_expansive.dart';
import 'package:jsonschema/widget/widget_tag_selector.dart';

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
    required this.ctx,
  });
  final GetChildRow getRow;
  final WidgetConfigInfo info;
  final GetChild children;
  final UIParamContext ctx;

  @override
  State<WidgetContentArray> createState() => _WidgetContentArrayState();
}

class _WidgetContentArrayState extends State<WidgetContentArray>
    with WidgetUIHelper {
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
    print(
      'Array path value ${widget.info.pathValue}   path data ${widget.info.pathData}',
    );

    var dataContainer = widget.info.json2ui.getState(widget.info.pathData!);
    List? items;
    if (dataContainer != null) {
      items = dataContainer.jsonData[widget.info.name];
    }

    var key = '${widget.info.pathValue}[0]';
    var template = widget.info.json2ui.stateMgr.stateTemplate[key];
    if ((template == null && widget.info.panInfo == null) ||
        widget.info.panInfo?.type == 'PrimitiveArray') {
      // de type tableau de String, int, double, bool
      var i =
          WidgetConfigInfo(json2ui: widget.info.json2ui, name: widget.info.name)
            ..inArrayValue = true
            ..setPathValue(widget.info.pathValue!)
            ..setPathData(widget.info.pathValue!)
            ..panInfo = widget.info.panInfo;

      var v = getInputDesc(i);

      if (v.choiseItem != null) {
        // template non défini donc tableau de String, Bool, int, double
        return Padding(
          padding: EdgeInsetsGeometry.all(10),
          child: Row(
            spacing: 20,
            children: [
              Text(widget.info.name),
              TagSelector(
                key: ObjectKey(items),
                availableTags: v.choiseItem!,
                initialSelected: [],
                accessor: InfoAccess(initialSelected: items!),
              ),
              Spacer(),
            ],
          ),
        );
      }
    }

    List<Widget> children = [];

    if (items != null) {
      for (var i = 0; i < items.length; i++) {
        // recupération des données
        children.add(
          widget.getRow(widget.info.pathValue!, items[i], i, null, () {
            setState(() {
              items!.removeAt(i);
            });
          }),
        );
      }
    }
    if (widget.ctx.layoutArray!.nbRowPerPage > 0) {
      double nextPreview = 20.0;

      Widget scroll = SizedBox(
        height: (widget.ctx.layoutArray!.nbRowPerPage * 47) + nextPreview,
        child: SingleChildScrollView(
          primary: false,
          child: Column(children: children),
        ),
      );
      children = [scroll];
    }

    // bouton d'ajout
    SizedBox addWidget = getAddBtn(items);
    children.add(addWidget);

    return WidgetExpansive(
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

  SizedBox getAddBtn(List<dynamic>? items) {
    // bouton d'ajout
    var addWidget = SizedBox(
      height: 30,
      child: Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  dynamic newRow = {};
                  var key = '${widget.info.pathValue}[0]';
                  var template =
                      widget.info.json2ui.stateMgr.stateTemplate[key];
                  if (template != null) {
                    newRow = getNewRowFromPath(
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
                  widget.info.json2ui.stateMgr.loadDataInContainer(
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
          ),
          Spacer(),
        ],
      ),
    );
    return addWidget;
  }

  dynamic getNewRowFromPath(Map<String, dynamic> json, String path) {
    final regex = RegExp(r'([^/\[\]]+)|\[(\d+)\]');
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

class InfoAccess extends ValueAccessor {
  final List initialSelected;

  InfoAccess({required this.initialSelected});

  @override
  dynamic get() {
    return initialSelected;
  }

  @override
  String getName() {
    return "";
  }

  @override
  bool isEditable() {
    return true;
  }

  @override
  void remove() {}

  @override
  void set(value) {
    initialSelected.clear();
    initialSelected.addAll(value);
  }
}
