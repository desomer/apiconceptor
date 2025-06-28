import 'package:flutter/material.dart';
import 'package:jsonschema/main.dart';
import 'package:markdown_widget/widget/markdown.dart';

class PanModelChangeLog extends StatefulWidget {
  const PanModelChangeLog({super.key});

  @override
  State<PanModelChangeLog> createState() => _PanModelChangeLogState();
}

class _PanModelChangeLogState extends State<PanModelChangeLog> {
  @override
  Widget build(BuildContext context) {
    var modelSchemaDetail = currentCompany.currentModel!;

    final md = modelSchemaDetail.getHistory(toMarkdown: true);

    return MarkdownWidget(data: md);
  }
}
