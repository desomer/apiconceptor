import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jsonschema/authorization_manager.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/start_core.dart';

class CellEditor extends StatefulWidget {
  const CellEditor({
    super.key,
    required this.acces,
    required this.inArray,
    this.line,
    this.isNumber = false,
    this.widthInfinite = false
  });
  final int? line;
  final ValueAccessor acces;
  final bool inArray;
  final bool isNumber;
  final bool widthInfinite;

  @override
  State<CellEditor> createState() => CellEditorState();
}

class CellEditorState extends State<CellEditor> {
  late final TextEditingController _controller;
  TextInputType? keyboardType;
  List<TextInputFormatter>? inputFormatters;
  FocusNode? focus;

  void setText(String txt) {
    _controller.text = txt;
  }

  @override
  void initState() {
    _controller = TextEditingController();
    _controller.text = widget.acces.get()?.toString() ?? '';
    _controller.addListener(() {
      dynamic val = _controller.text;
      if (val != (widget.acces.get()?.toString() ?? '')) {
        if (val != '') {
          if (widget.isNumber && val.toString().contains('.')) {
            val = double.parse(val);
          } else if (widget.isNumber && val != '-') {
            val = int.parse(val);
          }
          widget.acces.set(val);
        } else {
          widget.acces.remove();
        }
      }
    });

    if (widget.isNumber) {
      keyboardType = TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      );
      inputFormatters = <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'(^-$|^\-?\d+(\.|\.\d+)?$)')),
      ];
    }

    focus = FocusNode();
    focus!.addListener(() {
      if (focus!.hasPrimaryFocus) {
        _controller.text = widget.acces.get()?.toString() ?? '';
      }
    });

    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    focus?.dispose();
    super.dispose();
  }

  var textStyleLabel = TextStyle(color: Colors.grey.shade600, fontSize: 16);

  @override
  Widget build(BuildContext context) {
    if (widget.inArray) {
      return EditOnHover(
        focus: focus!,
        childOnHover: getWidgetModeEdit(textStyleLabel),
        childFct: () {
          return getWidgetModeView(textStyleLabel);
        },
      );
    }

    return getWidgetModeEdit(textStyleLabel);
  }

  SizedBox getWidgetModeEdit(TextStyle textStyleLabel) {
    return SizedBox(
      width: widget.inArray && !widget.widthInfinite ? (250 * (zoom.value / 100)) : double.infinity,
      height: widget.inArray ? 30 : null,
      child: TextField(
        focusNode: focus,
        enabled: widget.acces.isEditable(),
        controller: _controller,
        autocorrect: true,
        maxLines: widget.line ?? 1,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          contentPadding:
              widget.inArray ? const EdgeInsets.fromLTRB(5, 0, 5, 0) : null,
          border: const OutlineInputBorder(),
          labelText: !widget.inArray ? widget.acces.getName() : null,
          labelStyle: textStyleLabel,
          hintText: widget.inArray ? widget.acces.getName() : null,
          hintStyle: textStyleLabel,
        ),
      ),
    );
  }

  Container getWidgetModeView(TextStyle textStyleLabel) {
    var value = widget.acces.get()?.toString() ?? '';
    bool isEditable = widget.acces.isEditable();
    bool hasValue = value.isNotEmpty;

    if (hasValue) {
      return Container(
        padding: const EdgeInsets.fromLTRB(4, 2, 5, 0),
        width: (250 * (zoom.value / 100)),
        height: 30,
        decoration: BoxDecoration(
          border: Border.fromBorderSide(
            BorderSide(color: isEditable ? Colors.grey.shade600 : Colors.grey),
          ),
          borderRadius: const BorderRadius.all(Radius.circular(4.0)),
        ),
        child: Text(
          value,
          overflow: TextOverflow.clip,
          softWrap: false,
          maxLines: 1,
          style: TextStyle(
            fontSize: 16,
            color: !isEditable ? Colors.white : null,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 2, 5, 0),
      width: (250 * (zoom.value / 100)),
      height: 30,
      decoration: BoxDecoration(
        border: Border.fromBorderSide(BorderSide(color: Colors.grey.shade600)),
        borderRadius: const BorderRadius.all(Radius.circular(4.0)),
      ),
      child: Text(widget.acces.getName(), style: textStyleLabel),
    );
  }
}

class EditOnHover extends StatefulWidget {
  const EditOnHover({
    super.key,
    required this.childOnHover,
    required this.childFct,
    required this.focus,
  });

  final Widget childOnHover;
  final Function childFct;
  final FocusNode focus;

  @override
  State<EditOnHover> createState() => _EditOnHoverState();
}

class _EditOnHoverState extends State<EditOnHover> {
  bool hover = false;
  bool isFocusRegisted = false;

  @override
  Widget build(BuildContext context) {
    if (!isFocusRegisted) {
      isFocusRegisted = true;
      widget.focus.addListener(() {
        if (!widget.focus.hasFocus) {
          setState(() {
            hover = false;
          });
        }
      });
    }

    return MouseRegion(
      onEnter: (event) {
        setState(() {
          hover = true;
        });
      },
      onExit: (event) {
        if (!widget.focus.hasFocus) {
          setState(() {
            hover = false;
          });
        }
      },
      child: hover ? widget.childOnHover : widget.childFct(),
    );
  }
}

//-------------------------------------------------------------------------

class CellCheckEditor extends StatefulWidget {
  const CellCheckEditor({
    super.key,
    required this.acces,
    required this.inArray,
  });
  final ValueAccessor acces;
  final bool inArray;
  @override
  State<CellCheckEditor> createState() => CellCheckEditorState();
}

class CellCheckEditorState extends State<CellCheckEditor> {
  void check(bool check) {
    if (widget.acces.get() != check) {
      setState(() {
        widget.acces.set(check);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.inArray ? 50 : 400,
      height: widget.inArray ? 30 : 35,
      child:
          widget.inArray
              ? FittedBox(fit: BoxFit.fill, child: getArraySwitch())
              : getFormSwitch(),
    );
  }

  Widget getFormSwitch() {
    return SwitchListTile(
      title: Text(widget.acces.getName()),
      value: widget.acces.get() ?? false,
      activeThumbColor: Colors.blue,
      onChanged: (bool value) {
        // This is called when the user toggles the switch.
        if (widget.acces.isEditable()) {
          setState(() {
            widget.acces.set(value);
          });
        }
      },
    );
  }

  Switch getArraySwitch() {
    return Switch(
      // This bool value toggles the switch.
      value: widget.acces.get() ?? false,
      activeThumbColor: Colors.blue,
      onChanged: (bool value) {
        if (widget.acces.isEditable()) {
          setState(() {
            widget.acces.set(value);
          });
        }
      },
    );
  }
}

class CellSelectEditor extends StatefulWidget {
  const CellSelectEditor({super.key});

  @override
  State<CellSelectEditor> createState() => _SingleChoiceState();
}

class _SingleChoiceState extends State<CellSelectEditor> {
  String? calendarView;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      emptySelectionAllowed: true,
      segments: const <ButtonSegment<String>>[
        ButtonSegment<String>(value: "Fact", label: Text('Fact')),
        ButtonSegment<String>(value: "Dim", label: Text('Dimension')),
      ],
      selected: calendarView != null ? <String>{calendarView!} : <String>{},
      onSelectionChanged: (Set<String> newSelection) {
        setState(() {
          calendarView = newSelection.first;
        });
      },
    );
  }
}

abstract class ValueAccessor {
  dynamic get();
  void set(dynamic value);
  void remove();
  String getName();
  bool isEditable();
}

// mixin HasAccessorProp {
//   Map<String, dynamic> properties = {};

//   ValueAccessor getValueAccessor(String name) {
//     var a = PropAccessor(propName: name);
//     a.obj = this;
//     return a;
//   }
// }

// class PropAccessor extends ValueAccessor {
//   PropAccessor({required this.propName});

//   final String propName;
//   late HasAccessorProp obj;

//   @override
//   get() {
//     return obj.properties[propName];
//   }

//   @override
//   String getName() {
//     return propName;
//   }

//   @override
//   bool isEditable() {
//     throw UnimplementedError();
//   }

//   @override
//   void remove() {
//     obj.properties.remove(propName);
//   }

//   @override
//   void set(value) {
//     obj.properties[propName] = value;
//   }
// }

class ModelAccessorAttr extends ValueAccessor {
  ModelAccessorAttr({
    required this.node,
    required this.schema,
    required this.propName,
    this.editable = true,
  });

  final NodeAttribut node;
  final ModelSchema schema;
  final String propName;
  final bool editable;

  @override
  get() {
    return node.info.properties?[propName];
  }

  @override
  void set(dynamic value) {
    var path = '${node.info.path}.prop.$propName';
    if (node.info.properties?[propName] == value) return;
    
    var propChangeValue = node.info.properties?[propName];
    schema.addHistory(node, path, ChangeOpe.change, propChangeValue, value);
    node.info.properties?[propName] = value;
    schema.saveProperties();
    node.repaint();
  }

  @override
  void remove() {
    var path = '${node.info.path}.prop.$propName';
    var propChangeValue = node.info.properties?[propName];
    schema.addHistory(node, path, ChangeOpe.clear, propChangeValue, '');

    node.info.properties?.remove(propName);

    schema.saveProperties();
    // ignore: invalid_use_of_protected_member
    node.repaint();
  }

  @override
  String getName() {
    return propName;
  }

  @override
  bool isEditable() {
    if (!editable || node.info.isInitByRef) return false;
    return true;
  }
}
