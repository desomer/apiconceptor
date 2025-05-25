import 'package:flutter/material.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/core/json_browser.dart';

class WidgetJsonRow extends StatefulWidget {
  const WidgetJsonRow({
    super.key,
    required this.node,
    required this.schema,
    required this.fctGetRow,
  });

  final NodeAttribut node;
  final ModelSchemaDetail schema;
  final Function fctGetRow;

  @override
  State<WidgetJsonRow> createState() => _WidgetJsonRowState();
}

class _WidgetJsonRowState extends State<WidgetJsonRow> {
  @override
  Widget build(BuildContext context) {
    widget.node.widgetRowState = this;
    //print("rebuild  ${widget.node.info.path} ${widget.node.hashCode}");
    return widget.fctGetRow(widget.node, widget.schema);
  }
}
