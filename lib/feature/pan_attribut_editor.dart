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
  });
  final Function getModel;
  final TypeAttr typeAttr;

  @override
  State<EditorProperties> createState() => _EditorPropertiesState();
}

class _EditorPropertiesState extends State<EditorProperties> {
  @override
  Widget build(BuildContext context) {
    ModelSchema? model = widget.getModel();

    return WidgetTab(
      listTab: [Tab(text: 'Info')],
      listTabCont: [SingleChildScrollView(child: getInfoForm(model))],
      heightTab: 30,
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
