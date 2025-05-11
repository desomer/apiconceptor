import 'package:flutter/material.dart';

class WidgetHiddenBox extends StatefulWidget {
  const WidgetHiddenBox({
    super.key,
    required this.child,
    required this.showNotifier,
  });
  final Widget child;
  final ValueNotifier<double> showNotifier;
  @override
  State<WidgetHiddenBox> createState() => _WidgetHiddenBoxState();
}

class _WidgetHiddenBoxState extends State<WidgetHiddenBox> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    widget.showNotifier.value = 0;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.showNotifier,
      builder: (context, value, child) {
        double d = widget.showNotifier.value;
        return AnimatedContainer(
          // le detail des attribut
          duration: const Duration(milliseconds: 200),
          width: d,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: d, child: widget.child),
          ),
        );
      },
    );
  }
}
