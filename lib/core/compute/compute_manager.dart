import 'package:flutter/material.dart';
import 'package:highlight/languages/dart.dart';
import 'package:jsonschema/core/compute/core_expression.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/feature/transform/pan_response_viewer.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/widget/tree_editor/tree_view.dart';

class ComputeManager {
  OverlayEntry? activeOverlayEntry;
  late List<ComputedValue> computedProps;
  Function? onCloseScriptEditor;
  var variables = <String, dynamic>{};

  void editCompute(CwWidgetCtx sel, BuildContext context) {
    Map bind = sel.dataWidget?[cwProps]?['bind'];
    String repoId = bind['repository'];
    String computedId = bind['computedId'];
    Map computedInfo = sel.aFactory.appData[cwRepos][repoId][cwComputed];
    String expression = computedInfo[computedId]['expression'];

    ComputedValue cv = ComputedValue(
      id: computedId,
      name: computedInfo[computedId]['name'],
      expression: expression,
    );
    computedProps = [cv];
    onCloseScriptEditor = () {
      // update the bind with new expression
      sel.aFactory.appData[cwRepos][repoId][cwComputed][cv.id] = {
        'id': cv.id,
        'name': cv.name,
        'expression': cv.expression,
      };
      sel.repaint();
    };
    variables = {
      '\$\$__ctx__\$\$': sel,
      '\$\$__buildctx__\$\$': sel.widgetState!.context,
      '\$\$__state__\$\$': sel.widgetState,
    };
    showScriptEditor(cv, context);
  }

  void showScriptEditor(ComputedValue cv, BuildContext context) {
    MediaQueryData mediaQueryData = MediaQuery.of(context);
    double width = mediaQueryData.size.width * 0.4;
    //double height = mediaQueryData.size.height * 0.6;

    var codeEditorConfig = CodeEditorConfig(
      mode: dart,
      getText: () {
        return cv.expression;
      },
      onChange: (String json, CodeEditorConfig config) {
        cv.expression = json;
      },
      notifError: ValueNotifier(''),
    );

    ValueNotifier<String> valueListenableEval = ValueNotifier<String>("");
    activeOverlayEntry?.remove();

    activeOverlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: 50,
          bottom: 50,
          left: mediaQueryData.size.width - width - 50,
          right: 100,
          child: Stack(
            children: [
              Material(
                child: Column(
                  children: [
                    SizedBox(
                      width: width,
                      child: Row(
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue, // couleur du bouton
                              foregroundColor: Colors.white, // couleur du texte
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),

                            child: const Text('Save'),
                            onPressed: () {
                              if (computedProps.contains(cv) == false) {
                                computedProps.add(cv);
                              }

                              activeOverlayEntry?.remove();
                              activeOverlayEntry = null;
                              if (onCloseScriptEditor != null) {
                                onCloseScriptEditor!();
                              }
                            },
                          ),
                          ElevatedButton(
                            // style: ElevatedButton.styleFrom(
                            //   backgroundColor: Colors.red, // couleur du bouton
                            //   foregroundColor: Colors.white, // couleur du texte
                            //   shape: RoundedRectangleBorder(
                            //     borderRadius: BorderRadius.circular(12),
                            //   ),
                            // ),
                            child: const Text('Cancel'),
                            onPressed: () {
                              activeOverlayEntry?.remove();
                              activeOverlayEntry = null;
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PanEditComputedProp(
                        //dsCaller: dsCaller,
                        cv: cv,
                        codeEditorConfig: codeEditorConfig,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        CoreExpression run = CoreExpression();
                        var logs = <String>[];
                        run.init(cv.expression, logs: logs, isAsync: true);
                        var r = run.eval(logs: logs, variables: variables);
                        print(logs);
                        if (r is Future) {
                          r.then((result) {
                            valueListenableEval.value = result.toString();
                          });
                        } else {
                          valueListenableEval.value = r.toString();
                        }
                      },
                      child: Text("eval"),
                    ),
                    ValueListenableBuilder(
                      valueListenable: valueListenableEval,
                      builder: (context, value, child) {
                        return Text("result = $value");
                      },
                    ),
                  ],
                ),
              ),
              getDropTarget(context, cv, codeEditorConfig),
            ],
          ),
        );
      },
    );

    Overlay.of(context).insert(activeOverlayEntry!);
  }

  Widget getDropTarget(
    BuildContext context,
    ComputedValue cv,
    CodeEditorConfig? codeEditorConfig,
  ) {
    return DragTarget<Object>(
      onWillAcceptWithDetails: (detail) {
        var data = detail.data;
        return data is TreeNodeData<NodeAttribut>;
      },

      onAcceptWithDetails: (details) {
        var data = details.data;
        var dt = data is TreeNodeData<NodeAttribut>;
        if (dt) {
          var dataAttr = data.data;
          if ((codeEditorConfig
                      ?.codeEditorState
                      ?.controller
                      .selection
                      .isValid ??
                  false) ==
              false) {
            codeEditorConfig?.codeEditorState?.controller.setCursor(0);
          }

          codeEditorConfig?.codeEditorState?.controller.insertStr(
            '\$.data["${dataAttr.info.getJsonPath(withRoot: false, noEndWithArray: true)}"]',
          );
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isActive = candidateData.isNotEmpty;
        if (isActive) {
          //var data = candidateData.first as TreeNodeData<NodeAttribut>;
          //String path = data.data.info.name;
          return Container();
        }

        return Container();
      },
    );
  }
}

class PanEditComputedProp extends StatelessWidget {
  const PanEditComputedProp({
    super.key,
    // required this.dsCaller,
    required this.cv,
    required this.codeEditorConfig,
  });

  //final CallerDatasource dsCaller;
  final ComputedValue cv;
  final CodeEditorConfig codeEditorConfig;

  Widget _getCode() {
    return TextEditor(config: codeEditorConfig, header: 'code');
  }

  @override
  Widget build(BuildContext context) {
    var textEditingController = TextEditingController(text: cv.name);
    return Column(
      children: [
        Text("Edit computed property"),
        TextField(
          focusNode: FocusNode(),
          controller: textEditingController,
          onChanged: (value) {
            cv.name = value;
          },
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        Expanded(child: _getCode()),
      ],
    );
  }
}
