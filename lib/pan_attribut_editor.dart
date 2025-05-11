import 'package:flutter/material.dart';
import 'package:jsonschema/editor/cell_prop_editor.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/widget/widget_tab.dart';

class AttributProperties extends StatefulWidget {
  const AttributProperties({super.key});

  @override
  State<AttributProperties> createState() => _AttributPropertiesState();
}

class _AttributPropertiesState extends State<AttributProperties> {
  @override
  Widget build(BuildContext context) {
    return WidgetTab(
      listTab: [
        Tab(text: 'Info'),
        Tab(text: 'Validator'),
        Tab(text: 'Fake'),
        Tab(text: 'Bdd'),
        Tab(text: 'Tag'),
      ],
      listTabCont: [
        SingleChildScrollView(child: getInfoForm()),
        SingleChildScrollView(child: getTypeValidator()),
        Container(),
        Container(),
        Container(),
      ],
      heightTab: 40,
    );
  }

  Widget getTypeValidator() {
    if (currentCompany.currentModel?.currentAttr == null) {
      return Container();
    }

    String type = currentCompany.currentModel!.currentAttr!.type.toLowerCase();

    if (type == 'string') {
      return getValidatorStringForm();
    } else if (type == 'number') {
      return getValidatorNumberForm(); //getValidatorNumberForm();
    }

    return Container();
  }

