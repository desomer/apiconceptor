import 'package:flutter/material.dart';
import 'package:jsonschema/core/model_schema.dart';
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

class _EditorPropertiesState extends State<EditorProperties> {
  @override
  Widget build(BuildContext context) {
    ModelSchema? model = widget.getModel();
    var info = model!.selectedAttr!;

    Widget infoForm = switch (info.info.type) {
      //'send' => getReceivePubInfoForm(model),
      'receive' => getReceivePubInfoForm(model),
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

  // ackDeadline: 30
  // retryPolicy:
  //   minimumBackoff: 1s
  //   maximumBackoff: 30s
  // deadLetterPolicy:
  //   deadLetterTopic: orders.dlq
  //   maxDeliveryAttempts: 5

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

    List<Widget> row = [];
    String? lastCat = "";
    for (AttributeEditorAsync prop in listProp) {
      String? propName = prop.name;
      var cat = prop.name.split('.');
      if (cat.length > 1) {
        propName = cat.last;
        if (lastCat != cat.first) {
          lastCat = cat.first;
          row.add(SizedBox(height: 5));
          row.add(Text(lastCat, style: TextStyle(fontWeight: FontWeight.bold)));
        }
      }

      row.add(
        CellEditor(
          key: ValueKey('$propName#${info.hashCode}'),
          acces: ModelAccessorAttr(
            node: info,
            schema: model,
            propName: propName,
          ),
          line: 1,
          inArray: false,
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(10),
      child: Column(
        spacing: 10,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: row,
      ),
    );
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
}

class AttributeEditorAsync {
  final String name;
  final String type;
  AttributeEditorAsync({required this.name, required this.type});
}
