import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/export/json_browser.dart';

class CellEditor extends StatefulWidget {
  const CellEditor({
    super.key,
    required this.propName,
    required this.info,
    required this.schema,
    required this.inArray,
    this.line,
    this.isNumber = false,
  });
  final int? line;
  final AttributInfo info;
  final ModelSchemaDetail schema;
  final String propName;
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
    _controller.text =
        widget.info.properties?[widget.propName]?.toString() ?? '';
    _controller.addListener(() {
      dynamic val = _controller.text;
      if (val != '') {
        if (widget.isNumber && val.toString().contains('.')) {
          val = double.parse(val);
        }
        else if (widget.isNumber && val != '-') {
          val = int.parse(val);
        }
        widget.info.properties?[widget.propName] = val;
      } else {
        widget.info.properties?.remove(widget.propName);
      }

      widget.schema.saveProperties();
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
        controller: _controller,
        autocorrect: true,
        maxLines: widget.line,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          contentPadding:
              widget.inArray ? EdgeInsets.fromLTRB(5, 0, 5, 0) : null,
          border: OutlineInputBorder(),
          labelText: !widget.inArray ? widget.propName : null,
          labelStyle: TextStyle(color: Colors.grey.shade600),
          hintText: widget.inArray ? widget.propName : null,
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
    required this.propName,
    required this.info,
    required this.schema,
    required this.inArray,
  });
  final ModelSchemaDetail schema;
  final AttributInfo info;
  final String propName;
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
      title: Text(widget.propName),
      value: widget.info.properties?[widget.propName] ?? false,
      activeColor: Colors.blue,
      onChanged: (bool value) {
        // This is called when the user toggles the switch.
        setState(() {
          widget.info.properties?[widget.propName] = value;
          widget.schema.saveProperties();
        });
      },
    );
  }

  Switch getArraySwitch() {
    return Switch(
      // This bool value toggles the switch.
      value: widget.info.properties?[widget.propName] ?? false,
      activeColor: Colors.blue,
      onChanged: (bool value) {
        // This is called when the user toggles the switch.
        setState(() {
          widget.info.properties?[widget.propName] = value;
          widget.schema.saveProperties();
        });
      },
    );
  }
}
