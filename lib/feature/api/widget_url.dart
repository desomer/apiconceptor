import 'package:flutter/material.dart';
import 'package:jsonschema/core/api/call_api_manager.dart';

class WidgetApiParam extends StatefulWidget {
  const WidgetApiParam({super.key, required this.apiCallInfo});
  final APICallManager apiCallInfo;

  @override
  State<WidgetApiParam> createState() => _WidgetApiParamState();
}

class _WidgetApiParamState extends State<WidgetApiParam> {
  @override
  Widget build(BuildContext context) {
    return Text(widget.apiCallInfo.addParametersOnUrl(''));
  }
}
