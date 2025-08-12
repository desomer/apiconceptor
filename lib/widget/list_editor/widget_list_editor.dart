import 'package:flutter/material.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/widget/list_editor/widget_list.dart';

class WidgetListEditor extends StatefulWidget {
  const WidgetListEditor({super.key, required this.model});

  final ModelSchema model;

  @override
  State<WidgetListEditor> createState() => _WidgetListEditorState();
}

class _WidgetListEditorState extends State<WidgetListEditor> {
  final mapEntryEmpty = const MapEntry('', null);
  final GlobalKey keyDragDrop = GlobalKey(debugLabel: 'keyDragDrop');

  @override
  Widget build(BuildContext context) {
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
              model: widget.model,
              getNewAttribut: () {
                return NodeAttribut(
                  yamlNode: mapEntryEmpty,
                  info: AttributInfo(),
                  parent: null,
                );
              },
              loadAll: () {
                var browseSingle = BrowseSingle();
                browseSingle.browse(widget.model, true);
                return browseSingle.root;
              },
              onSave: (List<NodeAttribut> choices) {
                StringBuffer sb = StringBuffer();
                for (var choice in choices) {
                  sb.write(choice.info.name.isEmpty ? 'new' : choice.info.name);
                  sb.writeln(" : item");
                }
                widget.model.modelYaml = sb.toString();
                if (widget.model.doChangeAndRepaintYaml(null, true, 'import')) {
                  // ignore: invalid_use_of_protected_member
                  keyDragDrop.currentState?.setState(() {});
                }
                var f = widget.model.onChange;
                if (f != null) f({});
              },
            ),
          ),
        ),
        SizedBox(
          width: 500,
          child: Wrap(
            children: [
              for (var e in widget.model.useAttributInfo)
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
