import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/pages/router_layout.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/widget_overflow.dart';
import 'package:jsonschema/widget/widget_tab.dart';
import 'package:jsonschema/widget/widget_tag_selector.dart';

enum TypeAttr { detailmodel, detailapi }

TabController? currentPropTabController;

class AttributProperties extends StatefulWidget {
  const AttributProperties({
    super.key,
    required this.getModel,
    required this.typeAttr,
    this.onClose,
  });
  final Function getModel;
  final TypeAttr typeAttr;
  final Function? onClose;

  @override
  State<AttributProperties> createState() => _AttributPropertiesState();
}

class _AttributPropertiesState extends State<AttributProperties> {
  @override
  Widget build(BuildContext context) {
    ModelSchema? model = widget.getModel();

    return Column(
      children: [
        getHeader(model),
        Expanded(
          child: WidgetTab(
            onInitController: (TabController controller) {
              currentPropTabController = controller;
              currentPropTabController?.addListener(() {
                if (controller.indexIsChanging) {
                  if (currentYamlTree != null) {
                    //currentYamlTree?.reload();
                  }
                }
              });
            },
            listTab: [
              Tab(text: 'Info'),
              Tab(text: 'Validator'),
              if (widget.typeAttr == TypeAttr.detailmodel) Tab(text: 'Source'),
              if (widget.typeAttr == TypeAttr.detailmodel) Tab(text: 'Tag'),
              if (widget.typeAttr == TypeAttr.detailmodel) Tab(text: 'Fake'),
            ],
            listTabCont: [
              SingleChildScrollView(child: getInfoForm(model)),
              SingleChildScrollView(child: getTypeValidator(model)),
              if (widget.typeAttr == TypeAttr.detailmodel) getSourceForm(model),
              if (widget.typeAttr == TypeAttr.detailmodel) Container(),
              if (widget.typeAttr == TypeAttr.detailmodel)
                SingleChildScrollView(child: getTypeFake(model)),
            ],
            heightTab: 30,
          ),
        ),
      ],
    );
  }

  Container getHeader(ModelSchema? model) {
    return Container(
      decoration: BoxDecoration(
        //arrondi les coins
        borderRadius: BorderRadius.circular(20),
        color: Colors.blue.withValues(alpha: 0.6),
        //color: Colors.grey.shade300,
      ),
      padding: EdgeInsets.fromLTRB(10, 3, 3, 3),

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
              child: SelectableText(
                model?.selectedAttr?.info.name ?? '',
                maxLines: 1,
                //overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget getTypeFake(ModelSchema? model) {
    if (model?.selectedAttr == null) {
      return Container();
    }
    if (model!.selectedAttr!.info.isInitByRef) {
      return TextButton(onPressed: () {}, child: Text("Go to definition"));
    }

    var ret = <Widget>[SizedBox(height: 10)];
    String type = model.selectedAttr!.info.type.toLowerCase();
    if (type.endsWith('[]')) {
      type = 'array';
      // type.substring(0, type.length - 2);
    }
    if (type == 'array') {
      ret.add(
        CellEditor(
          key: ValueKey(
            '#minItems#${model.selectedAttr!.hashCode}@${model.selectedAttr!.info.numUpdateForKey}',
          ),
          acces: ModelAccessorAttr(
            node: model.selectedAttr!,
            schema: model,
            propName: '#minItems',
          ),
          inArray: false,
        ),
      );
      ret.add(
        CellEditor(
          key: ValueKey(
            '#maxItems#${model.selectedAttr!.hashCode}@${model.selectedAttr!.info.numUpdateForKey}',
          ),
          acces: ModelAccessorAttr(
            node: model.selectedAttr!,
            schema: model,
            propName: '#maxItems',
          ),
          inArray: false,
        ),
      );
    }

    return Column(spacing: 5, children: ret);
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
    } else if (type == 'number' || type == 'integer') {
      ret = getValidatorNumberForm(model, listProp == null);
    } else if (type == 'boolean') {
      ret = getValidatorBoolForm(model, listProp == null);
    } else if (type == 'array') {
      ret = getValidatorArrayForm(model);
    } else if (type == 'object') {
      ret = getValidatorObjectForm(model);
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
            key: ValueKey(
              'required#${info.hashCode}@${info.info.numUpdateForKey}',
            ),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'required',
            ),
            inArray: false,
          ),
          CellEditor(
            key: ValueKey(
              'dependentRequired#${info.hashCode}@${info.info.numUpdateForKey}',
            ),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'dependentRequired',
            ),
            line: 5,
            inArray: false,
          ),

