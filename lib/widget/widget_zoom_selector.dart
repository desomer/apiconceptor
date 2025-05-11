import 'package:flutter/material.dart';

class WidgetZoomSelector extends StatefulWidget {
  const WidgetZoomSelector({super.key, required this.zoom});
  final ValueNotifier<double> zoom;

  @override
  State<WidgetZoomSelector> createState() => _WidgetZoomSelectorState();
}

class _WidgetZoomSelectorState extends State<WidgetZoomSelector> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Slider(
        value: widget.zoom.value,
        onChanged: (value) {
          setState(() {
            widget.zoom.value = value;
          });
        },
      ),
    );
  }
}
