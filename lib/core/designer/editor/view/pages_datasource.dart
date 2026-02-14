import 'package:flutter/material.dart';
import 'package:highlight/languages/dart.dart';
import 'package:jsonschema/core/api/call_ds_manager.dart';
import 'package:jsonschema/core/core_expression.dart';
import 'package:jsonschema/core/designer/editor/view/helper/widget_carousel_choice.dart';
import 'package:jsonschema/core/designer/editor/view/bloc_drop_attr.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/feature/transform/pan_model_viewer.dart';
import 'package:jsonschema/feature/transform/pan_response_viewer.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/widget/widget_split.dart';
import 'package:shortid/shortid.dart' show shortid;

import '../../../../widget/tree_editor/tree_view.dart';

// ignore: must_be_immutable
class PagesDatasource extends StatelessWidget {
  PagesDatasource({super.key, required this.dsCaller});

  final CallerDatasource dsCaller;

  OverlayEntry? activeOverlayEntry;

  @override
  Widget build(BuildContext context) {
    ValueNotifier<String> sourceName = ValueNotifier<String>("Criteria");
    ValueNotifier<String> typeName = ValueNotifier<String>("Form");
    return Column(
      children: [
        SizedBox(
          height: 100,
          child: Row(
            children: [
              SizedBox(
                width: 450,
                child: CarouselChoice(
                  items: ['Criteria', 'Data', 'Actions', 'Computed'],
                  onSelected: (value) {
                    sourceName.value = value;
                  },
                ),
              ),
              Expanded(
                child: CarouselChoice(
                  items: [
                    'Form',
                    'List',
                    'Table',
                    'Card',
                    'Tabs',
                    'Menu',
                    'Button bar',
                    'Chart',
                  ],
                  onSelected: (value) {
                    typeName.value = value;
                    dsCaller.typeLayout = value;
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SplitView(
            primaryWidth: 600,
            children: [
              ValueListenableBuilder(
                valueListenable: sourceName,
                builder: (context, value, child) {
                  if (value == 'Criteria') {
                    return PanContentSelectorTree(
                      getSchemaFct: () {
                        return dsCaller.helper!.apiCallInfo.currentAPIRequest;
                      },
                    );
                  } else if (value == 'Data') {
                    return PanContentSelectorTree(
                      getSchemaFct: () {
                        return dsCaller.modelHttp200;
                      },
                    );
                  } else if (value == 'Computed') {
                    return Column(
                      children: [
                        TextButton(
                          onPressed: () async {
                            ComputedValue cv = ComputedValue(
                              id: shortid.generate(),
                              name:
                                  'compute ${dsCaller.config.computedProps.length + 1}',
                              expression: '',
                            );
                            showScriptEditor(cv, context);
                          },
                          child: Text("add computed property"),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: dsCaller.config.computedProps.length,
                            itemBuilder: (context, index) {
                              var prop = dsCaller.config.computedProps[index];
                              return Draggable<Map<String, dynamic>>(
                                dragAnchorStrategy: pointerDragAnchorStrategy,
                                data: <String, dynamic>{
                                  'src': 'Computed',
                                  'type': 'input',
                                  'id': prop.id,
                                  'label': prop.name,
                                  'path': 'show computed ${prop.name}',
                                },
                                feedback: Material(child: Text(prop.name)),
                                child: InkWell(
                                  onTap: () {
                                    // edit computed prop
                                    showScriptEditor(prop, context);
                                  },
                                  child: ListTile(
                                    title: Text(prop.name),
                                    subtitle: Text(prop.expression),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  } else if (value == 'Actions') {
                    List<Widget> buttons = getActions();

                    return SingleChildScrollView(
                      child: Column(children: buttons),
                    );
                  } else {
                    return const Center(child: Text('Select source type'));
                  }
                },
              ),

              DroppableListView<Map<String, dynamic>, Object>(
                initialItems: dsCaller.selectionConfig,
                onItemRemoved: (item) {},
                onDropConvert: (detail) {
                  if (detail.data is Map<String, dynamic>) {
                    return detail.data as Map<String, dynamic>;
                  }

                  var data = (detail.data as TreeNodeData<NodeAttribut>).data;
                  return <String, dynamic>{
                    'type': 'attr',
                    'src': sourceName.value,
                    'id':
                        data.info.masterID ??
                        data.info.properties?[constMasterID],
                    'path': data.info.getJsonPath().substring(5),
                  };
                },
                itemBuilder: (context, item, index) {
                  Icon icon = const Icon(Icons.description);
                  if (item['type'] == 'data_link') {
                    icon = const Icon(Icons.link);
                  } else if (item['type'] == 'load_criteria_action') {
                    icon = const Icon(Icons.search_rounded);
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 2,
                    ),
                    child: ListTile(
                      leading: icon,
                      title: Text(item['path'].toString()),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void showScriptEditor(ComputedValue cv, BuildContext context) {
    // double h = MediaQuery.of(context).size.height * 0.8;

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
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue, // couleur du bouton
                          foregroundColor: Colors.white, // couleur du texte
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),

                        child: const Text('Close'),
                        onPressed: () {
                          if (dsCaller.config.computedProps.contains(cv) ==
                              false) {
                            dsCaller.config.computedProps.add(cv);
                          }

                          activeOverlayEntry?.remove();
                          activeOverlayEntry = null;
                        },
                      ),
                    ),
                    Expanded(
                      child: PanEditComputedProp(
                        dsCaller: dsCaller,
                        cv: cv,
                        codeEditorConfig: codeEditorConfig,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        CoreExpression run = CoreExpression();
                        run.init(cv.expression, logs: []);
                        var r = run.eval(logs: [], variables: {});
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
            '\$.data["${dataAttr.info.getJsonPath().substring(5)}"]',
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

  List<Widget> getActions() {
    List<Widget> buttons = [];
    buttons.add(
      getActionButton('search', 'Search', Icon(Icons.smart_button_rounded)),
    );
    buttons.add(getActionButton('pager', 'Pager', Icon(Icons.pin)));
    buttons.add(
      getActionButton('prevPage', 'Previous Page', Icon(Icons.navigate_before)),
    );
    buttons.add(
      getActionButton('nextPage', 'Next Page', Icon(Icons.navigate_next)),
    );

    for (var element in dsCaller.exampleData ?? const <AttributInfo>[]) {
      buttons.add(getExampleButton(element, const Icon(Icons.search_rounded)));
    }

    buttons.addAll(getLinkActions());
    return buttons;
  }

  List<Widget> getLinkActions() {
    var link = dsCaller.config.data.links;
    List<Widget> buttons = [];

    for (var l in link) {
      buttons.add(
        Draggable<Map<String, dynamic>>(
          dragAnchorStrategy: pointerDragAnchorStrategy,
          data: <String, dynamic>{
            'src': 'Actions',
            'type': 'data_link',
            'configLink': l,
            'path': l.title,
          },
          feedback: Material(child: Text(l.title)),
          child: ListTile(
            dense: true,
            title: Text("load link ${l.title}"),
            leading: const Icon(Icons.link),
          ),
        ),
      );
    }
    return buttons;
  }

  Widget getExampleButton(AttributInfo info, Icon? icon) {
    return Draggable<Map<String, dynamic>>(
      dragAnchorStrategy: pointerDragAnchorStrategy,
      data: <String, dynamic>{
        'src': 'Actions',
        'type': 'load_criteria_action',
        'id': info.masterID,
        'label': info.name,
        'path': 'load ${info.name}',
      },
      feedback: Material(child: Text(info.name)),
      child: ListTile(
        dense: true,
        title: Text("load ${info.name}"),
        leading: icon,
      ),
    );
  }

  Widget getActionButton(String type, String label, Icon? icon) {
    return Draggable<Map<String, dynamic>>(
      dragAnchorStrategy: pointerDragAnchorStrategy,
      data: <String, dynamic>{
        'src': 'Actions',
        'type': 'action',
        'id': type,
        'label': label,
        'path': 'action $label',
      },
      feedback: Material(child: Text(label)),
      child: ListTile(dense: true, title: Text("action $label"), leading: icon),
    );
  }
}

class PanEditComputedProp extends StatelessWidget {
  const PanEditComputedProp({
    super.key,
    required this.dsCaller,
    required this.cv,
    required this.codeEditorConfig,
  });

  final CallerDatasource dsCaller;
  final ComputedValue cv;
  final CodeEditorConfig codeEditorConfig;

  Widget _getCode() {
    return TextEditor(config: codeEditorConfig, header: 'code');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text("Edit computed property"),
        TextField(
          controller: TextEditingController(text: ''),
          onChanged: (value) {},
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        Expanded(child: _getCode()),
      ],
    );
  }
}
