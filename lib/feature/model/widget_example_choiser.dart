import 'package:flutter/material.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';

// ignore: must_be_immutable
class ExampleManager extends StatelessWidget {
  String? jsonFake;
  String? nameExample;
  int? selectedIdx;
  List<dynamic>? examples;
  Function? onSelect;
  Function? onBeforeSave;
  ValueNotifier<int> onChangeExample = ValueNotifier(0);

  ExampleManager({super.key});

  List<Widget> getManageExample(BuildContext context) {
    return [
      TextButton.icon(
        icon: Icon(Icons.loupe),
        onPressed: () {
          showExampleDialog(context);
        },
        label: Text('Manage examples'),
      ),
      ValueListenableBuilder(
        valueListenable: onChangeExample,
        builder: (context, value, child) {
          if (nameExample == null) return Container();
          return TextButton.icon(
            icon: Icon(Icons.save),
            onPressed: () {
              if (onBeforeSave != null) {
                onBeforeSave!();
              }
              ModelAccessorAttr access = getAccessor();
              examples![selectedIdx!]['json'] = jsonFake;
              access.set(examples);
            },
            label: Text('Save example $nameExample'),
          );
        },
      ),
    ];
  }

  Future<void> showExampleDialog(BuildContext ctx) async {
    ModelAccessorAttr access = getAccessor();
    examples = access.get();
    examples ??= [];

    return showDialog<void>(
      context: ctx,
      barrierDismissible: true, // user must tap button!
      builder: (BuildContext context) {
        Size size = MediaQuery.of(ctx).size;
        double width = 500;
        double height = size.height * 0.8;
        return AlertDialog(
          content: SizedBox(
            width: width,
            height: height,
            child: DraggableEditableList(
              json: jsonFake!,
              initialItems: examples!,
              onChanged: (updatedList) {
                access.set(updatedList);
                clearSelected();
              },
              onLoad: (List<Map<String, dynamic>> list, int idx) {
                jsonFake = list[idx]['json'];
                nameExample = list[idx]['name'];
                selectedIdx = idx;
                onChangeExample.value++;
                onSelect!();
                Navigator.of(context).pop();
              },
              onReplace: (List<Map<String, dynamic>> list, int idx) {
                list[idx]['json'] = jsonFake;
                access.set(list);
                Navigator.of(context).pop();
              },
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

  void clearSelected() {
    selectedIdx = null;
    nameExample = null;
    onChangeExample.value++;
  }

  ModelAccessorAttr getAccessor() {
    ModelSchema model = currentCompany.currentModel!;
    var examplesNode = model.getExtendedNode("#examples");

    var access = ModelAccessorAttr(
      node: examplesNode,
      schema: model,
      propName: '#examples',
    );
    return access;
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: getManageExample(context));
  }
}

//-------------------------------------------------------------------------
class DraggableEditableList extends StatefulWidget {
  final String json;
  final List<dynamic> initialItems;
  final void Function(List<Map<String, dynamic>>) onChanged;
  final void Function(List<Map<String, dynamic>>, int idx) onLoad;
  final void Function(List<Map<String, dynamic>>, int idx) onReplace;

  const DraggableEditableList({
    super.key,
    required this.initialItems,
    required this.onChanged,
    required this.onLoad,
    required this.onReplace,
    required this.json,
  });

  @override
  State<DraggableEditableList> createState() => _DraggableEditableListState();
}

class _DraggableEditableListState extends State<DraggableEditableList> {
  late List<Map<String, dynamic>> items;

  @override
  void initState() {
    super.initState();
    items = List<Map<String, dynamic>>.from(widget.initialItems);
  }

  void _updateName(int index, String newName) {
    setState(() {
      items[index]['name'] = newName;
    });
    widget.onChanged(items);
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = items.removeAt(oldIndex);
      items.insert(newIndex, item);
    });
    widget.onChanged(items);
  }

  void _addItem() {
    setState(() {
      items.add({'name': 'new', 'json': widget.json});
    });
    widget.onChanged(items);
  }

  void _removeItem(int index) {
    setState(() {
      items.removeAt(index);
    });
    widget.onChanged(items);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _addItem,
          icon: Icon(Icons.add),
          label: Text('Add new example'),
        ),
        SizedBox(height: 12),
        ReorderableListView(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          onReorder: _onReorder,
          children: List.generate(items.length, (index) {
            return ListTile(
              key: ValueKey('item_$index'),
              title: Row(
                spacing: 5,
                children: [
                  TextButton(
                    onPressed: () {
                      widget.onLoad(items, index);
                    },
                    child: Text('Load'),
                  ),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Name example ${index + 1}',
                        border: OutlineInputBorder(),
                      ),
                      controller: TextEditingController(
                          text: items[index]['name'],
                        )
                        ..selection = TextSelection.fromPosition(
                          TextPosition(offset: items[index]['name']?.length ?? 0),
                        ),
                      onChanged: (value) => _updateName(index, value),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      widget.onReplace(items, index);
                    },
                    child: Text('Replace'),
                  ),
                ],
              ),
              trailing: IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeItem(index),
              ),
            );
          }),
        ),
      ],
    );
  }
}
