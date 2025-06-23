import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';

class DocEditor extends StatefulWidget {
  const DocEditor({super.key});

  @override
  State<DocEditor> createState() => _DocEditorState();
}

class _DocEditorState extends State<DocEditor> {
  /// Allows to control the editor and the document.
  late FleatherController _controller;

  /// Fleather editor like any other input field requires a focus node.
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    final document = _loadDocument();
    _controller = FleatherController(document: document);
    _focusNode = FocusNode();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FleatherToolbar.basic(controller: _controller),
        Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
        Expanded(
          child: FleatherEditor(controller: _controller, focusNode: _focusNode),
        ),
        //or
        //FleatherField(controller: _controller),
      ],
    );
  }

  /// Loads the document to be edited in Fleather.
  ParchmentDocument _loadDocument() {
    // For simplicity we hardcode a simple document with one line of text
    // saying "Fleather Quick Start".
    // (Note that delta must always end with newline.)
    final Delta delta = Delta()..insert('Fleather Quick Start\n');
    return ParchmentDocument.fromDelta(delta);
  }
}
