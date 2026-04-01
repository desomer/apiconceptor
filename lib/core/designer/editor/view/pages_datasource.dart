import 'package:flutter/material.dart';
import 'package:jsonschema/core/api/call_ds_manager.dart';
import 'package:jsonschema/core/compute/compute_manager.dart';
import 'package:jsonschema/core/designer/editor/view/helper/widget_carousel_choice.dart';
import 'package:jsonschema/core/designer/editor/view/bloc_drop_attr.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/feature/transform/pan_model_viewer.dart';
import 'package:jsonschema/feature/transform/pan_response_viewer.dart';
import 'package:jsonschema/widget/widget_split.dart';
import 'package:shortid/shortid.dart' show shortid;

import '../../../../widget/tree_editor/tree_view.dart';

// ignore: must_be_immutable
class PagesDatasource extends StatelessWidget {
  PagesDatasource({super.key, required this.dsCaller});

  final CallerDatasource dsCaller;
  ComputeManager computeManager = ComputeManager();

  @override
  Widget build(BuildContext context) {
    ValueNotifier<String> sourceName = ValueNotifier<String>("Criteria");
    ValueNotifier<String> typeName = ValueNotifier<String>("Form");
    var valueNotifier = ValueNotifier(0);

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
                    computeManager.computedProps =
                        dsCaller.config.computedProps;

                    var listComputeKey = GlobalKey(
                      debugLabel: 'ListComputeWidget',
                    );

                    return Column(
                      children: [
                        TextButton(
                          onPressed: () async {
                            computeManager.computedProps =
                                dsCaller.config.computedProps;
                            ComputedValue cv = ComputedValue(
                              id: shortid.generate(),
                              name:
                                  'compute ${computeManager.computedProps.length + 1}',
                              expression: '',
                            );
                            computeManager.onCloseScriptEditor = () {
                              // ignore: invalid_use_of_protected_member
                              listComputeKey.currentState?.setState(() {});

                              var attr = <String, dynamic>{
                                'src': 'Computed',
                                'type': 'input',
                                'id': cv.id,
                                'label': cv.name,
                                'path': 'show computed ${cv.name}',
                              };
                              dsCaller.panBuilderConfig.add(attr);
                              valueNotifier.value++;
                            };
                            computeManager.showScriptEditor(cv, context);
                          },
                          child: Text("add computed property"),
                        ),
                        Expanded(
                          child: ListComputeWidget(
                            key: listComputeKey,
                            computeManager: computeManager,
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
              ValueListenableBuilder(
                valueListenable: valueNotifier,
                builder: (context, value, child) {
                  return DroppableListView<Map<String, dynamic>, Object>(
                    initialItems: dsCaller.panBuilderConfig,
                    onItemRemoved: (item) {},
                    onDropConvert: (detail) {
                      if (detail.data is Map<String, dynamic>) {
                        // from action or computed
                        return detail.data as Map<String, dynamic>;
                      }

                      var data =
                          (detail.data as TreeNodeData<NodeAttribut>).data;
                      var masterPath = data.info.getMasterIDPath();
                      if (masterPath.isEmpty) {
                        masterPath = data.info.getMasterID();
                      }
                      return <String, dynamic>{
                        'type': 'attr',
                        'src': sourceName.value,
                        'id': masterPath,
                        'path': data.info.getJsonPath(withRoot: false),
                        'widget': 'input',
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
                        child: Row(
                          children: [
                            Expanded(
                              child: ListTile(
                                leading: icon,
                                title: Text(item['path'].toString()),
                              ),
                            ),
                            TypeDropdownWidget(item: item),
                            SizedBox(width: 40),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ],
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

class ListComputeWidget extends StatefulWidget {
  const ListComputeWidget({super.key, required this.computeManager});

  final ComputeManager computeManager;

  @override
  State<ListComputeWidget> createState() => _ListComputeWidgetState();
}

class _ListComputeWidgetState extends State<ListComputeWidget> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.computeManager.computedProps.length,
      itemBuilder: (context, index) {
        var prop = widget.computeManager.computedProps[index];
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
              widget.computeManager.onCloseScriptEditor = () {
                setState(() {});
              };
              // edit computed prop
              widget.computeManager.showScriptEditor(prop, context);
            },
            child: ListTile(
              title: Text(prop.name),
              subtitle: Text(prop.expression),
            ),
          ),
        );
      },
    );
  }
}

class TypeDropdownWidget extends StatefulWidget {
  const TypeDropdownWidget({super.key, required this.item});

  final Map<String, dynamic> item;

  @override
  State<TypeDropdownWidget> createState() => _TypeDropdownWidgetState();
}

class _TypeDropdownWidgetState extends State<TypeDropdownWidget> {
  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      hint: Text('widget type'),
      value: widget.item['widget'] ?? 'input',
      underline: const SizedBox(),
      onChanged: (value) {
        setState(() {
          widget.item['widget'] = value;
        });
      },
      itemHeight: kMinInteractiveDimension,
      isDense: true,

      items: [
        DropdownMenuItem(value: 'input', child: Text('Input')),
        DropdownMenuItem(value: 'label', child: Text('Label')),
        DropdownMenuItem(value: 'icon', child: Text('Icon')),
        DropdownMenuItem(value: 'indicator', child: Text('Indicator')),
        DropdownMenuItem(value: 'action', child: Text('Action button')),
      ],
    );
  }
}
