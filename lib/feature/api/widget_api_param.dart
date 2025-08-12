import 'package:flutter/material.dart';
import 'package:jsonschema/feature/api/pan_api_editor.dart';

class WidgetApiParam extends StatefulWidget {
  const WidgetApiParam({super.key, required this.apiCallInfo});
  final APICallInfo apiCallInfo;

  @override
  State<WidgetApiParam> createState() => _WidgetApiParamState();
}

class _WidgetApiParamState extends State<WidgetApiParam> {
  @override
  Widget build(BuildContext context) {
    return Text(widget.apiCallInfo.addParametersOnUrl(''));
  }
}
