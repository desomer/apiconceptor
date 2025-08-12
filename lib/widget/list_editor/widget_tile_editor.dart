import 'package:flutter/material.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/list_editor/widget_tile.dart';
    
class WidgetTileEditor extends StatefulWidget {
  const WidgetTileEditor({super.key});

  @override
  State<WidgetTileEditor> createState() => _WidgetTileEditorState();
}

class _WidgetTileEditorState extends State<WidgetTileEditor> {

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
            child: WidgetTile<NodeAttribut>(
              key: keyDragDrop,
              model: currentCompany.listEnv,
              getNewAttribut: () {
                return NodeAttribut(
                  yamlNode: mapEntryEmpty,
                  info: AttributInfo(),
                  parent: null,
                );
              },
              loadAll: () {
                var env = currentCompany.listEnv;
                var browseSingle = BrowseSingle();
                browseSingle.browse(env, true);
                return browseSingle.root;
              },
              onSave: (List<NodeAttribut> choices) {
                var env = currentCompany.listEnv;
                StringBuffer sb = StringBuffer();
                for (var choice in choices) {
                  sb.write(choice.info.name.isEmpty ? 'new' : choice.info.name);
                  sb.writeln(" : env");
                }
                env.modelYaml = sb.toString();
                if (env.doChangeAndRepaintYaml(null, true, 'import')) {
                  // ignore: invalid_use_of_protected_member
                  keyDragDrop.currentState?.setState(() {});
                }
              },
            ),
          ),
        ),
        SizedBox(
          width: 500,
          child: Wrap(
            children: [
              for (var e in currentCompany.listEnv.useAttributInfo)
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
