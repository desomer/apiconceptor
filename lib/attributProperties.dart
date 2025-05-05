import 'package:flutter/material.dart';
import 'package:jsonschema/editor/cell_editor.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/widget_tab.dart';

class AttributProperties extends StatefulWidget {
  const AttributProperties({super.key});

  @override
  State<AttributProperties> createState() => _AttributPropertiesState();
}

class _AttributPropertiesState extends State<AttributProperties> {
  @override
  Widget build(BuildContext context) {
    return WidgetTab(
      listTab: [Tab(text: 'Detail'), Tab(text: 'Validator'), Tab(text: 'Tag')],
      listTabCont: [getInfoForm(), getTypeValidator(), Container()],
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
          CellEditor(
            key: ValueKey('dependentRequired#${info.hashCode}'),
            propName: 'dependentRequired',
            schema: currentCompany.currentModel!,
            info: info,
            line: 5,
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('pattern#${info.hashCode}'),
            propName: 'pattern',
            schema: currentCompany.currentModel!,
            info: info,
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('format#${info.hashCode}'),
            propName: 'format',
            schema: currentCompany.currentModel!,
            info: info,
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('enum#${info.hashCode}'),
            propName: 'enum',
            schema: currentCompany.currentModel!,
            info: info,
            line: 5,
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('multipleOf#${info.hashCode}'),
            propName: 'multipleOf',
            schema: currentCompany.currentModel!,
            info: info,
            inArray: false,
            isNumber: true,
          ),
          CellEditor(
            key: ValueKey('minimum#${info.hashCode}'),
            propName: 'minimum',
            schema: currentCompany.currentModel!,
            info: info,
            inArray: false,
            isNumber: true,
          ),
          CellCheckEditor(
            key: ValueKey('exclusiveMinimum#${info.hashCode}'),
            propName: 'exclusiveMinimum',
            schema: currentCompany.currentModel!,
            info: info,
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('maximum#${info.hashCode}'),
            propName: 'maximum',
            schema: currentCompany.currentModel!,
            info: info,
            inArray: false,
            isNumber: true,
          ),
          CellCheckEditor(
            key: ValueKey('exclusiveMaximum#${info.hashCode}'),
            propName: 'exclusiveMaximum',
            schema: currentCompany.currentModel!,
            info: info,
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
          CellCheckEditor(
            schema: currentCompany.currentModel!,
            key: ValueKey('required#${info.hashCode}'),
            info: info,
            propName: 'required',
            inArray: false,
          ),
          CellEditor(
            key: ValueKey('dependentRequired#${info.hashCode}'),
            propName: 'dependentRequired',
            schema: currentCompany.currentModel!,
            info: info,
            line: 5,
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('pattern#${info.hashCode}'),
            propName: 'pattern',
            schema: currentCompany.currentModel!,
            info: info,
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('format#${info.hashCode}'),
            propName: 'format',
            schema: currentCompany.currentModel!,
            info: info,
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('enum#${info.hashCode}'),
            propName: 'enum',
            schema: currentCompany.currentModel!,
            info: info,
            line: 5,
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('minLength#${info.hashCode}'),
            propName: 'minLength',
            schema: currentCompany.currentModel!,
            info: info,
            inArray: false,
            isNumber: true,
          ),
          CellEditor(
            key: ValueKey('maxLength#${info.hashCode}'),
            propName: 'maxLength',
            schema: currentCompany.currentModel!,
            info: info,
            inArray: false,
            isNumber: true,
          ),

          CellEditor(
            key: ValueKey('contentEncoding#${info.hashCode}'),
            propName: 'contentEncoding',
            schema: currentCompany.currentModel!,
            info: info,
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('contentMediaType#${info.hashCode}'),
            propName: 'contentMediaType',
            schema: currentCompany.currentModel!,
            info: info,
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
          CellEditor(
            key: ValueKey('description#${info.hashCode}'),
            propName: 'description',
            schema: currentCompany.currentModel!,
            info: info,
            line: 5,
            inArray: false,
          ),
          CellEditor(
            key: ValueKey('example#${info.hashCode}'),
            propName: 'example',
            schema: currentCompany.currentModel!,
            info: info,
            line: 5,
            inArray: false,
          ),
          CellEditor(
            key: ValueKey('const#${info.hashCode}'),
            propName: 'const',
            schema: currentCompany.currentModel!,
            info: info,
            inArray: false,
          ),
          CellCheckEditor(
            key: ValueKey('readOnly#${info.hashCode}'),
            propName: 'readOnly',
            schema: currentCompany.currentModel!,
            info: info,
            inArray: false,
          ),
          CellCheckEditor(
            key: ValueKey('writeOnly#${info.hashCode}'),
            propName: 'writeOnly',
            schema: currentCompany.currentModel!,
            info: info,
            inArray: false,
          ),
          CellCheckEditor(
            key: ValueKey('deprecated#${info.hashCode}'),
            propName: 'deprecated',
            schema: currentCompany.currentModel!,
            info: info,
            inArray: false,
          ),
          CellEditor(
            key: ValueKey('comment#${info.hashCode}'),
            propName: '\$comment',
            schema: currentCompany.currentModel!,
            info: info,
            line: 5,
            inArray: false,
          ),
        ],
      ),
    );
  }
}
