import 'package:flutter/material.dart';
import 'package:jsonschema/core/api/call_ds_manager.dart';
import 'package:jsonschema/core/designer/component/widget_carousel_choice.dart';
import 'package:jsonschema/core/designer/component/widget_drop_attr.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/feature/transform/pan_model_viewer.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_split.dart';

import '../../../widget/tree_editor/tree_view.dart';

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
                  items: ['Criteria', 'Data'],
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
                  } else {
                    return PanContentSelectorTree(
                      getSchemaFct: () {
                        return dsCaller.modelHttp200;
                      },
                    );
                  }
                },
              ),

              DroppableListView<Map<String, dynamic>, TreeNodeData<NodeAttribut>>(
                initialItems: dsCaller.selectionConfig,
                onItemRemoved: (item) {},
                onDropConvert: (detail) {
                  if (detail.data is Map<String, dynamic>) {
                    return detail.data as Map<String, dynamic>;
                  }

                  var data = (detail.data as TreeNodeData<NodeAttribut>).data;
                  return <String, dynamic>{
                    'src': sourceName.value,
                    'id': data.info.masterID ?? data.info.properties?[constMasterID],
                    'path': data.info.getJsonPath().substring(5),
                  };
                },
                itemBuilder: (context, item, index) {
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 2,
                    ),
                    child: ListTile(title: Text(item['path'].toString())),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
