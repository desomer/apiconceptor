import 'package:flutter/material.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/widget_tab.dart';

enum TypeAttr { model, api }

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

    return Column(
      children: [
        getHeader(model),
        Expanded(
          child: WidgetTab(
            listTab: [Tab(text: 'Info')],
            listTabCont: [SingleChildScrollView(child: getInfoForm(model))],
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
            child: Center(child: Text(model?.selectedAttr?.info.name ?? '')),
          ),
        ],
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
          CellEditor(
            key: ValueKey('shortname#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'short name',
            ),
            inArray: false,
          ),
        ],
      ),
    );
  }
}
