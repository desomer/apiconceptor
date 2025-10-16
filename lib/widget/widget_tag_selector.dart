import 'package:flutter/material.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';

class TagSelector extends StatefulWidget {
  final List<String> availableTags;
  final List<String> initialSelected;
  final void Function(List<String>)? onChanged;
  final ValueAccessor? accessor;

  const TagSelector({
    super.key,
    required this.availableTags,
    required this.initialSelected,
    this.onChanged,
    this.accessor,
  });

  @override
  State<TagSelector> createState() => _TagSelectorState();
}

class _TagSelectorState extends State<TagSelector> with WidgetHelper {
  late List<String> selectedTags;
  late List<String> allTags;

  late TextEditingController controller;
  late FocusNode aFocusNode;
  late BuildContext aCtx;

  @override
  void initState() {
    super.initState();
    selectedTags = [...widget.initialSelected];
    var sel = widget.accessor?.get();
    if (sel is List) {
      for (var element in sel) {
        selectedTags.add(element);
      }
    }
    allTags = {...widget.availableTags}.toList();
  }

  void _addTag(String tag) {
    tag = tag.trim();
    if (tag.isEmpty || selectedTags.contains(tag)) return;
    setState(() {
      selectedTags.add(tag);
      if (!allTags.contains(tag)) {
        allTags.add(tag);
      }
      controller.clear();
    });
    if (widget.onChanged != null) widget.onChanged!(selectedTags);
    widget.accessor?.set(selectedTags);
    Navigator.of(aCtx).pop();
  }

  void _removeTag(String tag) {
    setState(() => selectedTags.remove(tag));
    if (widget.onChanged != null) widget.onChanged!(selectedTags);
    widget.accessor?.set(selectedTags);
  }

  @override
  Widget build(BuildContext context) {
    GlobalKey k = GlobalKey();

    List<Widget> tagChips =
        selectedTags.map<Widget>((tag) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey, width: 1),
            ),
            padding: EdgeInsets.symmetric(vertical: 0, horizontal: 8),
            child: Row(
              spacing: 4,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tag),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  onPressed: () {
                    _removeTag(tag);
                  },
                  icon: Icon(Icons.close, size: 18),
                ),
              ],
            ),
          );
        }).toList();

    if (tagChips.isEmpty) tagChips.add(Text('Add tag '));

    tagChips.add(
      IconButton(
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(),

        onPressed: () {
          //Size size = MediaQuery.of(context).size;
          double width = 200;
          double height = 450;

          dialogBuilderBelow(
            context,
            SizedBox(
              width: width,
              height: height,
              child: Column(
                children: [getTagSelector(), Expanded(child: Container())],
              ),
            ),
            k,
            Offset(-100, 0),
            (BuildContext ctx) {
              aCtx = ctx;
            },
          );
        },

        icon: Icon(Icons.add, size: 20),
      ),
    );

    return Wrap(key: k, spacing: 4, runSpacing: 4, children: tagChips);
  }

  Widget getTagSelector() {
    Future.delayed(Duration(milliseconds: 100), () {
      aFocusNode.requestFocus();
    });

    return Autocomplete<String>(
      optionsMaxHeight: 400,
      optionsBuilder: (textEditingValue) {
        return allTags
            .where(
              (tag) =>
                  textEditingValue.text == ' ' ||
                  tag.toLowerCase().contains(
                    textEditingValue.text.toLowerCase(),
                  ),
            )
            .toList();
      },
      onSelected: _addTag,
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        controller = textController;
        aFocusNode = focusNode;
        return TextField(
          controller: textController,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'search or add tag',
            suffixIcon: Icon(Icons.add),
          ),
          onSubmitted: _addTag,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            //decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
            height: 400,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options.elementAt(index);
                return ListTile(
                  dense: true,
                  title: Text(option),
                  onTap: () => onSelected(option),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
