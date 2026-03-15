// ignore_for_file: experimental_member_use

import 'package:flutter/material.dart';
// import 'package:flutter_quill/flutter_quill.dart';
// import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/widget_split.dart';
import 'package:markdown_toolbar/markdown_toolbar.dart';
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

  @override
  void initState() {
    _controller.addListener(() => setState(() {}));
    _focusNode = FocusNode();

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
        Row(children: [Expanded(child: _buildEditor()), VerticalDivider()]),
        Column(
          children: [
            Container(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Center(child: Text('Preview')),
            ),
            Divider(),
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      // Change the toolbar alignment
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(height: 5.0),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: MarkdownToolbar(
            // If you set useIncludedTextField to true, remove
            // a) the controller and focusNode fields below and
            // b) the TextField outside below widget
            useIncludedTextField: false,
            controller: _controller,
            focusNode: _focusNode,

            // Uncomment some of the options below to observe the changes. This list is not exhaustive
            collapsable: false,
            // alignCollapseButtonEnd: true,
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            // dropdownTextColor: Colors.red,
            iconColor: Colors.white,
            iconSize: 20,
            borderRadius: const BorderRadius.all(Radius.circular(8.0)),
            width: 30,
            height: 30,
            // spacing: 16.0,
            // runSpacing: 12.0,
            alignment: WrapAlignment.start,
            // italicCharacter: '_',
            // bulletedListCharacter: '*',
            // horizontalRuleCharacter: '***',
            // hideImage: true,
            // hideCode: true,
            // linkTooltip: 'Add a link',
          ),
        ),
        const Divider(),
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            expands: true, // prend toute la hauteur dispo
            maxLines: null, // obligatoire avec expands
            minLines: null,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              floatingLabelBehavior: FloatingLabelBehavior.always,
              alignLabelWithHint: true,
              labelText: 'Markdown Documentation',
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }
}

// class _WidgetDocState extends State<WidgetDoc> {
//   final QuillController _controller = () {
//     return QuillController.basic(
//       config: QuillControllerConfig(
//         clipboardConfig: QuillClipboardConfig(
//           enableExternalRichPaste: true,
//           onImagePaste: (imageBytes) async {
//             if (kIsWeb) {
//               // Dart IO is unsupported on the web.
//               return null;
//             }
//             // Save the image somewhere and return the image URL that will be
//             // stored in the Quill Delta JSON (the document).
//             final newFileName =
//                 'image-file-${DateTime.now().toIso8601String()}.png';
//             final newPath = path.join(
//               io.Directory.systemTemp.path,
//               newFileName,
//             );
//             final file = await io.File(
//               newPath,
//             ).writeAsBytes(imageBytes, flush: true);
//             return file.path;
//           },
//         ),
//       ),
//     );
//   }();
//   final FocusNode _editorFocusNode = FocusNode();
//   final ScrollController _editorScrollController = ScrollController();

//   @override
//   void initState() {
//     super.initState();
//     //_controller.document.toDelta().toJson();
//     // Load document

//     var kQuillDefaultSample =
//         widget.accessorAttr?.get() ??
//         [
//           {'insert': '\n'},
//         ];

//     _controller.document = Document.fromJson(kQuillDefaultSample);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Row(
//           children: [
//             ElevatedButton.icon(
//               icon: Icon(Icons.save),
//               onPressed: () {
//                 // Save document
//                 var content = _controller.document.toDelta().toJson();
//                 widget.accessorAttr?.set(content);
//                 //widget.setAccessorAttr?.set(content);
//               },
//               label: Text('Save'),
//             ),
//             Spacer(),
//             QuillSimpleToolbar(
//               controller: _controller,
//               config: QuillSimpleToolbarConfig(
//                 embedButtons: FlutterQuillEmbeds.toolbarButtons(),
//                 showClipboardPaste: true,
//                 customButtons: [
//                   QuillToolbarCustomButtonOptions(
//                     icon: const Icon(Icons.add_alarm_rounded),
//                     onPressed: () {
//                       _controller.document.insert(
//                         _controller.selection.extentOffset,
//                         TimeStampEmbed(DateTime.now().toString()),
//                       );

//                       _controller.updateSelection(
//                         TextSelection.collapsed(
//                           offset: _controller.selection.extentOffset + 1,
//                         ),
//                         ChangeSource.local,
//                       );
//                     },
//                   ),
//                 ],
//                 buttonOptions: QuillSimpleToolbarButtonOptions(
//                   base: QuillToolbarBaseButtonOptions(
//                     afterButtonPressed: () {
//                       final isDesktop = {
//                         TargetPlatform.linux,
//                         TargetPlatform.windows,
//                         TargetPlatform.macOS,
//                       }.contains(defaultTargetPlatform);
//                       if (isDesktop) {
//                         _editorFocusNode.requestFocus();
//                       }
//                     },
//                   ),
//                   linkStyle: QuillToolbarLinkStyleButtonOptions(
//                     validateLink: (link) {
//                       // Treats all links as valid. When launching the URL,
//                       // `https://` is prefixed if the link is incomplete (e.g., `google.com` → `https://google.com`)
//                       // however this happens only within the editor.
//                       return true;
//                     },
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//         Expanded(
//           child: QuillEditor(
//             focusNode: _editorFocusNode,
//             scrollController: _editorScrollController,
//             controller: _controller,
//             config: QuillEditorConfig(
//               placeholder: 'Start writing your notes...',
//               padding: const EdgeInsets.all(16),
//               embedBuilders: [
//                 ...FlutterQuillEmbeds.editorBuilders(
//                   imageEmbedConfig: QuillEditorImageEmbedConfig(
//                     imageProviderBuilder: (context, imageUrl) {
//                       // https://pub.dev/packages/flutter_quill_extensions#-image-assets
//                       if (imageUrl.startsWith('assets/')) {
//                         return AssetImage(imageUrl);
//                       }
//                       return null;
//                     },
//                   ),
//                   videoEmbedConfig: QuillEditorVideoEmbedConfig(
//                     customVideoBuilder: (videoUrl, readOnly) {
//                       // To load YouTube videos https://github.com/singerdmx/flutter-quill/releases/tag/v10.8.0
//                       return null;
//                     },
//                   ),
//                 ),
//                 TimeStampEmbedBuilder(),
//               ],
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     _editorScrollController.dispose();
//     _editorFocusNode.dispose();
//     super.dispose();
//   }
// }

// class TimeStampEmbed extends Embeddable {
//   const TimeStampEmbed(String value) : super(timeStampType, value);

//   static const String timeStampType = 'timeStamp';

//   static TimeStampEmbed fromDocument(Document document) =>
//       TimeStampEmbed(jsonEncode(document.toDelta().toJson()));

//   Document get document => Document.fromJson(jsonDecode(data));
// }

// class TimeStampEmbedBuilder extends EmbedBuilder {
//   @override
//   String get key => 'timeStamp';

//   @override
//   String toPlainText(Embed node) {
//     return node.value.data;
//   }

//   @override
//   Widget build(BuildContext context, EmbedContext embedContext) {
//     return Row(
//       children: [
//         const Icon(Icons.access_time_rounded),
//         Text(embedContext.node.value.data as String),
//       ],
//     );
//   }
// }
