import 'package:flutter/material.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/async_api/property_editor_mixin.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/widget_tab.dart';

enum TypeAttr { asyncapi }

class EditorProperties extends StatefulWidget {
  const EditorProperties({
    super.key,
    required this.getModel,
    required this.typeAttr,
    this.onClose,
  });
  final Function getModel;
  final TypeAttr typeAttr;
  final Function? onClose;

  @override
  State<EditorProperties> createState() => _EditorPropertiesState();
}

class _EditorPropertiesState extends State<EditorProperties>
    with PropertyEditorMixin {
  @override
  Widget build(BuildContext context) {
    ModelSchema? model = widget.getModel();

    if (model?.selectedAttr == null) {
      return SizedBox.shrink();
    }

    var info = model!.selectedAttr!;

    Widget infoForm = switch (info.info.type) {
      //'send' => getReceivePubInfoForm(model),
      'receive' => getReceivePubInfoForm(model),
      'bucket' => getBucketInfoForm(model),
      'scheduler' => getSchedulerInfoForm(model),
      _ => getInfoForm(model),
    };

    return Column(
      children: [
        getHeader(model),
        Expanded(
          child: WidgetTab(
            listTab: [Tab(text: 'Info')],
            listTabCont: [SingleChildScrollView(child: infoForm)],
            heightTab: 30,
          ),
        ),
      ],
    );
  }

  Container getHeader(ModelSchema? model) {
    return Container(
      padding: EdgeInsets.all(3),
      color: Colors.blue,
      child: Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                if (widget.onClose != null) {
                  widget.onClose!();
                }
              },
              child: Icon(Icons.close),
            ),
          ),
          Expanded(
            child: Center(
              child: SelectableText(model?.selectedAttr?.info.name ?? ''),
            ),
          ),
        ],
      ),
    );
  }

  Widget getReceivePubInfoForm(ModelSchema? model) {
    if (model?.selectedAttr == null) {
      return Container();
    }

    var info = model!.selectedAttr!;
    List<AttributeEditorAsync> listProp = [
      AttributeEditorAsync(name: 'ackDeadline', type: 'int'),
      AttributeEditorAsync(
        name: 'retryPolicy.minimumBackoff',
        type: 'duration',
      ),
      AttributeEditorAsync(
        name: 'retryPolicy.maximumBackoff',
        type: 'duration',
      ),
      AttributeEditorAsync(
        name: 'deadLetterPolicy.deadLetterTopic',
        type: 'string',
      ),
      AttributeEditorAsync(
        name: 'deadLetterPolicy.maxDeliveryAttempts',
        type: 'int',
      ),
    ];

    return getListProp(listProp, info, model, <Widget>[]);
  }

  Widget getInfoForm(ModelSchema? model) {
    if (model?.selectedAttr == null) {
      return Container();
    }

    var info = model!.selectedAttr!;
    return Padding(
      padding: EdgeInsets.all(10),
      child: Column(
        spacing: 10,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CellEditor(
            key: ValueKey('description#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'description',
            ),
            line: 5,
            inArray: false,
          ),
          CellEditor(
            key: ValueKey('tag#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'tag',
            ),
            inArray: false,
          ),
          // CellEditor(
          //   key: ValueKey('shortname#${info.hashCode}'),
          //   acces: ModelAccessorAttr(
          //     node: info,
          //     schema: model,
          //     propName: 'short name',
          //   ),
          //   inArray: false,
          // ),
        ],
      ),
    );
  }

  Widget getSchedulerInfoForm(ModelSchema? model) {
    /*  description: "Import quotidien des produits depuis un bucket"

  schedule:
    cron: "0 3 * * *"
    timezone: "Europe/Paris"

  task:
    type: http*/
    if (model?.selectedAttr == null) {
      return Container();
    }

    var info = model!.selectedAttr!;
    List<AttributeEditorAsync> listProp = [
      AttributeEditorAsync(name: 'scheduler.type', type: 'string'),
      AttributeEditorAsync(name: 'trigger.cron', type: 'string'),
      AttributeEditorAsync(name: 'trigger.timezone', type: 'string'),
      AttributeEditorAsync(name: 'taskrunner.type', type: 'string'),
    ];

    var row = <Widget>[];
    row.add(
      CellEditor(
        key: ValueKey('description#${info.hashCode}'),
        acces: ModelAccessorAttr(
          node: info,
          schema: model,
          propName: 'description',
        ),
        line: 5,
        inArray: false,
      ),
    );
    row.add(SizedBox(height: 10));

    return getListProp(listProp, info, model, row);
  }

  Widget getBucketInfoForm(ModelSchema? model) {
    if (model?.selectedAttr == null) {
      return Container();
    }

    var info = model!.selectedAttr!;
    List<AttributeEditorAsync> listProp = [
      AttributeEditorAsync(name: 'storageClass', type: 'string'),
      AttributeEditorAsync(name: 'versioning', type: 'duration'),
      AttributeEditorAsync(name: 'encryption.type', type: 'string'),
      AttributeEditorAsync(name: 'encryption.key', type: 'string'),
      AttributeEditorAsync(name: 'lifecycle.delete_Age', type: 'int'),
      AttributeEditorAsync(name: 'lifecycle.coldline_Age', type: 'int'),
    ];

    return getListProp(listProp, info, model, <Widget>[]);
  }
}

class AttributeEditorAsync {
  final String name;
  final String type;
  AttributeEditorAsync({required this.name, required this.type});
}
