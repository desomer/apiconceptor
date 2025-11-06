import 'package:flutter/material.dart';
import 'package:jsonschema/feature/content/browser_pan.dart';
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
    var data =
        widget.state.jsonUI ?? widget.state.dataEmpty ?? widget.state.data;


    var ctx = PanContext(name: '', level: 0, path: '')..data = data;
    var browser = BrowserPan();
    browser.browseAttr(ctx, '');


    int nb = ctx.listPanOfJson.length;
    var pans = ValueListenableBuilder(
      valueListenable: rootPan,
      builder: (context, value, child) {
        return ReorderableListView.builder(
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
        var pan = browser.mapPanByPath[value];
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
                    Text(pan.children[index].pathDataInTemplate),
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
        ElevatedButton(
          onPressed: () {
            showPreviewDialog(context, ctx);
          },
          child: Text('Show preview'),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Flexible(child: pans), Flexible(child: inputs)],
          ),
        ),
      ],
    );
  }

  Widget getPan(PanInfoObject pan, ValueNotifier<int> changer) {
    List<PanInfoObject> childrenPan =
        pan.children.whereType<PanInfoObject>().toList();

    return ReorderableListView.builder(
      shrinkWrap: true,
      buildDefaultDragHandles: false,
      itemCount: childrenPan.length,
      itemBuilder: (context, index) {
        Widget row;
        var left = 25.0;

        if (['Panel', 'Array'].contains(childrenPan[index].type)) {
          var name = childrenPan[index].attrName;

          if (pan.type == "Row") {
            name = 'Content';
          }

          row = Container(
            decoration: BoxDecoration(border: Border.all(), color: Colors.blue),
            child: Row(
              spacing: 10,
              children: [
                Text(name),
                Text(childrenPan[index].type),
                Text(childrenPan[index].pathDataInTemplate),
              ],
            ),
          );
        } else if (childrenPan[index].type == 'Bloc') {
          row = Container(
            decoration: BoxDecoration(border: Border.all()),
            child: InkWell(
              onTap: () {
                selectedPan.value =
                    '${childrenPan[index].pathDataInTemplate}@${childrenPan[index].attrName}';
              },
              child: Row(
                children: [Text('${childrenPan[index].nbInput} inputs')],
              ),
            ),
          );
        } else {
          // row
          left = 0;
          if (childrenPan[index].children.length == 1 &&
              childrenPan[index].children.first is PanInfoObject &&
              (childrenPan[index].children.first as PanInfoObject).nbInput ==
                  1) {
            // row de string, etc..
            row = Container();
          } else {
            row = Container(
              decoration: BoxDecoration(
                border: Border.all(),
                color: Colors.lightBlueAccent,
              ),
              child: Row(
                spacing: 10,
                children: [
                  Text(childrenPan[index].type),
                  Text(childrenPan[index].pathDataInTemplate),
                ],
              ),
            );
          }
        }

        ValueNotifier<int> aPanChanger = ValueNotifier(0);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          key: ValueKey(childrenPan[index].attrName),
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Container(
                height: 21,
                width: 25,
                color: Colors.grey,
                child: Icon(Icons.drag_handle),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  row,
                  Padding(
                    padding: EdgeInsets.only(left: left),
                    child: ValueListenableBuilder(
                      key: ValueKey(childrenPan[index].attrName),
                      valueListenable: aPanChanger,
                      builder: (context, value, child) {
                        return getPan(childrenPan[index], aPanChanger);
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
        final item = pan.children.removeAt(oldIndex);
        pan.children.insert(newIndex, item);
        changer.value++;
      },
    );
  }

  Future<void> showPreviewDialog(
    BuildContext ctx,
    PanContext panContext,
  ) async {
    var ui = PanToUi(state: this);
    ui.loadData(widget.state.data);

    return showDialog<void>(
      context: ctx,
      barrierDismissible: true, // user must tap button!
      builder: (BuildContext context) {
        Size size = MediaQuery.of(ctx).size;
        double width = size.width * 0.9;
        double height = size.height * 0.8;

        var w =
            ui.getWidget(panContext.listPanOfJson.first, WidgetType.root, "")!;

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


