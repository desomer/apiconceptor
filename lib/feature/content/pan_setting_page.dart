import 'package:flutter/material.dart';
import 'package:jsonschema/core/export/export2ui.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/feature/content/pan_browser.dart';
import 'package:jsonschema/feature/content/json_to_ui.dart';
import 'package:jsonschema/feature/content/pan_to_ui.dart';
import 'package:jsonschema/feature/content/state_manager.dart';

class PanSettingPage extends StatefulWidget {
  const PanSettingPage({super.key, required this.state});
  final StateManager state;

  @override
  State<PanSettingPage> createState() => _PanSettingPageState();
}

class _PanSettingPageState extends State<PanSettingPage> {
  ValueNotifier<String> selectedPan = ValueNotifier("");
  ValueNotifier<int> rootPan = ValueNotifier(0);

  @override
  Widget build(BuildContext context) {
    // var data =
    //     widget.state.jsonUI ?? widget.state.dataEmpty ?? widget.state.data;

    // var ctx = PanContext(name: '', level: 0, path: '')..data = data;
    // var browser = BrowserPan();
    // browser.browseAttr(ctx, '', 'root');

    PanContext ctx = widget.state.browser.rootContext!;
    int nb = ctx.listPanOfJson.length;

    var pans = ValueListenableBuilder(
      valueListenable: rootPan,
      builder: (context, value, child) {
        return ReorderableListView.builder(
          buildDefaultDragHandles: false,
          shrinkWrap: true,
          itemCount: nb,
          itemBuilder: (context, index) {
            ValueNotifier<int> aPanChanger = ValueNotifier(0);

            return ValueListenableBuilder(
              key: ValueKey(ctx.listPanOfJson[index].attrName),
              valueListenable: aPanChanger,
              builder: (context, value, child) {
                return getPan(ctx.listPanOfJson[index], aPanChanger);
              },
            );
          },
          onReorder: (int oldIndex, int newIndex) {
            if (newIndex > oldIndex) newIndex -= 1;
            final item = ctx.listPanOfJson.removeAt(oldIndex);
            ctx.listPanOfJson.insert(newIndex, item);
            rootPan.value++;
          },
        );
      },
    );

    var inputs = ValueListenableBuilder(
      valueListenable: selectedPan,
      builder: (context, value, child) {
        var pan = widget.state.browser.mapPanByPath[value];
        if (pan == null) {
          return const Text("No pan selected");
        } else {
          return ReorderableListView.builder(
            shrinkWrap: true,
            buildDefaultDragHandles: true,
            itemCount: pan.children.length,
            itemBuilder: (context, index) {
              return ListTile(
                key: ValueKey(pan.children[index].attrName),
                title: Row(
                  spacing: 10,
                  children: [
                    Text(pan.children[index].attrName),
                    //Text(pan.children[index].pathDataInTemplate),
                  ],
                ),
              );
            },
            onReorder: (int oldIndex, int newIndex) {
              if (newIndex > oldIndex) newIndex -= 1;
              final item = pan.children.removeAt(oldIndex);
              pan.children.insert(newIndex, item);
              selectedPan.value = selectedPan.value.toString();
            },
          );
        }
      },
    );

    return Column(
      children: [
        // ElevatedButton(
        //   onPressed: () {
        //     showPreviewDialog(context, ctx);
        //   },
        //   child: Text('Show preview'),
        // ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Flexible(child: pans), Flexible(child: inputs)],
          ),
        ),
      ],
    );
  }

  Widget getPan(PanInfoObject panParent, ValueNotifier<int> changer) {
    List<PanInfoObject> childrenPan =
        panParent.children.whereType<PanInfoObject>().toList();

    if (panParent.isInvisible) {
      return Container();
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      buildDefaultDragHandles: false,
      itemCount: childrenPan.length,
      itemBuilder: (context, index) {
        Widget row;
        var left = 25.0;
        var childPan = childrenPan[index];

        if (childPan.isInvisible) {
          return Container(key: ValueKey(childPan.attrName));
        }

        if (['Panel', 'Array'].contains(childPan.type)) {
          var name = childPan.attrName;

          if (childPan.subtype == "RowDetail") {
            if (childrenPan.length == 1) {
              name = 'Row Detail';
            } else {
              // any
              var anyInfo = childPan.dataJsonSchema[cstProp] as AttributInfo;
              name = anyInfo.name;
              childPan.anyChoise = true;
            }
          }

          Color aColor = Colors.blue;
          if (childPan.type == 'Array') {
            aColor = Colors.deepOrangeAccent;
          }
          if (childPan.anyChoise) {
            aColor = Colors.blueGrey;
          }

          row = Container(
            decoration: BoxDecoration(border: Border.all(), color: aColor),
            child: Row(
              spacing: 10,
              children: [
                Text(name),
                Text(childPan.type),
                //Text("[${childPan.subtype}]"),
                //Text(childrenPan[index].pathDataInTemplate),
              ],
            ),
          );
        } else if (childPan.type == 'Bloc') {
          if (childPan.pathPanVisible == null) {
            // pas d'enfant visible
            return Container(key: ValueKey(childPan.attrName));
          }

          row = Container(
            decoration: BoxDecoration(border: Border.all()),
            child: InkWell(
              onTap: () {
                selectedPan.value =
                    '${childPan.pathDataInTemplate}@${childPan.attrName}';
              },
              child: Row(children: [Text('${childPan.nbInput} inputs')]),
            ),
          );
        } else {
          // Row
          left = 0;
          if (panParent.type == 'PrimitiveArray') {
            // row de string, etc..
            row = Container(); // pas de bloc row
          } else if (childPan.type == 'PrimitiveArray') {
            String nameAttrInRow =
                ((childPan.children.first as PanInfoObject).children.first
                        as PanInfoObject)
                    .children
                    .first
                    .attrName;
            row = Container(
              decoration: BoxDecoration(
                border: Border.all(),
                color: Colors.deepOrangeAccent,
              ),
              child: Row(
                spacing: 10,
                children: [Text(nameAttrInRow), Text('Array')],
              ),
            );
          } else {
            row = Container(
              decoration: BoxDecoration(
                border: Border.all(),
                color: Colors.lightBlueAccent,
              ),
              child: Row(spacing: 10, children: [Text(childPan.type)]),
            );
          }
        }

        ValueNotifier<int> aPanChanger = ValueNotifier(0);

        var reorderBtn = ReorderableDragStartListener(
          index: index,
          child: Container(
            height: 21,
            width: 25,
            color: Colors.grey,
            child: Icon(Icons.drag_handle),
          ),
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          key: ValueKey(childPan.attrName),
          children: [
            if (panParent.type != 'PrimitiveArray' &&
                childrenPan.length > 1 &&
                !childPan.anyChoise)
              reorderBtn,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  row,
                  Padding(
                    padding: EdgeInsets.only(left: left),
                    child: ValueListenableBuilder(
                      key: ValueKey(childPan.attrName),
                      valueListenable: aPanChanger,
                      builder: (context, value, child) {
                        return getPan(childPan, aPanChanger);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      onReorder: (int oldIndex, int newIndex) {
        if (newIndex > oldIndex) newIndex -= 1;
        final item = panParent.children.removeAt(oldIndex);
        panParent.children.insert(newIndex, item);
        changer.value++;
      },
    );
  }

  Future<void> showPreviewDialog(
    BuildContext ctx,
    PanContext panContext,
  ) async {
    var ui = PanToUi(state: this, withScroll: true);
    ui.loadData(widget.state.data);

    return showDialog<void>(
      context: ctx,
      barrierDismissible: true, // user must tap button!
      builder: (BuildContext context) {
        Size size = MediaQuery.of(ctx).size;
        double width = size.width * 0.9;
        double height = size.height * 0.8;

        var w =
            ui.getWidgetTyped(
              panContext.listPanOfJson.first,
              WidgetType.root,
              "",
              [],
            )!;

        return AlertDialog(
          content: SizedBox(
            width: width,
            height: height,
            child: SingleChildScrollView(child: w.widget),
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
