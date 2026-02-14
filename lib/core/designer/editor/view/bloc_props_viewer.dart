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
      itemCount: widget.factory.cwFactoryProps.listPropsEditor.length,
      itemBuilder: (context, index) {
        return widget.factory.cwFactoryProps.listPropsEditor[index];
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
      itemCount: widget.factory.cwFactoryProps.listStyleEditor.length,
      itemBuilder: (context, index) {
        return widget.factory.cwFactoryProps.listStyleEditor[index];
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
      itemCount: widget.factory.cwFactoryProps.listStyleSelectorEditor.length,
      itemBuilder: (context, index) {
        return widget.factory.cwFactoryProps.listStyleSelectorEditor[index];
      },
    );
  }
}
//-------------------------------------------------------
class BehaviorSelectorViewer extends StatefulWidget {
  const BehaviorSelectorViewer({super.key, required this.factory});
  final WidgetFactory factory;

  @override
  State<BehaviorSelectorViewer> createState() => _BehaviorSelectorViewerState();
}

class _BehaviorSelectorViewerState extends State<BehaviorSelectorViewer> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: widget.factory.cwFactoryProps.listBehaviorEditor.length,
      itemBuilder: (context, index) {
        return widget.factory.cwFactoryProps.listBehaviorEditor[index];
      },
    );
  }
}