import 'package:flutter/material.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';

class WidgetList<T extends NodeAttribut> extends StatefulWidget {
  const WidgetList({
    super.key,
    required this.getNewAttribut,
    required this.loadAll,
    required this.onSave,
    required this.model,
  });

  final Function getNewAttribut;
  final Function loadAll;
  final Function onSave;
  final ModelSchema model;

  @override
  State<WidgetList<T>> createState() => _WidgetListState();
}

class _WidgetListState<T extends NodeAttribut> extends State<WidgetList<T>> {
  final List<T> _choices = [];

  void _addChoice() {
    setState(() {
      _choices.add(widget.getNewAttribut());
      widget.onSave(_choices);
    });
  }

  void _removeChoice(int index) {
    setState(() {
      _choices.removeAt(index);
      widget.onSave(_choices);
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _choices.removeAt(oldIndex);
      _choices.insert(newIndex, item);
      widget.onSave(_choices);
    });
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    _choices.clear();
    _choices.addAll(widget.loadAll());

    var ret = <Widget>[];
    for (int index = 0; index < _choices.length; index++) {
      var choice = _choices[index];
      var cells = <Widget>[
        SizedBox(
          height: 30,
          width: 200,
          child: CellEditor(
            key: ValueKey('name#${choice.info.masterID}'),
            acces: NodeAccessorAttr(
              attr: choice,
              onSave: () {
                widget.onSave(_choices);
              },
            ),
            inArray: true,
          ),
        ),
      ];
      widget.model.infoManager.addRowWidget(choice, widget.model, cells, context);
      cells.add(Spacer());
      cells.add(
        Padding(
          padding: EdgeInsets.only(right: 50),
          child: InkWell(
            child: Icon(Icons.highlight_off),
            onTap: () => _removeChoice(index),
          ),
        ),
      );

      ret.add(
        Container(
          key: ValueKey(_choices[index].info),
          // decoration: BoxDecoration(
          //   border: BoxBorder.fromLTRB(
          //     bottom: BorderSide(color: Colors.grey, width: 1),
          //   ),
          // ),
          child: Row(children: cells),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        getBtnNewEnd(),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: BoxBorder.fromLTRB(
                top: BorderSide(color: Colors.grey, width: 1),
              ),
            ),
            child: ReorderableListView(onReorder: _onReorder, children: ret),
          ),
        ),
      ],
    );
  }

  var style = ElevatedButton.styleFrom(
    backgroundColor: Colors.blueGrey.shade800,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(5), // button's shape
    ),
    elevation: 5, // button's elevation when it's pressed
  );

  Widget getBtnNewEnd() {
    return ElevatedButton.icon(
      icon: Icon(Icons.add_box_outlined),
      style: style,
      onPressed: () {
        _addChoice();
      },
      label: Text('Add'),
    );
  }
}

//------------------------------------------------------------------------------
class NodeAccessorAttr extends ValueAccessor {
  final NodeAttribut attr;
  final Function onSave;

  NodeAccessorAttr({required this.onSave, required this.attr});

  @override
  get() {
    return attr.info.name;
  }

  @override
  String getName() {
    return 'name';
  }

  @override
  bool isEditable() {
    return true;
  }

  @override
  void remove() {
    // TODO: implement remove
  }

  @override
  void set(value) {
    attr.info.name = value;
    onSave();
  }
}
