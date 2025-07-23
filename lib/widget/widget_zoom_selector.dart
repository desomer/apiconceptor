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
                if (_stateList?.mounted ?? false) {
                  var root =
                      _stateList!.modelInfo.treeController?.tree
                          as TreeNode<NodeAttribut>?;
                  if (root != null) {
                    var delay = _stateList!.doZoomNode(
                      open,
                      0,
                      root,
                      0,
                      max: value.toInt(),
                    );
                    _stateList!.repaintListView(delay, 'zoom');
                  }
                }
              });
            },
          ),
        ),
        IconButton(
          onPressed: () {
            _stateList!.setState(() {});
            _stateList!.keyTree.currentState!.setState(() {});
            _stateList!.keyJsonList.currentState!.setState(() {});
          },
          icon: Icon(Icons.replay_outlined),
        ),
      ],
    );
  }

  JsonListEditorState? _stateList;

  void setList(JsonListEditorState? state) {
    if (state != null) {
      _stateList = state;
    }
  }
}
