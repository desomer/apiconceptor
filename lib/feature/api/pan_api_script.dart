import 'package:flutter/material.dart';
import 'package:highlight/languages/dart.dart';
import 'package:jsonschema/core/api/call_api_manager.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';

enum ScriptType { pre, post }

class PanApiScript extends StatefulWidget {
  const PanApiScript({super.key, required this.api, required this.type});
  final APICallManager api;
  final ScriptType type;

  @override
  State<PanApiScript> createState() => _PanApiScriptState();
}

class _PanApiScriptState extends State<PanApiScript> {
  @override
  Widget build(BuildContext context) {
    return _getCode();
  }

  Widget _getCode() {
    return TextEditor(
      config: CodeEditorConfig(
        mode: dart,
        getText: () {
          return widget.type == ScriptType.pre
              ? widget.api.preRequestStr
              : widget.api.postResponseStr;
        },
        onChange: (String json, CodeEditorConfig config) {
          if (widget.type == ScriptType.pre) {
            widget.api.preRequestStr = json;
          } else {
            widget.api.postResponseStr = json;
          }
        },
        notifError: ValueNotifier(''),
      ),
      header: 'code',
    );
  }
}