          CellEditor(
            key: ValueKey(
              'minItems#${info.hashCode}@${info.info.numUpdateForKey}',
            ),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'minItems',
            ),
            inArray: false,
            isNumber: true,
          ),

          CellEditor(
            key: ValueKey(
              'maxItems#${info.hashCode}@${info.info.numUpdateForKey}',
            ),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'maxItems',
            ),
            inArray: false,
            isNumber: true,
          ),

          CellCheckEditor(
            key: ValueKey(
              'uniqueItems#${info.hashCode}@${info.info.numUpdateForKey}',
            ),
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
              key: ValueKey(
                'required#${info.hashCode}@${info.info.numUpdateForKey}',
              ),
              acces: ModelAccessorAttr(
                node: info,
                schema: model,
                propName: 'required',
              ),
              inArray: false,
            ),
          if (withRequired)
            CellEditor(
              key: ValueKey(
                'dependentRequired#${info.hashCode}@${info.info.numUpdateForKey}',
              ),
              acces: ModelAccessorAttr(
                node: info,
                schema: model,
                propName: 'dependentRequired',
              ),
              line: 5,
              inArray: false,
            ),

          CellEditor(
            key: ValueKey(
              'pattern#${info.hashCode}@${info.info.numUpdateForKey}',
            ),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'pattern',
            ),
            inArray: false,
          ),

          CellEditor(
            key: ValueKey(
              'format#${info.hashCode}@${info.info.numUpdateForKey}',
            ),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'format',
            ),
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('enum#${info.hashCode}@${info.info.numUpdateForKey}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'enum',
            ),
            line: 5,
            inArray: false,
          ),

          CellEditor(
            key: ValueKey(
              'multipleOf#${info.hashCode}@${info.info.numUpdateForKey}',
            ),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'multipleOf',
            ),
            inArray: false,
            isNumber: true,
          ),
          CellEditor(
            key: ValueKey(
              'minimum#${info.hashCode}@${info.info.numUpdateForKey}',
            ),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'minimum',
            ),
            inArray: false,
            isNumber: true,
          ),
          CellCheckEditor(
            key: ValueKey(
              'exclusiveMinimum#${info.hashCode}@${info.info.numUpdateForKey}',
            ),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'exclusiveMinimum',
            ),
            inArray: false,
          ),

          CellEditor(
            key: ValueKey(
              'maximum#${info.hashCode}@${info.info.numUpdateForKey}',
            ),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'maximum',
            ),
            inArray: false,
            isNumber: true,
          ),
          CellCheckEditor(
            key: ValueKey(
              'exclusiveMaximum#${info.hashCode}@${info.info.numUpdateForKey}',
            ),
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
              key: ValueKey(
                'required#${info.hashCode}@${info.info.numUpdateForKey}',
              ),
              acces: ModelAccessorAttr(
                node: info,
                schema: model,
                propName: 'required',
              ),
              inArray: false,
            ),
          if (withRequired)
            CellEditor(
              key: ValueKey(
                'dependentRequired#${info.hashCode}@${info.info.numUpdateForKey}',
              ),
              acces: ModelAccessorAttr(
                node: info,
                schema: model,
                propName: 'dependentRequired',
              ),
              line: 5,
              inArray: false,
            ),

          CellEditor(
            key: ValueKey(
              'pattern#${info.hashCode}@${info.info.numUpdateForKey}',
            ),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'pattern',
            ),
            inArray: false,
          ),

          CellDropMenuEditor(
            key: ValueKey(
              'format#${info.hashCode}@${info.info.numUpdateForKey}',
            ),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'format',
            ),
            // inArray: false,
          ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 5,
            children: [
              Expanded(
                child: CellEditor(
                  key: ValueKey(
                    'enum#${info.hashCode}@${info.info.numUpdateForKey}',
                  ),
                  acces: ModelAccessorAttr(
                    node: info,
                    schema: model,
                    propName: 'enum',
                  ),
                  line: 5,
                  inArray: false,
                ),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    showLabelDialog(info, model, context);
                  },
                  child: Icon(Icons.label),
                ),
              ),
            ],
          ),

          CellEditor(
            key: ValueKey(
              'minLength#${info.hashCode}@${info.info.numUpdateForKey}',
            ),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'minLength',
            ),
            inArray: false,
            isNumber: true,
          ),
          CellEditor(
            key: ValueKey(
              'maxLength#${info.hashCode}@${info.info.numUpdateForKey}',
            ),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'maxLength',
            ),
            inArray: false,
            isNumber: true,
          ),

          CellEditor(
            key: ValueKey(
              'contentEncoding#${info.hashCode}@${info.info.numUpdateForKey}',
            ),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'contentEncoding',
            ),
            inArray: false,
          ),

          CellEditor(
            key: ValueKey(
              'contentMediaType#${info.hashCode}@${info.info.numUpdateForKey}',
            ),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'contentMediaType',
            ),
            inArray: false,
          ),

          CellEditor(
            key: ValueKey('link#${info.hashCode}@${info.info.numUpdateForKey}'),
            line: 3,
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: '#link',
            ),
            inArray: false,
          ),

          // "contentEncoding": "base64",
          // "contentMediaType": "image/png"
        ],
      ),
    );
  }

  Future<void> showLabelDialog(
    NodeAttribut info,
    ModelSchema model,
    BuildContext ctx,
  ) async {
    var str = ModelAccessorAttr(
      node: info,
      schema: model,
      propName: 'enum',
    ).get();

    var label = ModelAccessorAttr(
      node: info,
      schema: model,
      propName: '#enumLabel',
    );

    List<String> enumer = str.toString().split('\n');
    enumer.removeWhere((value) => value.trim().isEmpty);
    String? jsonLabel = label.get();

    jsonLabel ??= "{}";
    Map mapLabel = jsonDecode(jsonLabel);

    List<Widget> listEnumWidget = [];
    for (var element in enumer) {
      listEnumWidget.add(
        Row(
          children: [
            Expanded(child: Text(element)),
            Expanded(
              flex: 2,
              child: TextField(
                enabled: label.isEditable(),
                decoration: InputDecoration(
                  filled: true,
                  labelText: 'Label for "$element"',
                ),
                controller: TextEditingController(
                  text: mapLabel[element] ?? '',
                ),
                onChanged: (value) {
                  if (label.isEditable()) {
                    mapLabel[element] = value;
                  }
                },
              ),
            ),
          ],
        ),
      );
    }

    return showDialog<void>(
      context: ctx,
      barrierDismissible: true, // user must tap button!
      builder: (BuildContext context) {
        Size size = MediaQuery.of(ctx).size;
        double width = size.width * 0.5;
        double height = size.height * 0.8;
        return AlertDialog(
          content: SizedBox(
            width: width,
            height: height,
            child: ListView(children: listEnumWidget),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
                if (mapLabel.isEmpty) {
                  label.remove();
                } else {
                  var v = jsonEncode(mapLabel);
                  label.set(v);
                }
              },
            ),
          ],
        );
      },
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
              key: ValueKey(
                'required#${info.hashCode}@${info.info.numUpdateForKey}',
              ),
              acces: ModelAccessorAttr(
                node: info,
                schema: model,
                propName: 'required',
              ),
              inArray: false,
            ),
          if (withRequired)
            CellEditor(
              key: ValueKey(
                'dependentRequired#${info.hashCode}@${info.info.numUpdateForKey}',
              ),
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

    var typeModelAccessor = ModelAccessorAttr(
      node: info,
      schema: model,
      propName: '#target',
    );

    return Padding(
      padding: EdgeInsets.all(10),
      child: Column(
        spacing: 10,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (info.info.isInitByRef)
            TextButton(onPressed: () {}, child: Text("Go to definition")),

          NoOverflowErrorFlex(
            direction: Axis.horizontal,
            children: [Text('target'), SizedBox(width: 10), getTargetWidget(typeModelAccessor)],
          ),

          TagSelector(
            key: ValueKey('tag#${info.hashCode}@${info.info.numUpdateForKey}'),
            availableTags: ['In future', 'Technical debt', 'Computed'],
            initialSelected: [],
            accessor: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: '#tag',
            ),
          ),

          CellEditor(
            key: ValueKey(
              'description#${info.hashCode}@${info.info.numUpdateForKey}',
            ),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'description',
            ),
            line: 5,
            inArray: false,
          ),
          CellEditor(
            key: ValueKey(
              'example#${info.hashCode}@${info.info.numUpdateForKey}',
            ),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'example',
            ),
            line: 5,
            inArray: false,
          ),
          CellEditor(
            key: ValueKey(
              'const#${info.hashCode}@${info.info.numUpdateForKey}',
            ),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'const',
            ),
            inArray: false,
          ),
          CellEditor(
            key: ValueKey(
              'default#${info.hashCode}@${info.info.numUpdateForKey}',
            ),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'default',
            ),
            inArray: false,
          ),
          CellCheckEditor(
            key: ValueKey(
              'nullable#${info.hashCode}@${info.info.numUpdateForKey}',
            ),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: '#nullable',
            ),
            inArray: false,
          ),
          CellCheckEditor(
            key: ValueKey(
              'readOnly#${info.hashCode}@${info.info.numUpdateForKey}',
            ),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'readOnly',
            ),
            inArray: false,
          ),
          CellCheckEditor(
            key: ValueKey(
              'writeOnly#${info.hashCode}@${info.info.numUpdateForKey}',
            ),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'writeOnly',
            ),
            inArray: false,
          ),
          CellCheckEditor(
            key: ValueKey(
              'deprecated#${info.hashCode}@${info.info.numUpdateForKey}',
            ),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'deprecated',
            ),
            inArray: false,
          ),
          CellEditor(
            key: ValueKey(
              'comment#${info.hashCode}@${info.info.numUpdateForKey}',
            ),
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

  Widget getSourceForm(ModelSchema? model) {
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
            key: ValueKey(
              'source#${info.hashCode}@${info.info.numUpdateForKey}',
            ),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: '#source',
            ),
            line: 5,
            inArray: false,
          ),
        ],
      ),
    );
  }

  Widget getValidatorObjectForm(ModelSchema model) {
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
            key: ValueKey(
              'required#${info.hashCode}@${info.info.numUpdateForKey}',
            ),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'required',
            ),
            inArray: false,
          ),
          CellEditor(
            key: ValueKey(
              'dependentRequired#${info.hashCode}@${info.info.numUpdateForKey}',
            ),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: 'dependentRequired',
            ),
            line: 5,
            inArray: false,
          ),
        ],
      ),
    );
  }

  Widget getTargetWidget(ModelAccessorAttr typeModelAccessor) {
    ValueNotifier<String> sourceName = ValueNotifier(
      typeModelAccessor.get() ?? 'api;bdd;event',
    );

    return ValueListenableBuilder(
      valueListenable: sourceName,
      builder: (context, value, child) {
        var sel = Set<String>.from(value.split(';'));
        return SegmentedButton<String>(
          multiSelectionEnabled: true,
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: 'api',
              label: Text('API', style: TextStyle(fontSize: 12)),
            ),
            ButtonSegment(
              value: 'bdd',
              label: Text('BDD', style: TextStyle(fontSize: 12)),
            ),
            ButtonSegment(
              value: 'event',
              label: Text('Event', style: TextStyle(fontSize: 12)),
            ),
          ],
          style: SegmentedButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.zero, // enlève le padding interne
            visualDensity: const VisualDensity(
              horizontal: -4,
              vertical: -4,
            ), // compresse encore plus
            minimumSize: const Size(0, 28),
          ),
          onSelectionChanged: (value) {
            String str = value.join(';');
            typeModelAccessor.set(str);
            sourceName.value = str;
          },
          selected: sel,
        );
      },
    );
  }
}