  Widget getValidatorNumberForm() {
    var info = currentCompany.currentModel!.currentAttr!;
    return Padding(
      padding: EdgeInsets.all(10),
      child: Column(
        spacing: 10,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (info.isInitByRef)
            TextButton(onPressed: () {}, child: Text("Go to definition")),

          CellEditor(
            key: ValueKey('dependentRequired#${info.hashCode}'),
            acces: ModelAccessorAttr(
              info: info,
              schema: currentCompany.currentModel!,
              propName: 'dependentRequired',
            ),
            line: 5,
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('pattern#${info.hashCode}'),
            acces: ModelAccessorAttr(
              info: info,
              schema: currentCompany.currentModel!,
              propName: 'pattern',
            ),
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('format#${info.hashCode}'),
            acces: ModelAccessorAttr(
              info: info,
              schema: currentCompany.currentModel!,
              propName: 'format',
            ),
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('enum#${info.hashCode}'),
            acces: ModelAccessorAttr(
              info: info,
              schema: currentCompany.currentModel!,
              propName: 'enum',
            ),
            line: 5,
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('multipleOf#${info.hashCode}'),
            acces: ModelAccessorAttr(
              info: info,
              schema: currentCompany.currentModel!,
              propName: 'multipleOf',
            ),
            inArray: false,
            isNumber: true,
          ),
          CellEditor(
            key: ValueKey('minimum#${info.hashCode}'),
            acces: ModelAccessorAttr(
              info: info,
              schema: currentCompany.currentModel!,
              propName: 'minimum',
            ),
            inArray: false,
            isNumber: true,
          ),
          CellCheckEditor(
            key: ValueKey('exclusiveMinimum#${info.hashCode}'),
            acces: ModelAccessorAttr(
              info: info,
              schema: currentCompany.currentModel!,
              propName: 'exclusiveMinimum',
            ),
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('maximum#${info.hashCode}'),
            acces: ModelAccessorAttr(
              info: info,
              schema: currentCompany.currentModel!,
              propName: 'maximum',
            ),
            inArray: false,
            isNumber: true,
          ),
          CellCheckEditor(
            key: ValueKey('exclusiveMaximum#${info.hashCode}'),
            acces: ModelAccessorAttr(
              info: info,
              schema: currentCompany.currentModel!,
              propName: 'exclusiveMaximum',
            ),
            inArray: false,
          ),
        ],
      ),
    );
  }

  Widget getValidatorStringForm() {
    var info = currentCompany.currentModel!.currentAttr!;
    return Padding(
      padding: EdgeInsets.all(10),
      child: Column(
        spacing: 10,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (info.isInitByRef)
            TextButton(onPressed: () {}, child: Text("Go to definition")),
          CellCheckEditor(
            key: ValueKey('required#${info.hashCode}'),
            acces: ModelAccessorAttr(
              info: info,
              schema: currentCompany.currentModel!,
              propName: 'required',
            ),
            inArray: false,
          ),
          CellEditor(
            key: ValueKey('dependentRequired#${info.hashCode}'),
            acces: ModelAccessorAttr(
              info: info,
              schema: currentCompany.currentModel!,
              propName: 'dependentRequired',
            ),
            line: 5,
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('pattern#${info.hashCode}'),
            acces: ModelAccessorAttr(
              info: info,
              schema: currentCompany.currentModel!,
              propName: 'pattern',
            ),
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('format#${info.hashCode}'),
            acces: ModelAccessorAttr(
              info: info,
              schema: currentCompany.currentModel!,
              propName: 'format',
            ),
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('enum#${info.hashCode}'),
            acces: ModelAccessorAttr(
              info: info,
              schema: currentCompany.currentModel!,
              propName: 'enum',
            ),
            line: 5,
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('minLength#${info.hashCode}'),
            acces: ModelAccessorAttr(
              info: info,
              schema: currentCompany.currentModel!,
              propName: 'minLength',
            ),
            inArray: false,
            isNumber: true,
          ),
          CellEditor(
            key: ValueKey('maxLength#${info.hashCode}'),
            acces: ModelAccessorAttr(
              info: info,
              schema: currentCompany.currentModel!,
              propName: 'maxLength',
            ),
            inArray: false,
            isNumber: true,
          ),

          CellEditor(
            key: ValueKey('contentEncoding#${info.hashCode}'),
            acces: ModelAccessorAttr(
              info: info,
              schema: currentCompany.currentModel!,
              propName: 'contentEncoding',
            ),
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('contentMediaType#${info.hashCode}'),
            acces: ModelAccessorAttr(
              info: info,
              schema: currentCompany.currentModel!,
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

  Widget getInfoForm() {
    if (currentCompany.currentModel?.currentAttr == null) {
      return Container();
    }

    var info = currentCompany.currentModel!.currentAttr!;
    return Padding(
      padding: EdgeInsets.all(10),
      child: Column(
        spacing: 10,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (info.isInitByRef)
            TextButton(onPressed: () {}, child: Text("Go to definition")),
          CellEditor(
            key: ValueKey('description#${info.hashCode}'),
            acces: ModelAccessorAttr(
              info: info,
              schema: currentCompany.currentModel!,
              propName: 'description',
            ),
            line: 5,
            inArray: false,
          ),
          CellEditor(
            key: ValueKey('example#${info.hashCode}'),
            acces: ModelAccessorAttr(
              info: info,
              schema: currentCompany.currentModel!,
              propName: 'example',
            ),
            line: 5,
            inArray: false,
          ),
          CellEditor(
            key: ValueKey('const#${info.hashCode}'),
            acces: ModelAccessorAttr(
              info: info,
              schema: currentCompany.currentModel!,
              propName: 'const',
            ),
            inArray: false,
          ),
          CellCheckEditor(
            key: ValueKey('readOnly#${info.hashCode}'),
            acces: ModelAccessorAttr(
              info: info,
              schema: currentCompany.currentModel!,
              propName: 'readOnly',
            ),
            inArray: false,
          ),
          CellCheckEditor(
            key: ValueKey('writeOnly#${info.hashCode}'),
            acces: ModelAccessorAttr(
              info: info,
              schema: currentCompany.currentModel!,
              propName: 'writeOnly',
            ),
            inArray: false,
          ),
          CellCheckEditor(
            key: ValueKey('deprecated#${info.hashCode}'),
            acces: ModelAccessorAttr(
              info: info,
              schema: currentCompany.currentModel!,
              propName: 'deprecated',
            ),
            inArray: false,
          ),
          CellEditor(
            key: ValueKey('comment#${info.hashCode}'),
            acces: ModelAccessorAttr(
              info: info,
              schema: currentCompany.currentModel!,
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
