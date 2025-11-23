import 'package:flutter/material.dart';

class DragCtx {
  void doDragOn(Widget widget, BuildContext context) {}
}

class DragComponentCtx extends DragCtx {
  DragComponentCtx();

  @override
  void doDragOn(Widget widget, BuildContext context) {}
}

//-----------------------------------------------------------

class CWSlotImage extends StatefulWidget {
  const CWSlotImage({super.key});

  @override
  CWSlotImageState createState() => CWSlotImageState();
}

class CWSlotImageState extends State<CWSlotImage> {
  static Widget? wi;

  @override
  Widget build(BuildContext context) {
    return wi ?? const Text('vide');
  }
}
