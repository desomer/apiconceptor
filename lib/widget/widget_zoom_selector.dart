import 'package:animated_tree_view/tree_view/tree_node.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/main.dart' show stateOpenFactor;
import 'package:jsonschema/widget/json_editor/widget_json_tree.dart';

class WidgetZoomSelector extends StatefulWidget {
  const WidgetZoomSelector({super.key, required this.zoom});
  final ValueNotifier<double> zoom;

  @override
  State<WidgetZoomSelector> createState() => WidgetZoomSelectorState();
}

class WidgetZoomSelectorState extends State<WidgetZoomSelector> {
  @override
  Widget build(BuildContext context) {
    stateOpenFactor = this;

    return Row(
      children: [
        Text(widget.zoom.value.toInt().toString()),
        SizedBox(
          width: 150,
          child: Slider(
            min: 1,
            max: 10,
            divisions: 9,
            value: widget.zoom.value,
            onChanged: (value) {
              setState(() {
                bool open = value > widget.zoom.value;
                widget.zoom.value = value;
                if (stateList?.mounted ?? false) {
                  var root =
                      stateList!.modelInfo.treeController?.tree
                          as TreeNode<NodeAttribut>?;
                  if (root != null) {
                    var delay = stateList!.doZoomNode(
                      open,
                      0,
                      root,
                      0,
                      max: value.toInt(),
                    );
                    stateList!.repaintListView(delay, 'zoom');
                  }
                }
              });
            },
          ),
        ),
      ],
    );
  }

  JsonListEditorState? stateList;

  void setList(JsonListEditorState state) {
    stateList = state;
  }
}
