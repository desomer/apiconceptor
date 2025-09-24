import 'package:flutter/material.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/widget/list_editor/widget_list.dart';

class WidgetListEditor extends StatefulWidget {
  const WidgetListEditor({
    super.key,
    required this.model,
    this.getModel,
    required this.change,
    this.onSelectRow, 
    this.withSpacer=true,
  });

  final ModelSchema? model;
  final Function? getModel;
  final ValueNotifier<int> change;
  final Function? onSelectRow;
  final bool withSpacer;

  @override
  State<WidgetListEditor> createState() => _WidgetListEditorState();
}

class _WidgetListEditorState extends State<WidgetListEditor> {
  final mapEntryEmpty = const MapEntry('', null);
  final GlobalKey keyDragDrop = GlobalKey(debugLabel: 'keyDragDrop');
  State? selectedState;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.change,
      builder: (context, value, child) {
        dynamic model = widget.model ?? widget.getModel!();

        if (model is Future<ModelSchema>) {
          return FutureBuilder<ModelSchema>(
            future: model,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                ModelSchema modelLoaded = snapshot.data!;
                return getContent(modelLoaded);
              } else if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              } else {
                return getLoader();
              }
            },
          );
        } else if (model != null) {
          return getContent(model as ModelSchema);
        } else {
          return Container();
        }
      },
    );
  }

  Widget getLoader() {
    return Center(child: CircularProgressIndicator());
  }

  Widget getContent(ModelSchema model) {
    return Row(
      children: [
        Expanded(
          child: Container(
            width: 500,
            decoration: BoxDecoration(
              border: BoxBorder.fromLTRB(
                right: BorderSide(color: Colors.grey, width: 1),
              ),
            ),
            child: WidgetList<NodeAttribut>(
              key: keyDragDrop,
              model: model,
              onSelectRow: widget.onSelectRow,
              withSpacer: widget.withSpacer,
              isSelected: (node, current, oldSelectedState) {
                selectedState = oldSelectedState;
                return node == model.selectedAttr;
              },

              getNewAttribut: () {
                return NodeAttribut(
                  yamlNode: mapEntryEmpty,
                  info: AttributInfo(),
                  parent: null,
                );
              },
              loadAll: () {
                var browseSingle = BrowseSingle();
                browseSingle.browse(model, true);
                return browseSingle.root;
              },
              onSave: (List<NodeAttribut> choices) {
                StringBuffer sb = StringBuffer();
                for (var choice in choices) {
                  sb.write(choice.info.name.isEmpty ? 'new' : choice.info.name);
                  sb.writeln(" : item");
                }
                model.modelYaml = sb.toString();
                if (model.doChangeAndRepaintYaml(null, true, 'import')) {
                  // ignore: invalid_use_of_protected_member
                  keyDragDrop.currentState?.setState(() {});
                }
                var f = model.onChange;
                if (f != null) f({});
              },
            ),
          ),
        ),
        SizedBox(
          width: 300,
          child: Wrap(
            children: [
              for (var e in model.useAttributInfo)
                Chip(
                  label: Text(e.name),
                  onDeleted: () {
                    // Handle delete actionee
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}
