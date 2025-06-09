import 'package:flutter/material.dart';
import 'package:jsonschema/main.dart';
import 'package:markdown_widget/widget/markdown.dart';

class PanModelChangeViewer extends StatefulWidget {
  const PanModelChangeViewer({super.key});

  @override
  State<PanModelChangeViewer> createState() => _PanModelChangeViewerState();
}

class _PanModelChangeViewerState extends State<PanModelChangeViewer> {
  @override
  Widget build(BuildContext context) {
    var modelSchemaDetail = currentCompany.currentModel!;

    final md = modelSchemaDetail.getHistoryMarkdown();

    // JsonPatch.diff(
    //   modelSchemaDetail.originalModelProperties,
    //   modelSchemaDetail.getJSonForDiff(),
    // );

    // try {
    //   final patchedJson = JsonPatch.apply(json, patches, strict: false);
    // } on JsonPatchTestFailedException catch (e) {
    //   print(e);
    // }

    return MarkdownWidget(data: md);

    // return TextEditor(
    //   header: 'Patch',
    //   config: TextConfig(
    //     mode: json,
    //     readOnly: true,
    //     notifError: ValueNotifier(""),
    //     onChange: (String json, TextConfig config) {},
    //     getText: () {
    //       return Export2JsonSchema().prettyPrintJson(patches);
    //     },
    //   ),
    // );
  }
}
