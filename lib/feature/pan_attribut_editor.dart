import 'package:flutter/material.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/widget_tab.dart';

enum TypeAttr { model, api }

class AttributProperties extends StatefulWidget {
  const AttributProperties({
    super.key,
    required this.getModel,
    required this.typeAttr,
  });
  final Function getModel;
  final TypeAttr typeAttr;

  @override
  State<AttributProperties> createState() => _AttributPropertiesState();
}

class _AttributPropertiesState extends State<AttributProperties> {
  @override
  Widget build(BuildContext context) {
    ModelSchema? model = widget.getModel();

    return WidgetTab(
      listTab: [
        Tab(text: 'Info'),
        Tab(text: 'Validator'),
        Tab(text: 'Fake'),
        if (widget.typeAttr == TypeAttr.model) Tab(text: 'Bdd'),
        if (widget.typeAttr == TypeAttr.model) Tab(text: 'Tag'),
      ],
      listTabCont: [
        SingleChildScrollView(child: getInfoForm(model)),
        SingleChildScrollView(child: getTypeValidator(model)),
        Container(),
        if (widget.typeAttr == TypeAttr.model) Container(),
        if (widget.typeAttr == TypeAttr.model) Container(),
      ],
      heightTab: 40,
    );
  }

  Widget getTypeValidator(ModelSchema? model) {
    if (model?.currentAttr == null) {
      return Container();
    }

    String type = model!.currentAttr!.info.type.toLowerCase();

    if (type == 'string') {
      return getValidatorStringForm(model);
    } else if (type == 'number') {
      return getValidatorNumberForm(model);
    } else if (type == 'boolean') {
      return getValidatorBoolForm(model);
    } else if (type == 'array') {
      return getValidatorArrayForm(model);
    }

    return Container();
  }

  Widget getValidatorArrayForm(ModelSchema model) {
    var info = model.currentAttr!;
    return Padding(
      padding: EdgeInsets.all(10),
      child: Column(
        spacing: 10,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (info.info.isInitByRef)
            TextButton(onPressed: () {}, child: Text("Go to definition")),
          CellCheckEditor(
            key: ValueKey('required#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'required',
            ),
            inArray: false,
          ),
          CellEditor(
            key: ValueKey('dependentRequired#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'dependentRequired',
            ),
            line: 5,
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('minItems#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'minItems',
            ),
            inArray: false,
            isNumber: true,
          ),

          CellEditor(
            key: ValueKey('maxItems#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'maxItems',
            ),
            inArray: false,
            isNumber: true,
          ),

          CellCheckEditor(
            key: ValueKey('uniqueItems#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'uniqueItems ',
            ),
            inArray: false,
          ),
        ],
      ),
    );
  }

  Widget getValidatorNumberForm(ModelSchema model) {
    var info = model.currentAttr!;
    return Padding(
      padding: EdgeInsets.all(10),
      child: Column(
        spacing: 10,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (info.info.isInitByRef)
            TextButton(onPressed: () {}, child: Text("Go to definition")),
          CellCheckEditor(
            key: ValueKey('required#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'required',
            ),
            inArray: false,
          ),
          CellEditor(
            key: ValueKey('dependentRequired#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'dependentRequired',
            ),
            line: 5,
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('pattern#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'pattern',
            ),
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('format#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'format',
            ),
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('enum#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'enum',
            ),
            line: 5,
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('multipleOf#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'multipleOf',
            ),
            inArray: false,
            isNumber: true,
          ),
          CellEditor(
            key: ValueKey('minimum#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'minimum',
            ),
            inArray: false,
            isNumber: true,
          ),
          CellCheckEditor(
            key: ValueKey('exclusiveMinimum#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'exclusiveMinimum',
            ),
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('maximum#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'maximum',
            ),
            inArray: false,
            isNumber: true,
          ),
          CellCheckEditor(
            key: ValueKey('exclusiveMaximum#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'exclusiveMaximum',
            ),
            inArray: false,
          ),
        ],
      ),
    );
  }

  Widget getValidatorStringForm(ModelSchema model) {
    var info = model.currentAttr!;
    return Padding(
      padding: EdgeInsets.all(10),
      child: Column(
        spacing: 10,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (info.info.isInitByRef)
            TextButton(onPressed: () {}, child: Text("Go to definition")),
          CellCheckEditor(
            key: ValueKey('required#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'required',
            ),
            inArray: false,
          ),
          CellEditor(
            key: ValueKey('dependentRequired#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'dependentRequired',
            ),
            line: 5,
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('pattern#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'pattern',
            ),
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('format#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'format',
            ),
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('enum#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'enum',
            ),
            line: 5,
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('minLength#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'minLength',
            ),
            inArray: false,
            isNumber: true,
          ),
          CellEditor(
            key: ValueKey('maxLength#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'maxLength',
            ),
            inArray: false,
            isNumber: true,
          ),

          CellEditor(
            key: ValueKey('contentEncoding#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'contentEncoding',
            ),
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('contentMediaType#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'contentMediaType',
            ),
            inArray: false,
          ),

          // "contentEncoding": "base64",
          // "contentMediaType": "image/png"
        ],
      ),
    );
  }

  Widget getValidatorBoolForm(ModelSchema? model) {
    var info = model!.currentAttr!;
    return Padding(
      padding: EdgeInsets.all(10),
      child: Column(
        spacing: 10,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (info.info.isInitByRef)
            TextButton(onPressed: () {}, child: Text("Go to definition")),
          CellCheckEditor(
            key: ValueKey('required#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'required',
            ),
            inArray: false,
          ),
          CellEditor(
            key: ValueKey('dependentRequired#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'dependentRequired',
            ),
            line: 5,
            inArray: false,
          ),

          // "contentEncoding": "base64",
          // "contentMediaType": "image/png"
        ],
      ),
    );
  }

  Widget getInfoForm(ModelSchema? model) {
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
          if (info.info.isInitByRef)
            TextButton(onPressed: () {}, child: Text("Go to definition")),
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
          CellEditor(
            key: ValueKey('const#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'const',
            ),
            inArray: false,
          ),
          CellCheckEditor(
            key: ValueKey('readOnly#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'readOnly',
            ),
            inArray: false,
          ),
          CellCheckEditor(
            key: ValueKey('writeOnly#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'writeOnly',
            ),
            inArray: false,
          ),
          CellCheckEditor(
            key: ValueKey('deprecated#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'deprecated',
            ),
            inArray: false,
          ),
          CellEditor(
            key: ValueKey('comment#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: '\$comment',
            ),
            line: 5,
            inArray: false,
          ),
        ],
      ),
    );
  }
}
