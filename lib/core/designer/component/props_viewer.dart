import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/cw_factory.dart';

class PropsViewer extends StatefulWidget {
  const PropsViewer({super.key, required this.factory});
  final WidgetFactory factory;

  @override
  State<PropsViewer> createState() => _PropsViewerState();
}

class _PropsViewerState extends State<PropsViewer> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.factory.listPropsEditor.length,
      itemBuilder: (context, index) {
        return widget.factory.listPropsEditor[index];
      },
    );
  }
}
