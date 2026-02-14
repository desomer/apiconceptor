import 'package:flutter/material.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';

class WidgetTile<T extends NodeAttribut> extends StatefulWidget {
  const WidgetTile({
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
  State<WidgetTile<T>> createState() => _WidgetTileState();
}

class _WidgetTileState<T extends NodeAttribut> extends State<WidgetTile<T>> {
  final List<T> _choices = [];

  T? draggingItem;

  final int columns = 3;
  final double cardWidth = 120;
  final double cardHeight = 80;
  final double spacing = 12;  

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

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children:
              _choices.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;

                final row = index ~/ columns;
                final col = index % columns;

                final left = col * (cardWidth + spacing);
                final top = row * (cardHeight + spacing);

                return AnimatedPositioned(
                  key: ValueKey(item.info.masterID),
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  left: left.toDouble(),
                  top: top.toDouble(),
                  child: DragTarget<T>(
                    onWillAcceptWithDetails: (data) => data.data != item,
                    onAcceptWithDetails: (data) {
                     // setState(() {
                        final fromIndex = _choices.indexWhere(
                          (i) => i.info.masterID == data.data.info.masterID,
                        );
                        final toIndex = _choices.indexWhere(
                          (i) => i.info.masterID == item.info.masterID,
                        );
                        final dragged = _choices.removeAt(fromIndex);
                        _choices.insert(toIndex, dragged);
                         widget.onSave(_choices);
                      //});
                    },
                    builder: (context, candidateData, rejectedData) {
                      return Draggable<T>(
                        data: item,
                        onDragStarted:
                            () => setState(() => draggingItem = item),
                        onDraggableCanceled:
                            (_, _) => setState(() => draggingItem = null),
                        onDragCompleted:
                            () => setState(() => draggingItem = null),
                        feedback: Material(
                          color: Colors.transparent,
                          child: Transform.scale(
                            scale: 1.1,
                            child: _buildCard(item, isDragging: true),
                          ),
                        ),
                        child: _buildCard(
                          item,
                          isDragging: draggingItem == item,
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
        );
      },
    );
  }


  Widget _buildCard(T item, {bool isDragging = false}) {
    return Opacity(
      opacity: isDragging ? 0.4 : 1.0,
      child: Card(
        //color: item.color,
        elevation: isDragging ? 2 : 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: cardWidth,
          height: cardHeight,
          alignment: Alignment.center,
          child: Text(
            item.info.name,
            style: TextStyle(fontSize: 20, color: Colors.white),
          ),
        ),
      ),
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
