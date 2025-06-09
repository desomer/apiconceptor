import 'package:flutter/material.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/widget_tab.dart';

enum TypeAttr { model, api }

class APIProperties extends StatefulWidget {
  const APIProperties({
    super.key,
    required this.getModel,
    required this.typeAttr,
  });
  final Function getModel;
  final TypeAttr typeAttr;

  @override
  State<APIProperties> createState() => _APIPropertiesState();
}

class _APIPropertiesState extends State<APIProperties> {
  @override
  Widget build(BuildContext context) {
    ModelSchemaDetail? model = widget.getModel();

    return WidgetTab(
      listTab: [Tab(text: 'Info')],
      listTabCont: [SingleChildScrollView(child: getInfoForm(model))],
      heightTab: 40,
    );
  }

  Widget getInfoForm(ModelSchemaDetail? model) {
    if (model?.currentAttr == null) {
      return Container();
    }

    var info = model!.currentAttr!;
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
            key: ValueKey('example#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'example',
            ),
            line: 5,
            inArray: false,
          ),
        ],
      ),
    );
  }
}
