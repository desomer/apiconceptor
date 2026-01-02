import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

typedef OnWidgetSizeChange = void Function(Size size);

class WidgetMeasureSize extends SingleChildRenderObjectWidget {
  final OnWidgetSizeChange onChange;

  const WidgetMeasureSize({super.key, required this.onChange, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderMeasureSize(onChange);
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  Size? oldSize;
  final OnWidgetSizeChange onChange;

  _RenderMeasureSize(this.onChange);

  @override
  void performLayout() {
    super.performLayout();
    if (child == null) return;
    Size newSize = child!.size;
    if (oldSize == newSize) return;
    oldSize = newSize;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onChange(newSize);
    });
  }
}