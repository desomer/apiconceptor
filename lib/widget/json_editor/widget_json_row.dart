import 'package:flutter/material.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';

// ignore: must_be_immutable
class WidgetJsonRow extends StatefulWidget {
  WidgetJsonRow({
    super.key,
    required this.node,
    required this.schema,
    required this.fctGetRow,
  }) {
    first = fctGetRow(node, schema);
  }

  final NodeAttribut node;
  final ModelSchema schema;
  final Function fctGetRow;
  Widget? first;
  Widget? cache;

  @override
  State<WidgetJsonRow> createState() => WidgetJsonRowState();
}

class WidgetJsonRowState extends State<WidgetJsonRow> {
  @override
  Widget build(BuildContext context) {
    widget.node.widgetRowState = this;
    if (widget.first != null) {
      var r = widget.first!;
      widget.first = null;
      widget.node.info.cacheRowWidget = widget;
      widget.cache = r;
      return r;
    }
    if (widget.node.info.cacheRowWidget != null && widget.cache != null) {
      return widget.cache!;
    }

    // print("rebuild  ${widget.node.info.path} ${widget.node.info.hashCode}");
    widget.cache = widget.fctGetRow(widget.node, widget.schema);
    return widget.cache!;
  }
}
