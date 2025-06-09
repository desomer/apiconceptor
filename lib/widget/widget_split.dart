import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';

class SplitView extends StatefulWidget {
  const SplitView({super.key, required this.childs, required this.primaryWidth});
  final List<Widget> childs;
  final double primaryWidth;

  @override
  SplitViewState createState() => SplitViewState();
}

class SplitViewState extends State<SplitView> {
  final MultiSplitViewController _controller = MultiSplitViewController();

  @override
  void initState() {
    super.initState();
    _controller.areas = [
      Area(data: 0, size: widget.primaryWidth, min: 50, max: 700),
      Area(data: 1, flex: 1),
    ];
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    MultiSplitView multiSplitView = MultiSplitView(
      axis: Axis.horizontal,
      controller: _controller,
      builder: (BuildContext context, Area area) {
        return widget.childs[area.data as int];
      },
    );

    return multiSplitView;
  }
}
