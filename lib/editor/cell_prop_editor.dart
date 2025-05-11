import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/core/json_browser.dart';

class CellEditor extends StatefulWidget {
  const CellEditor({
    super.key,
    required this.acces,
    required this.inArray,
    this.line,
    this.isNumber = false,
  });
  final int? line;
  final ModelAccessor acces;
  final bool inArray;
  final bool isNumber;

  @override
  State<CellEditor> createState() => _CellEditorState();
}

class _CellEditorState extends State<CellEditor> {
  late final TextEditingController _controller;

  @override
  void initState() {
    _controller = TextEditingController();
    _controller.text = widget.acces.get()?.toString() ?? '';
    _controller.addListener(() {
      dynamic val = _controller.text;
      if (val != widget.acces.get()?.toString()) {
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
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    TextInputType? keyboardType;
    List<TextInputFormatter>? inputFormatters;

    if (widget.isNumber) {
      keyboardType = TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      );
      inputFormatters = <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'(^-$|^\-?\d+(\.|\.\d+)?$)')),
      ];
    }

    return SizedBox(
      width: widget.inArray ? 250 : double.infinity,
      height: widget.inArray ? 30 : null,
      child: TextField(
        enabled: widget.acces.isEditable(),
        controller: _controller,
        autocorrect: true,
        maxLines: widget.line,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          contentPadding:
              widget.inArray ? EdgeInsets.fromLTRB(5, 0, 5, 0) : null,
          border: OutlineInputBorder(),
          labelText: !widget.inArray ? widget.acces.getName() : null,
          labelStyle: TextStyle(color: Colors.grey.shade600),
          hintText: widget.inArray ? widget.acces.getName() : null,
          hintStyle: TextStyle(color: Colors.grey.shade600),
        ),
      ),
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
  final ModelAccessor acces;
  final bool inArray;
  @override
  State<CellCheckEditor> createState() => _CellCheckEditorState();
}

class _CellCheckEditorState extends State<CellCheckEditor> {
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
      activeColor: Colors.blue,
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
      activeColor: Colors.blue,
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

abstract class ModelAccessor {
  dynamic get();
  void set(dynamic value);
  void remove();
  String getName();
  bool isEditable();
}

// class ModelEntityAccessor extends ModelAccessor {
//   ModelEntityAccessor({
//     required this.schema,
//     required this.propName,
//   });

//   final ModelSchemaDetail schema;
//   final String propName;

//   @override
//   get() {
//     return schema.modelProperties[propName];
//   }

//   @override
//   void set(dynamic value) {
//     schema.modelProperties[propName] = value;
//     schema.saveProperties();
//   }

//   @override
//   void remove() {
//     schema.modelProperties.remove(propName);
//     schema.saveProperties();
//   }

//   @override
//   String getName() {
//     return propName;
//   }
// }

class ModelAccessorAttr extends ModelAccessor {
  ModelAccessorAttr({
    required this.info,
    required this.schema,
    required this.propName,
  });

  final AttributInfo info;
  final ModelSchemaDetail schema;
  final String propName;

  @override
  get() {
    return info.properties?[propName];
  }

  @override
  void set(dynamic value) {
    var path = '${info.path}.prop.$propName';
    var propChangeValue = info.properties?[propName];
    schema.addHistory(path, ChangeOpe.change, propChangeValue, value);
    info.properties?[propName] = value;
    schema.saveProperties();
  }

  @override
  void remove() {
    info.properties?.remove(propName);
    schema.saveProperties();
  }

  @override
  String getName() {
    return propName;
  }

  @override
  bool isEditable() {
    if (info.isInitByRef) return false;
    return true;
  }
}
