import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:highlight/highlight_core.dart';
import 'package:jsonschema/core/yaml_browser.dart';
import 'package:jsonschema/widget/widget_error_banner.dart';
// ignore: implementation_imports
import 'package:flutter_code_editor/src/code_field/actions/tab.dart';
import 'package:jsonschema/widget/widget_long_json_viewer.dart';
import 'package:jsonschema/widget/widget_overflow.dart';

class TextEditor extends StatefulWidget {
  const TextEditor({
    super.key,
    required this.config,
    this.header,
    this.actions,
    this.onHelp,
    this.onSelection,
    this.onHistory,
    this.headerWidget,
  });
  final CodeEditorConfig config;
  final String? header;
  final Widget? headerWidget;
  final List<Widget>? actions;
  final Function? onHelp;
  final Function? onHistory;
  final Function? onSelection;

  @override
  State<TextEditor> createState() => TextEditorState();
}

class TabKeyAction2 extends Action<TabKeyIntent> {
  final CodeController controller;

  TabKeyAction2({required this.controller});

  @override
  Object? invoke(TabKeyIntent intent) {
    controller.indentSelection();
    return null;
  }
}

class PasteKeyAction extends Action<PasteTextIntent> {
  final CodeController controller;

  PasteKeyAction({required this.controller});

  @override
  Object? invoke(PasteTextIntent intent) {
    Clipboard.getData(Clipboard.kTextPlain).then((data) {
      if (data?.text != null) {
        final text = data!.text!;
        final sel = controller.selection;
        controller.value = controller.value.replaced(sel, text);
      }
    });
    return null;
  }
}

class CopyKeyAction extends Action<CopySelectionTextIntent> {
  final CodeController controller;

  CopyKeyAction({required this.controller});

  @override
  Object? invoke(CopySelectionTextIntent intent) {
    final sel = controller.selection;
    if (!sel.isCollapsed) {
      final text = controller.fullText.substring(sel.start, sel.end);
      Clipboard.setData(ClipboardData(text: text));
    }
    return null;
  }
}

class TextEditorState extends State<TextEditor> {
  late CodeController controller;
  late ScrollController verticalScroll;
  late ScrollController horizontalScroll;
  int lastRow = -1;
  final textStyle = const TextStyle(fontFamily: 'SourceCode', fontSize: 14);
  late final double _lineHeight;

  int getCursorLine(CodeController controller) {
    final cursorIndex = controller.selection.start;

    // On prend tout le texte avant le curseur
    final beforeCursor = controller.text.substring(0, cursorIndex);

    // Le numéro de ligne = nombre de '\n' + 1
    return '\n'.allMatches(beforeCursor).length + 1;
  }

  double computeLineHeight() {
    final painter = TextPainter(
      text: TextSpan(text: 'X', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    return painter.height;
  }

  @override
  void initState() {
    _lineHeight = computeLineHeight();
    controller = CodeController(language: widget.config.mode);

    controller.actions[TabKeyIntent] = TabKeyAction2(controller: controller);
    // controller.actions[PasteTextIntent] = PasteKeyAction(
    //   controller: controller,
    // );
    // controller.actions[CopySelectionTextIntent] = CopyKeyAction(
    //   controller: controller,
    // );

    controller.popupController.enabled = false;
    horizontalScroll = ScrollController();
    verticalScroll = ScrollController();
    controller.addListener(() {
      if (dispatch) {
        widget.config.onChange(controller.fullText, widget.config);
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    verticalScroll.dispose();
    horizontalScroll.dispose();
    controller.dispose();
    super.dispose();
  }

  bool dispatch = true;
  int _lastTap = 0;

  void _handleTap() {
    final now = DateTime.now().millisecondsSinceEpoch;

    if (now - _lastTap < 250) {
      _onDoubleClick();
    }

    _lastTap = now;
  }

  void _onDoubleClick() {
    onSelectedCode();
  }

  void scrollToLine(int lineNumber) {
    focusNode.requestFocus();
    int delay = 0;
    if (controller.selection.isValid == false) {
      controller.setCursor(0);
      delay = 300;
    }

    final targetOffset = (lineNumber - 1) * _lineHeight;

    print('scroll to line $lineNumber $targetOffset');

    final text = controller.fullText;

    // Séparer le texte en lignes
    final lines = text.split('\n');
    int charIndex = 0;
    for (int i = 0; i < lineNumber; i++) {
      charIndex += lines[i].length + 1; // +1 pour le '\n'
    }
    // recherle le : dans la ligne
    int idx = lines[lineNumber].indexOf(':');
    if (idx > 0) {
      charIndex += idx;
    }

    Future.delayed(Duration(milliseconds: delay), () {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        controller.selection = TextSelection(
          baseOffset: charIndex,
          extentOffset: charIndex,
        );
        verticalScroll.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      });
    });
  }

  final focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    widget.config.codeEditorState = this;

    var aText = widget.config.getText();
    if (aText == null) {
      return Text('select model first');
    }

    if (aText != controller.fullText) {
      controller.fullText = aText;
    }

    if (aText.length > 50000) {
      return Column(
        children: [
          getHeaderEditor(context),
          Expanded(child: LongJsonViewerSelectableColored(json: aText)),
          WidgetErrorBanner(error: widget.config.notifError),
        ],
      );
    }

    Widget code = CodeField(
      gutterStyle: const GutterStyle(
        //textStyle: TextStyle(height: 1.5),
        margin: 0,
        width: 80,
        showErrors: true,
        showFoldingHandles: true,
        showLineNumbers: true,
      ),
      controller: controller,
      textStyle: textStyle,
      focusNode: focusNode,
      readOnly: widget.config.readOnly,
    );

    // dispatch = false;
    // controller.text = widget.config.getYaml();
    // dispatch = true;
    return Column(
      children: [
        getHeaderEditor(context),
        Expanded(
          child: CodeTheme(
            data: CodeThemeData(styles: monokaiSublimeTheme),
            child: Scrollbar(
              controller: verticalScroll,
              thumbVisibility: true,
              trackVisibility: true,
              child: SingleChildScrollView(
                controller: verticalScroll,
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) => _handleTap(),
                  child: code,
                ),
              ),
            ),
          ),
        ),
        WidgetErrorBanner(error: widget.config.notifError),
      ],
    );
  }

