import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/core/transform/engine.dart';
import 'package:jsonschema/core/transform/transform_registry.dart';
import 'package:jsonschema/pages/content/content_map_page_detail.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';

class WidgetMapping extends StatefulWidget {
  const WidgetMapping({
    super.key,
    required this.listMapping,
    required this.onChange,
  });

  final List<MappingInfo> listMapping;
  final Function onChange;

  @override
  State<WidgetMapping> createState() => WidgetMappingState();
}

class WidgetMappingState extends State<WidgetMapping> with WidgetHelper {
  @override
  Widget build(BuildContext context) {
    return getListMappingWidget();
  }

  ValueNotifier<int> valueListenable = ValueNotifier(0);

  Widget getListMappingWidget() {
    TransformRegistry.init();

    return ValueListenableBuilder(
      valueListenable: valueListenable,
      builder: (context, value, child) {
        return ReorderableListView.builder(
          itemCount: widget.listMapping.length,
          itemBuilder: (context, index) {
            GlobalKey k = GlobalKey();
            var mapping = widget.listMapping[index];
            List<Widget> transformWidgets = [];
            for (var m in mapping.transforms) {
              var type = m['name'];
              TransformAction? transform =
                  TransformRegistry.availableTransforms[type];
              Widget? info = transform?.getInfo.call(null, m);
              transformWidgets.add(
                info ?? Text('No info available for this transform'),
              );
            }
            if (transformWidgets.isEmpty) {
              transformWidgets.add(Text('No transform'));
            }

            return Row(
              key: ObjectKey(mapping),
              spacing: 20,
              children: [
                GestureDetector(
                  key: k,
                  child: Icon(Icons.more_vert, size: 20),
                  onTap: () {
                    openAction(context, index, k);
                  },
                ),
                Text(mapping.pathSrc?.info.name ?? 'Not mapped'),
                Icon(Icons.arrow_right_alt),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      openTransform(context, mapping);
                    },
                    child: Container(
                      color: Colors.blue.withAlpha(128),
                      child: Row(
                        spacing: 10,
                        children: [
                          Row(spacing: 5, children: transformWidgets),
                          Icon(Icons.settings, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
                Icon(Icons.arrow_right_alt),
                Text(mapping.pathDest?.info.name ?? 'Not mapped'),
              ],
            );
          },
          onReorder: (int oldIndex, int newIndex) {
            if (newIndex > oldIndex) {
              newIndex -= 1;
            }
            var item = widget.listMapping.removeAt(oldIndex);
            widget.listMapping.insert(newIndex, item);
            widget.onChange();
            valueListenable.value++;
          },
        );
      },
    );
  }

  void openAction(
    BuildContext context,
    int idx,
    GlobalKey<State<StatefulWidget>> k,
  ) {
    BuildContext? bCtx;
    List<Widget> listWidget = [
      ListTile(
        leading: Icon(Icons.delete),
        title: Text('Delete'),
        onTap: () {
          if (bCtx != null) Navigator.pop(bCtx!);
          widget.listMapping.removeAt(idx);
          setState(() {});
          widget.onChange();
        },
      ),
    ];

    dialogBuilderBelow(
      context,
      SizedBox(width: 110, height: 220, child: Column(children: listWidget)),
      k,
      Offset(-40, -20),
      (BuildContext ctx) {
        bCtx = ctx;
      },
    );
  }

  Map<String, dynamic>? currentTransformConfig;

  void openTransform(BuildContext ctx, MappingInfo mapping) async {
    ValueNotifier<int> valueChangeListenable = ValueNotifier(0);
    ValueNotifier<int> displayListenable = ValueNotifier(0);

    await showDialog(
      context: ctx,
      builder: (context) {
        Size size = MediaQuery.of(ctx).size;
        double width = size.width * 0.9;
        double height = size.height * 0.8;

        return AlertDialog(
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Close'),
            ),
          ],
          content: SizedBox(
            width: width,
            height: height,
            child: Row(
              children: [
                getListTransformAvailable(context),
                VerticalDivider(),
                getListTransform(
                  valueChangeListenable,
                  displayListenable,
                  mapping,
                ),
                VerticalDivider(),
                Expanded(
                  child: Column(
                    children: [
                      Text('Transform config'),
                      getWidgetConfigTransform(
                        valueChangeListenable,
                        displayListenable,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    widget.onChange();
    setState(() {});
  }

  ValueListenableBuilder<int> getWidgetConfigTransform(
    ValueNotifier<int> valueChangeListenable,
    ValueNotifier<int> displayListenable,
  ) {
    return ValueListenableBuilder(
      valueListenable: displayListenable,
      builder: (context, value, child) {
        if (currentTransformConfig == null) {
          return Text('Select a transform to display config');
        }
        var type = currentTransformConfig!['name'];
        TransformAction? transform =
            TransformRegistry.availableTransforms[type];
        Widget? form = transform?.getForm?.call(
          null,
          currentTransformConfig!,
          valueChangeListenable,
        );
        return form ?? Text('No config available for this transform');
      },
    );
  }

  Widget getListTransform(
    ValueNotifier<int> valueChangeListenable,
    ValueNotifier<int> displayListenable,
    MappingInfo mapping,
  ) {
    return SizedBox(
      width: 400,
      child: Column(
        spacing: 20,
        children: [
          Text('Current transforms'),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: valueChangeListenable,
              builder: (context, value, child) {
                return ReorderableListView(
                  shrinkWrap: true,
                  onReorder: (int oldIndex, int newIndex) {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    if (newIndex >= mapping.transforms.length) {
                      newIndex -= 1;
                    }
                    if (mapping.transforms.length <= oldIndex ||
                        mapping.transforms.length <= newIndex) {
                      return;
                    }
                    var item = mapping.transforms.removeAt(oldIndex);
                    mapping.transforms.insert(newIndex, item);
                    valueChangeListenable.value++;
                  },
                  children: [
                    ...mapping.transforms.map((t) {
                      return ListTile(
                        onTap: () {
                          // display transform config
                          displayListenable.value++;
                          currentTransformConfig = t;
                        },
                        key: ObjectKey(t),
                        title: Text(t['name']),
                        subtitle: Text(t['\$options'] ?? 'no options'),
                        leading: IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () {
                            mapping.transforms.remove(t);
                            valueChangeListenable.value++;
                          },
                        ),
                      );
                    }),
                    getAddTransform(mapping, valueChangeListenable),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget getAddTransform(
    MappingInfo mapping,
    ValueNotifier<int> valueChangeListenable,
  ) {
    return DragTarget<TransformAction>(
      key: ObjectKey('addTransform'),
      builder: (context, candidateData, rejectedData) {
        final isActive = candidateData.isNotEmpty;
        return SizedBox(
          width: double.infinity,
          child: DottedBorder(
            options: RectDottedBorderOptions(
              color: Colors.grey,
              dashPattern: isActive ? [2, 2] : [5, 5],
              strokeWidth: 1,
            ),
            child: Text(
              'Drag transform here',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        );
      },
      onWillAcceptWithDetails: (details) {
        return true;
      },
      onAcceptWithDetails: (data) {
        print('Accept transform: ${data.data}');
        mapping.transforms.add({
          'name': data.data.info.type,
          //'options': 'no option', // TODO add config UI for transform options
          'args': {},
        });
        valueChangeListenable.value++;
      },
    );
  }

  SizedBox getListTransformAvailable(BuildContext context) {
    return SizedBox(
      width: 250,
      child: ListView(
        shrinkWrap: true,
        children: [
          Text('Available transforms'),
          ...TransformRegistry.getAllTransformsInfo().map((e) {
            TransformAction transform = e['info'] as TransformAction;
            var listTile = Material(
              color: Colors.transparent,
              child: ListTile(
                dense: true,
                title: Text(e['name'] as String),
                subtitle: transform.getTypeWidget(),
                trailing: Icon(Icons.drag_indicator),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {});
                },
              ),
            );
            return Draggable(
              dragAnchorStrategy: pointerDragAnchorStrategy,
              data: transform,
              feedback: Container(
                color: Colors.black38,
                width: 250,
                child: listTile,
              ),
              child: listTile,
            );
          }),
        ],
      ),
    );
  }
}
