
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/widget_glowing_halo.dart';

// ignore: must_be_immutable
class ExampleManager extends StatelessWidget {
  String? jsonFake;
  String? nameExample;
  int? selectedIdx;
  List<dynamic>? examples;
  Function? onSelect;
  Function? onBeforeSave;
  ValueNotifier<int> onChangeExample = ValueNotifier(0);
  ValueNotifier<String> onChangeSizeInfo = ValueNotifier('');

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
            child: DraggableExampleList(
              onJsonChange: ValueNotifier(''),
              json: () => jsonFake!,
              initialItems: examples!,
              onItemChanged: (updatedList) {
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
class DraggableExampleList extends StatefulWidget {
  //final String json;
  final List<dynamic> initialItems;
  final void Function(List<Map<String, dynamic>>) onItemChanged;
  final void Function(List<Map<String, dynamic>>, int idx) onLoad;
  final void Function(List<Map<String, dynamic>>, int idx) onReplace;
  final String Function() json;
  final ValueNotifier<String?> onJsonChange;

  const DraggableExampleList({
    super.key,
    required this.initialItems,
    required this.onItemChanged,
    required this.onLoad,
    required this.onReplace,
    required this.json,
    required this.onJsonChange,
  });

  @override
  State<DraggableExampleList> createState() => _DraggableExampleListState();
}

class _DraggableExampleListState extends State<DraggableExampleList> {
  late List<Map<String, dynamic>> items;
  int? _selectedIndex;
  String? _selectedAction;
  String? currentJsonFake;

  @override
  void initState() {
    super.initState();
    items = List<Map<String, dynamic>>.from(widget.initialItems);
    if (items.isNotEmpty) {
      _selectedIndex = 0;
      _selectedAction = 'view';
      currentJsonFake = items[0]['json'];
      SchedulerBinding.instance.addPostFrameCallback((_) {
        widget.onLoad(items, 0);
      });
    }

    widget.onJsonChange.addListener(listener);
  }

  void listener() {
    if (_selectedAction != 'replace' &&
        (_selectedIndex != null && currentJsonFake != null) &&
        currentJsonFake != widget.onJsonChange.value) {
      _setSelection(_selectedIndex!, 'replace');
    }

    currentJsonFake = widget.onJsonChange.value;
  }

  @override
  void dispose() {
    widget.onJsonChange.removeListener(listener);
    super.dispose();
  }

  void _updateName(int index, String newName) {
    setState(() {
      items[index]['name'] = newName;
    });
    widget.onItemChanged(items);
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = items.removeAt(oldIndex);
      items.insert(newIndex, item);
      _selectedIndex = null;
      _selectedAction = null;
    });
    widget.onItemChanged(items);
  }

  void _addItem() {
    setState(() {
      items.add({'name': 'new', 'json': widget.json()});
    });
    widget.onItemChanged(items);
  }

  void _removeItem(int index) {
    setState(() {
      items.removeAt(index);
      if (_selectedIndex == index) {
        _selectedIndex = null;
        _selectedAction = null;
      } else if (_selectedIndex != null && _selectedIndex! > index) {
        _selectedIndex = _selectedIndex! - 1;
      }
    });
    widget.onItemChanged(items);
  }

  bool isInBuildPhase() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    return phase == SchedulerPhase.persistentCallbacks;
  }

  void _setSelection(int index, String action) {
    _selectedIndex = index;
    _selectedAction = action;
    currentJsonFake = null;
    if (!isInBuildPhase() && mounted) {
      setState(() {});
    }
  }

  Color? _selectedColor(int index) {
    if (_selectedIndex != index) return Colors.black;
    if (_selectedAction == 'replace') {
      return Colors.orange.withValues(alpha: 0.20);
    }
    return Colors.blue.withValues(alpha: 0.20);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _addItem,
          icon: Icon(Icons.add),
          label: GlowingHalo(child: Text('Add new example')),
        ),
        SizedBox(height: 12),
        ReorderableListView(
          key: ObjectKey(items),
          shrinkWrap: true,
          //physics: NeverScrollableScrollPhysics(),
          onReorder: _onReorder,
          children: List.generate(items.length, (index) {
            return ListTile(
              key: ObjectKey(items[index]),
              //tileColor: _selectedColor(index),
              title: Container(
                color: _selectedColor(index),
                child: Row(
                  spacing: 5,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor:
                            _selectedIndex == index &&
                                    (_selectedAction == 'view' ||
                                        _selectedAction == 'focus')
                                ? Colors.white
                                : null,
                        backgroundColor:
                            _selectedIndex == index &&
                                    (_selectedAction == 'view' ||
                                        _selectedAction == 'focus')
                                ? Colors.blue
                                : null,
                      ),
                      onPressed: () {
                        _setSelection(index, 'view');
                        widget.onLoad(items, index);
                      },
                      child: Text('View'),
                    ),
                    Expanded(
                      child: Focus(
                        onFocusChange: (hasFocus) {
                          if (hasFocus) {
                            _setSelection(index, 'focus');
                            widget.onLoad(items, index);
                          }
                        },
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: 'Name example ${index + 1}',
                            border: OutlineInputBorder(),
                          ),
                          controller: TextEditingController(
                              text: items[index]['name'],
                            )
                            ..selection = TextSelection.fromPosition(
                              TextPosition(
                                offset: items[index]['name']?.length ?? 0,
                              ),
                            ),
                          onChanged: (value) => _updateName(index, value),
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor:
                            _selectedIndex == index &&
                                    _selectedAction == 'replace'
                                ? Colors.white
                                : null,
                        backgroundColor:
                            _selectedIndex == index &&
                                    _selectedAction == 'replace'
                                ? Colors.orange
                                : null,
                      ),
                      onPressed: () {
                        _setSelection(index, 'view');
                        currentJsonFake = items[index]['json'];
                        widget.onReplace(items, index);
                      },
                      child: Text('Replace'),
                    ),
                  ],
                ),
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
