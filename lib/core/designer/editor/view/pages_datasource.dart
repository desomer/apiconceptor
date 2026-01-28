import 'package:flutter/material.dart';
import 'package:jsonschema/core/api/call_ds_manager.dart';
import 'package:jsonschema/core/designer/editor/view/helper/widget_carousel_choice.dart';
import 'package:jsonschema/core/designer/editor/view/bloc_drop_attr.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/feature/transform/pan_model_viewer.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_split.dart';

import '../../../../widget/tree_editor/tree_view.dart';

class PagesDatasource extends StatelessWidget {
  const PagesDatasource({super.key, required this.dsCaller});

  final CallerDatasource dsCaller;

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
                width: 300,
                child: CarouselChoice(
                  items: ['Criteria', 'Data', 'Actions'],
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
                  } else if (value == 'Actions') {
                    List<Widget> buttons = [];
                    buttons.add(
                      getActionButton(
                        'search',
                        'Search',
                        Icon(Icons.smart_button_rounded),
                      ),
                    );
                    buttons.add(
                      getActionButton(
                        'pager',
                        'Pager',
                        Icon(Icons.pin),
                      ),
                    );                    
                    buttons.add(
                      getActionButton(
                        'prevPage',
                        'Previous Page',
                        Icon(Icons.navigate_before),
                      ),
                    );
                    buttons.add(
                      getActionButton(
                        'nextPage',
                        'Next Page',
                        Icon(Icons.navigate_next),
                      ),
                    );

                    for (var element
                        in dsCaller.exampleData ?? const <AttributInfo>[]) {
                      buttons.add(
                        getExampleButton(
                          element,
                          const Icon(Icons.search_rounded),
                        ),
                      );
                    }

                    buttons.addAll(getLinkActions());

                    return Column(children: buttons);
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

  List<Widget> getLinkActions() {
    var link = dsCaller.configApp.data.links;
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
