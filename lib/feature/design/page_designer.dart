import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/component/pages_viewer.dart';
import 'package:jsonschema/core/designer/component/props_viewer.dart';
import 'package:jsonschema/core/designer/component/widget_cmp_choiser.dart';
import 'package:jsonschema/core/designer/cw_factory.dart';
import 'package:jsonschema/widget/widget_split.dart';
import 'package:jsonschema/widget/widget_tab.dart';

class PageDesigner extends StatefulWidget {
  const PageDesigner({super.key});

  @override
  State<PageDesigner> createState() => _PageDesignerState();
}

class _PageDesignerState extends State<PageDesigner> {
  WidgetFactory factory = WidgetFactory();

  @override
  void initState() {
    factory.addPage();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SplitView(
      primaryWidth: 300,
      children: [
        WidgetTab(
          listTab: [Tab(text: 'Properties')],
          listTabCont: [
            PropsViewer(key: factory.keyPropsViewer, factory: factory),
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
                child: factory.getRootSlot(),
              ),
            ),

            WidgetTab(
              listTab: [Tab(text: 'Components')],
              listTabCont: [WidgetChoiser()],
              heightTab: 30,
            ),
          ],
        ),
      ],
    );
  }
}
