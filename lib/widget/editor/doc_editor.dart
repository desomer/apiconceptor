// ignore_for_file: experimental_member_use

import 'package:flutter/material.dart';
// import 'package:flutter_quill/flutter_quill.dart';
// import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/editor/mark_down_editor.dart';
import 'package:jsonschema/widget/splitview/widget_split.dart';
import 'package:markdown_widget/config/configs.dart';
import 'package:markdown_widget/widget/markdown.dart';

class WidgetDoc extends StatefulWidget {
  const WidgetDoc({super.key, this.accessorAttr});
  final ModelAccessorAttr? accessorAttr;

  @override
  State<WidgetDoc> createState() => _WidgetDocState();
}

class _WidgetDocState extends State<WidgetDoc> {
  final TextEditingController _controller = TextEditingController();
  late final FocusNode _focusNode;
  //late final FocusNode _focusNode2;

  @override
  void initState() {
    //_controller.addListener(() => setState(() {}));
    _focusNode = FocusNode();
    //_focusNode2 = FocusNode();
    var doc = widget.accessorAttr?.get();
    if (doc != null) {
      _controller.text = doc.toString();
    }

    _controller.addListener(() {
      widget.accessorAttr?.set(_controller.text);
    });

    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    //_focusNode2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var doc = widget.accessorAttr?.get();
    if (doc != null) {
      _controller.text = doc.toString();
    }

    return SplitView(
      secondaryWidth: -1,
      primaryWidth: -1,
      children: [
        Row(
          children: [
            Expanded(child: _buildEditor()),
            const VerticalDivider(),
          ],
        ),
        Column(
          children: [
            Container(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: const Center(child: Text('Preview')),
            ),
            const Divider(),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: _controller,
                builder: (context, value, child) {
                  return MarkdownWidget(
                    data: _controller.text,
                    config: MarkdownConfig.darkConfig,
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditor() {
    return MarkDownEditor(
      controller: _controller,
      focusNode: _focusNode,
      context: context,
    );
  }
}
