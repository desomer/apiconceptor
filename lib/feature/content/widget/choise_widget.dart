import 'package:flutter/material.dart';

class ChoiseWidget extends StatefulWidget {
  const ChoiseWidget({
    super.key,
    required this.child,
    required this.ctrl,
    required this.choise,
  });
  final Widget child;
  final TextEditingController ctrl;
  final List<String> choise;

  @override
  State<ChoiseWidget> createState() => _ChoiseWidgetState();
}

class _ChoiseWidgetState extends State<ChoiseWidget> {
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
            widget.ctrl.text = result;

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
        _options.clear();
        _options.addAll(widget.choise);

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
