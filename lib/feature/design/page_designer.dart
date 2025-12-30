import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/component/pages_viewer.dart';
import 'package:jsonschema/core/designer/component/props_viewer.dart';
import 'package:jsonschema/core/designer/component/widget_cmp_choiser.dart';
import 'package:jsonschema/core/designer/cw_factory.dart';
import 'package:jsonschema/widget/widget_split.dart';
import 'package:jsonschema/widget/widget_tab.dart';

enum DesignMode { designer, viewer }

class PageDesigner extends StatefulWidget {
  const PageDesigner({super.key, required this.mode, required this.factory});
  final WidgetFactory factory;
  final DesignMode mode;

  @override
  State<PageDesigner> createState() => _PageDesignerState();
}

class _PageDesignerState extends State<PageDesigner> {
  @override
  void initState() {
    Map slot = widget.factory.data[cwSlots] ?? {};
    if (slot.isEmpty) {
      widget.factory.addPage();
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {

    widget.factory.mode = widget.mode;  
    if (widget.mode == DesignMode.viewer) {
      return PagesDesignerViewer(
        cWDesignerMode: false,
        child: widget.factory.getRootSlot(),
      );
    }

    return SplitView(
      primaryWidth: 300,
      children: [
        WidgetTab(
          listTab: [
            Tab(icon: Icon(Icons.layers_outlined)),
            Tab(icon: Icon(Icons.style)),
          ],
          listTabCont: [
            PropsViewer(
              key: widget.factory.keyPropsViewer,
              factory: widget.factory,
            ),
            Container(),
          ],
          heightTab: 30,
        ),
        SplitView(
          secondaryWidth: 300,
          primaryWidth: -1,
          children: [
            GestureDetector(
              onTap: () {}, // evite le bip au cliq
              child: PagesDesignerViewer(
                cWDesignerMode: true,
                child: widget.factory.getRootSlot(),
              ),
            ),

            WidgetTab(
              listTab: [Tab(text: 'Components')],
              listTabCont: [WidgetChoiser(factory: widget.factory)],
              heightTab: 30,
            ),
          ],
        ),
      ],
    );
  }
}
