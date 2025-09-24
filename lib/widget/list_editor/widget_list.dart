import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/widget_hover.dart';

typedef IsSelected<T> =
    bool Function(T node, State? current, State? oldSelectedState);

class WidgetList<T extends NodeAttribut> extends StatefulWidget {
  const WidgetList({
    super.key,
    required this.getNewAttribut,
    required this.loadAll,
    required this.onSave,
    required this.model,
    required this.isSelected,
    this.onSelectRow,
    this.withSpacer=true,
  });

  final Function getNewAttribut;
  final Function loadAll;
  final Function onSave;
  final ModelSchema model;
  final IsSelected<T> isSelected;
  final Function? onSelectRow;
  final bool withSpacer;

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

  void doSelectedRow(T attr) {
    widget.model.selectedAttr = attr;
    if (rowSelectedState?.mounted == true) {
      // ignore: invalid_use_of_protected_member
      rowSelectedState?.setState(() {});
    }
    if (widget.onSelectRow != null) {
      widget.onSelectRow!();
    }
  }

  @override
  Widget build(BuildContext context) {
    _choices.clear();
    _choices.addAll(widget.loadAll());

    var listRows = <Widget>[];
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
      widget.model.infoManager.addRowWidget(
        choice,
        widget.model,
        cells,
        context,
      );
      if (widget.withSpacer) cells.add(Spacer());
      if (!widget.withSpacer) cells.add(SizedBox(width: 20,));
      cells.add(
        Padding(
          padding: EdgeInsets.only(right: 50),
          child: InkWell(
            child: Icon(Icons.highlight_off),
            onTap: () => _removeChoice(index),
          ),
        ),
      );

      listRows.add(
        getHover(
          ValueKey(_choices[index].info),
          _choices[index],
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              doSelectedRow(_choices[index]);
            },
            child: Row(children: cells),
          ),
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
            child: ReorderableListView(
              onReorder: _onReorder,
              children: listRows,
            ),
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

  State? rowSelectedState;

  Widget getHover(Key key, T attr, Widget child) {
    return HoverableCard(
      key: key,
      isSelected: (State state) {
        bool isSelected = widget.isSelected(attr, state, rowSelectedState);
        if (isSelected) {
          if (state != rowSelectedState) {
            var old = rowSelectedState;
            SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
              if (rowSelectedState?.mounted == true) {
                // ignore: invalid_use_of_protected_member
                old?.setState(() {});
              }
            });
          }
          rowSelectedState = state;
        }
        return isSelected;
      },
      child: child,
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
