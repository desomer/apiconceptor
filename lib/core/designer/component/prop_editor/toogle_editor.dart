import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/component/helper/helper_editor.dart';
import 'package:jsonschema/core/designer/component/prop_editor/generic_editor.dart';

class ToogleEditor extends GenericEditor {
  const ToogleEditor({
    super.key,
    required super.json,
    required super.config,
    required super.onJsonChanged,
    required this.items,
    required this.isMultiple,
    this.defaultValue,
  });
  final List items;
  final bool isMultiple;
  final String? defaultValue;

  @override
  State<ToogleEditor> createState() => _ToogleEditorState();
}

class _ToogleEditorState extends State<ToogleEditor> with HelperEditor {
  late List<bool> isSelected;
  List<String> listValue = [];
  List items = [];

  @override
  void initState() {
    // this is for 3 buttons, add "false" same as the number of buttons here
    items = widget.items;

    isSelected = [];
    // ignore: unused_local_variable
    for (var element in items) {
      isSelected.add(false);
      //listIcons.add(element['icon'] as IconData);
      listValue.add(element['value'].toString());
    }

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    double width = 30;

    var vals = <String>[];
    var mapValue =
        widget.json[widget.config.id]?.toString() ?? widget.defaultValue;
    if (mapValue != null && widget.isMultiple) {
      vals = mapValue.split(';');
    } else if (mapValue != null) {
      vals.add(mapValue);
    }
    for (int i = 0; i < isSelected.length; i++) {
      if (vals.contains(listValue[i])) {
        isSelected[i] = true;
      }
    }

    List<Widget> lb = [];

    for (var element in items) {
      if (element['label'] != null) {
        width = 70;
        lb.add(Row(children: [Icon(element['icon']), Text(element['label'])]));
      } else {
        lb.add(
          RotatedBox(
            quarterTurns: element['quarterTurns'] ?? 0,
            child: Icon(element['icon']),
          ),
        );
      }
    }

    // listIcons.map((e) => Icon(e)).toList()
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
          child: Text(widget.config.name),
        ),
        const Spacer(),
        ToggleButtons(
          isSelected: isSelected,
          constraints: BoxConstraints(
            maxWidth: width,
            minWidth: width,
            minHeight: 30,
            maxHeight: 30,
          ),
          children: lb,
          onPressed: (int newIndex) {
            setState(() {
              if (widget.isMultiple) {
                isSelected[newIndex] = !isSelected[newIndex];
                StringBuffer v = StringBuffer();
                for (int i = 0; i < isSelected.length; i++) {
                  if (isSelected[i] == true) {
                    if (v.isNotEmpty) v.write(';');
                    v.write(listValue[i]);
                  }
                }
                if (v.isEmpty) {
                  widget.json.remove(widget.config.id);
                } else {
                  widget.json[widget.config.id] = v;
                }
                widget.onJsonChanged?.call(widget.json);
              } else {
                for (int i = 0; i < isSelected.length; i++) {
                  isSelected[i] = i == newIndex ? (!isSelected[i]) : false;
                  if (i == newIndex) {
                    var v = isSelected[i] ? listValue[i] : null;
                    if (v == null || v.isEmpty) {
                      widget.json.remove(widget.config.id);
                    } else {
                      widget.json[widget.config.id] = v;
                    }
                    widget.onJsonChanged?.call(widget.json);
                  }
                }
              }
            });
          },
        ),
      ],
    );

    // return const Row(
    //   mainAxisSize: MainAxisSize.max,
    //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    //   children: [Icon(Icons.abc), Icon(Icons.ac_unit)],
    // );
  }
}
