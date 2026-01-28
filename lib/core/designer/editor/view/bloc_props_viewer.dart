import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';

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

class StyleViewer extends StatefulWidget {
  const StyleViewer({super.key, required this.factory});
  final WidgetFactory factory;

  @override
  State<StyleViewer> createState() => _StyleViewerState();
}

class _StyleViewerState extends State<StyleViewer> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.factory.listStyleEditor.length,
      itemBuilder: (context, index) {
        return widget.factory.listStyleEditor[index];
      },
    );
  }
}

class StyleSelectorViewer extends StatefulWidget {
  const StyleSelectorViewer({super.key, required this.factory});
  final WidgetFactory factory;

  @override
  State<StyleSelectorViewer> createState() => _StyleSelectorViewerState();
}

class _StyleSelectorViewerState extends State<StyleSelectorViewer> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: widget.factory.listStyleSelectorEditor.length,
      itemBuilder: (context, index) {
        return widget.factory.listStyleSelectorEditor[index];
      },
    );
  }
}