  Container getHeaderEditor(BuildContext context) {
    return Container(
      color: Colors.grey.shade800,
      height: 25,
      width: double.infinity,
      child: NoOverflowErrorFlex(
        direction: Axis.horizontal,
        children: [
          Expanded(
            child: Center(
              child: widget.headerWidget ?? Text(widget.header ?? ""),
            ),
          ),
          ...widget.actions ?? [],
          if (widget.onHistory != null)
            InkWell(
              onTap: () {
                widget.onHistory!(context);
              },
              child: const Icon(Icons.history, size: 20),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
            child: InkWell(
              onTap: () {
                if (widget.onHelp != null) widget.onHelp!(context);
              },
              child: const Icon(Icons.help_outline, size: 20),
            ),
          ),
          if (widget.onSelection != null)
            InkWell(
              child: Icon(Icons.double_arrow_sharp),
              onTap: () {
                //print(controller.selection);
                onSelectedCode();
              },
            ),
        ],
      ),
    );
  }

  void scrollToJsonPath(String aPath) {
    YamlDoc docYaml = YamlDoc();
    docYaml.load(controller.fullText);
    docYaml.doAnalyse();

    for (var line in docYaml.listYamlLine) {
      YamlLine? l = line;
      String path = '';
      while (l != null) {
        if (path.isNotEmpty) {
          path = '.$path';
        }
        path = '${l.name}$path';
        l = l.parent;
      }
      path = 'root.$path';
      if (path == aPath) {
        scrollToLine(line.index);
        return;
      }
    }
  }

  void onSelectedCode() {

    if (widget.onSelection == null) return;

    var curPos = controller.selection.baseOffset;
    YamlDoc docYaml = YamlDoc();
    docYaml.load(controller.fullText);
    docYaml.doAnalyse();

    String path = '';

    for (var line in docYaml.listYamlLine) {
      if (curPos > line.idxCharStart && curPos < line.idxCharStop) {
        YamlLine? l = line;
        int i = 0;
        while (l != null && i < 20) {
          i++;
          if (path.isNotEmpty) {
            path = '.$path';
          }
          path = '${l.name}$path';
          l = l.parent;
        }
        path = 'root.$path';
        widget.onSelection!(path);
        break;
      }
    }
  }
}

class CodeEditorConfig {
  CodeEditorConfig({
    required this.mode,
    required this.getText,
    required this.onChange,
    required this.notifError,
    this.readOnly = false,
    this.validateKey,
  });
  Mode mode;
  late Function onChange;
  late Function getText;
  Function? validateKey;
  late ValueNotifier<String> notifError;
  bool readOnly;

  TextEditorState? codeEditorState;
  State? treeJsonState;

  void repaintCode() {
    if (codeEditorState?.mounted ?? false) {
      // ignore: invalid_use_of_protected_member
      codeEditorState?.setState(() {});
    }
  }
}
