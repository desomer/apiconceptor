import 'package:flutter/material.dart';
import 'package:jsonschema/feature/api/pan_api_param_array.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';

class SearchEditor extends StatefulWidget {
  const SearchEditor({
    super.key,
    required this.child,
    required this.childKey,
    required this.paramAccessEditor,
  });
  final Widget child;
  final GlobalKey<CellEditorState> childKey;
  final ParamAccess paramAccessEditor;

  @override
  State<SearchEditor> createState() => _SearchEditorState();
}

class _SearchEditorState extends State<SearchEditor> {
  final SearchController controller = SearchController();

  final List<String> _options = [];
  final Set<String> _selectedItems = {};

  @override
  Widget build(BuildContext context) {
    return SearchAnchor(
      searchController: controller,
      viewTrailing: [
        IconButton(
          onPressed: () {
            String result = _selectedItems.join(',');
            widget.childKey.currentState!.setText(result);
            widget.childKey.currentState!.setState(() {
              widget.paramAccessEditor.set(result);
            });

            controller.closeView('');
          },
          icon: Icon(Icons.check),
        ),
      ],
      builder: (BuildContext context, SearchController controller) {
        return Row(
          children: [
            widget.child,
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                controller.openView();
              },
            ),
          ],
        );
      },
      suggestionsBuilder: (BuildContext context, SearchController controller) {
        var info = widget.paramAccessEditor.paramInfo.info;

        _options.clear();
        if (info != null && info.properties?['enum'] != null) {
          List<String> enumer = info.properties!['enum'].toString().split('\n');
          for (var item in enumer) {
            item = item.replaceAll(RegExp(r'\\n'), '');
            _options.add(item.trim());
          }
        }

        //final query = controller.text.toLowerCase();
        // final filtered = _options.where(
        //   (item) => item.toLowerCase().contains(query),
        // );
        final filtered = _options;

        return filtered.map((item) {
          return SearchCheckTile(choise: item, selectedItems: _selectedItems);
        }).toList();
      },
    );
  }
}

class SearchCheckTile extends StatefulWidget {
  const SearchCheckTile({
    super.key,
    required this.selectedItems,
    required this.choise,
  });
  final Set<String> selectedItems;
  final String choise;
  @override
  State<SearchCheckTile> createState() => _SearchCheckTileState();
}

class _SearchCheckTileState extends State<SearchCheckTile> {
  @override
  Widget build(BuildContext context) {
    final isSelected = widget.selectedItems.contains(widget.choise);
    return CheckboxListTile(
      dense: true,
      title: Text(widget.choise),
      value: isSelected,
      onChanged: (bool? selected) {
        setState(() {
          if (selected == true) {
            widget.selectedItems.add(widget.choise);
          } else {
            widget.selectedItems.remove(widget.choise);
          }
        });
      },
    );
  }
}
