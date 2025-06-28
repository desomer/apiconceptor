import 'package:flutter/material.dart';

class PanJsonBeautifier extends StatefulWidget {
  const PanJsonBeautifier({super.key});

  @override
  State<PanJsonBeautifier> createState() => _PanJsonBeautifierState();
}

class _PanJsonBeautifierState extends State<PanJsonBeautifier> {
  //final CodeLineEditingController _controller = CodeLineEditingController();

  @override
  Widget build(BuildContext context) {
    return Container();
    // return CodeEditor(
    //   style: CodeEditorStyle(
    //     codeTheme: CodeHighlightTheme(
    //       languages: {'json': CodeHighlightThemeMode(mode: langJson)},
    //       theme: atomOneLightTheme,
    //     ),
    //   ),
    //   controller: _controller,
    //   wordWrap: false,
    //   indicatorBuilder: (
    //     context,
    //     editingController,
    //     chunkController,
    //     notifier,
    //   ) {
    //     return Row(
    //       children: [
    //         DefaultCodeLineNumber(
    //           controller: editingController,
    //           notifier: notifier,
    //         ),
    //         DefaultCodeChunkIndicator(
    //           width: 20,
    //           controller: chunkController,
    //           notifier: notifier,
    //         ),
    //       ],
    //     );
    //   },
    //   // findBuilder: (context, controller, readOnly) => CodeFindPanelView(controller: controller, readOnly: readOnly),
    //   // toolbarController: const ContextMenuControllerImpl(),
    //   sperator: Container(width: 1, color: Colors.blue),
    // );
  }
}
