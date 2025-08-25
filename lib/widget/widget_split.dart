import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';

class SplitView extends StatefulWidget {
  const SplitView({
    super.key,
    required this.children,
    required this.primaryWidth, this.flex1 = 1, this.flex2 =1,
  });
  final List<Widget> children;
  final double primaryWidth;
  final double flex1;
  final double flex2;

  @override
  SplitViewState createState() => SplitViewState();
}

class SplitViewState extends State<SplitView> {
  final MultiSplitViewController _controller = MultiSplitViewController();

  @override
  void initState() {
    super.initState();
    if (widget.primaryWidth == -1) {
      _controller.areas = [Area(data: 0, flex: widget.flex1), Area(data: 1, flex: widget.flex2)];
    } else {
      _controller.areas = [
        Area(data: 0, size: widget.primaryWidth, min: 50, max: 1000),
        Area(data: 1, flex: 1),
      ];
    }
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
        return widget.children[area.data as int];
      },
    );

    return multiSplitView;
  }
}
