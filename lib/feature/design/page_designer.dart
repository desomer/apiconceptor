import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/component/pages_viewer.dart';
import 'package:jsonschema/core/designer/component/props_viewer.dart';
import 'package:jsonschema/core/designer/component/widget_cmp_choiser.dart';
import 'package:jsonschema/core/designer/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/cw_factory_bloc.dart';
import 'package:jsonschema/main.dart';
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
      var d = prefs.getString("page_designer_data");
      if (d != null) {
        var saveData = jsonDecode(d);
        CwFactoryBloc()
            .createRepositoryIfNeeded(widget.factory, saveData, true)
            .then((_) {
              widget.factory.data = saveData;
              setState(() {});
            });
      } else {
        widget.factory.initEmptyPage();
        // Future.delayed(Duration(milliseconds: 500), () {
        //   widget.factory.rootCtx?.selectOnDesigner();
        // });
      }
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    widget.factory.mode = widget.mode;

    var rootSlot = widget.factory.getRootSlot();
    widget.factory.onStarted?.call();

    if (widget.mode == DesignMode.viewer) {
      var j = jsonEncode(widget.factory.data);
      prefs.setString("page_designer_data", j);

      return PagesDesignerViewer(
        cWDesignerMode: false,
        aFactory: widget.factory,
        child: rootSlot,
      );
    }

    return SplitView(
      key: widget.factory.designRootKey,
      primaryWidth: 300,
      children: [
        WidgetTab(
          listTab: [
            Tab(
              child: Row(
                spacing: 5,
                mainAxisSize: MainAxisSize.min,
                children: const [Icon(Icons.layers_outlined), Text("Stack")],
              ),
            ), //icon: Icon(Icons.layers_outlined)
            Tab(
              child: Row(
                spacing: 5,
                mainAxisSize: MainAxisSize.min,
                children: const [Icon(Icons.style), Text("Style")],
              ),
            ), //icon: Icon(Icons.style)
          ],
          listTabCont: [
            PropsViewer(
              key: widget.factory.keyPropsViewer,
              factory: widget.factory,
            ),
            StyleViewer(
              key: widget.factory.keyStyleViewer,
              factory: widget.factory,
            ),
          ],
          heightTab: 40,
        ),
        SplitView(
          secondaryWidth: 300,
          primaryWidth: -1,
          children: [
            GestureDetector(
              onTap: () {}, // evite le bip au cliq
              child: PagesDesignerViewer(
                cWDesignerMode: true,
                aFactory: widget.factory,
                child: rootSlot,
              ),
            ),

            WidgetTab(
              listTab: [Tab(text: 'Components'), Tab(text: 'Pages')],
              listTabCont: [
                WidgetChoiser(factory: widget.factory),
                Container(),
              ],
              heightTab: 30,
            ),
          ],
        ),
      ],
    );
  }
}
