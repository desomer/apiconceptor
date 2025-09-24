import 'package:flutter/material.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/widget_tab.dart';

enum TypeAttr { detailmodel, detailapi }

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

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(3),
          color: Colors.blue,
          child: Center(child: Text(model?.selectedAttr?.info.name ?? '')),
        ),
        Expanded(
          child: WidgetTab(
            listTab: [
              Tab(text: 'Info'),
              Tab(text: 'Validator'),
              if (widget.typeAttr == TypeAttr.detailmodel) Tab(text: 'Fake'),
              if (widget.typeAttr == TypeAttr.detailmodel) Tab(text: 'Bdd'),
              if (widget.typeAttr == TypeAttr.detailmodel) Tab(text: 'Tag'),
            ],
            listTabCont: [
              SingleChildScrollView(child: getInfoForm(model)),
              SingleChildScrollView(child: getTypeValidator(model)),
              if (widget.typeAttr == TypeAttr.detailmodel) Container(),
              if (widget.typeAttr == TypeAttr.detailmodel) Container(),
              if (widget.typeAttr == TypeAttr.detailmodel) Container(),
            ],
            heightTab: 30,
          ),
        ),
      ],
    );
  }

  Widget getTypeValidator(ModelSchema? model) {
    if (model?.selectedAttr == null) {
      return Container();
    }

    String type = model!.selectedAttr!.info.type.toLowerCase();
    List<Widget>? listProp;

    if (type.endsWith('[]')) {
      type = type.substring(0, type.length - 2);
      listProp = [getValidatorArrayForm(model)];
    }
    Widget? ret;
    if (type == 'string') {
      ret = getValidatorStringForm(model, listProp == null);
    } else if (type == 'number') {
      ret = getValidatorNumberForm(model, listProp == null);
    } else if (type == 'boolean') {
      ret = getValidatorBoolForm(model, listProp == null);
    } else if (type == 'array') {
      ret = getValidatorArrayForm(model);
    }
    if (ret == null) return Container();
    if (listProp != null) {
      return Column(children: [...listProp, ret]);
    }
    return ret;
  }

  Widget getValidatorArrayForm(ModelSchema model) {
    var info = model.selectedAttr!;
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

  Widget getValidatorNumberForm(ModelSchema model, bool withRequired) {
    var info = model.selectedAttr!;
    return Padding(
      padding: EdgeInsets.all(10),
      child: Column(
        spacing: 10,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (info.info.isInitByRef)
            TextButton(onPressed: () {}, child: Text("Go to definition")),
          if (withRequired)
            CellCheckEditor(
              key: ValueKey('required#${info.hashCode}'),
              acces: ModelAccessorAttr(
                node: info,
                schema: model,
                propName: 'required',
              ),
              inArray: false,
            ),
          if (withRequired)
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

  Widget getValidatorStringForm(ModelSchema model, bool withRequired) {
    var info = model.selectedAttr!;
    return Padding(
      padding: EdgeInsets.all(10),
      child: Column(
        spacing: 10,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (info.info.isInitByRef)
            TextButton(onPressed: () {}, child: Text("Go to definition")),
          if (withRequired)
            CellCheckEditor(
              key: ValueKey('required#${info.hashCode}'),
              acces: ModelAccessorAttr(
                node: info,
                schema: model,
                propName: 'required',
              ),
              inArray: false,
            ),
          if (withRequired)
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

  Widget getValidatorBoolForm(ModelSchema? model, bool withRequired) {
    var info = model!.selectedAttr!;
    return Padding(
      padding: EdgeInsets.all(10),
      child: Column(
        spacing: 10,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (info.info.isInitByRef)
            TextButton(onPressed: () {}, child: Text("Go to definition")),
          if (withRequired)
            CellCheckEditor(
              key: ValueKey('required#${info.hashCode}'),
              acces: ModelAccessorAttr(
                node: info,
                schema: model,
                propName: 'required',
              ),
              inArray: false,
            ),
          if (withRequired)
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
