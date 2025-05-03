import 'package:flutter/material.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/export/json_browser.dart';

class CellEditor extends StatefulWidget {
  const CellEditor({
    super.key,
    required this.propName,
    required this.info,
    required this.schema,
  });
  final AttributInfo info;
  final ModelSchemaDetail schema;
  final String propName;

  @override
  State<CellEditor> createState() => _CellEditorState();
}

class _CellEditorState extends State<CellEditor> {
  late final TextEditingController _controller;

  @override
  void initState() {
    _controller = TextEditingController();
    _controller.text = widget.info.properties?[widget.propName] ?? '';
    _controller.addListener(() {
      widget.info.properties?[widget.propName] = _controller.text;
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
    return SizedBox(
      width: 250,
      height: 30,
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(5, 0, 5, 0),
          border: OutlineInputBorder(),
          hintText: widget.propName,
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
  });
  final ModelSchemaDetail schema;
  final AttributInfo info;
  final String propName;
  @override
  State<CellCheckEditor> createState() => _CellCheckEditorState();
}

class _CellCheckEditorState extends State<CellCheckEditor> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50,
      height: 30,
      child: FittedBox(
        fit: BoxFit.fill,
        child: Switch(
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
        ),
      ),
    );
  }
}
