import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/editor/view/pages_viewer.dart';
import 'package:jsonschema/core/designer/editor/view/bloc_props_viewer.dart';
import 'package:jsonschema/core/designer/editor/view/bloc_drag_components.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/core/cw_factory_bloc.dart';
import 'package:jsonschema/core/designer/editor/view/bloc_drag_pages.dart';
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
  bool isInitialized = false;

  @override
  void initState() {
    Map app = widget.factory.appData[cwApp] ?? {};
    if (app.isEmpty) {
      var d = prefs.getString("page_designer_data");
      if (d != null) {
        var saveData = jsonDecode(d);
        CwFactoryBloc()
            .createRepositoriesIfNeeded(widget.factory, saveData, true)
            .then((_) {
              // affiche apres avoir tout charger les repositories
              widget.factory.appData = saveData;
              isInitialized = true;
              setState(() {});
            });
      } else {
        widget.factory.getEmptyApp();
        isInitialized = true;
        // Future.delayed(Duration(milliseconds: 500), () {
        //   widget.factory.rootCtx?.selectOnDesigner();
        // });
      }
    } else {
      isInitialized = true;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    widget.factory.mode = widget.mode;

    if (isInitialized) {
      isInitialized = false;
      widget.factory.onStarted?.call();
    }
    Widget rootSlot = widget.factory.getRootSlot('/');

    if (widget.mode == DesignMode.viewer) {
      var j = jsonEncode(widget.factory.appData);
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
          onInitController: (widgetTabController) {
            widget.factory.controllerTabProps = widgetTabController;
          },
          listTab: [
            Tab(
              child: Row(
                spacing: 5,
                mainAxisSize: MainAxisSize.min,
                children: const [Icon(Icons.layers_outlined), Text("layout")],
              ),
            ), //icon: Icon(Icons.layers_outlined)
            Tab(
              child: Row(
                spacing: 5,
                mainAxisSize: MainAxisSize.min,
                children: const [Icon(Icons.style), Text("Style")],
              ),
            ), //icon: Icon(Icons.style)
            Tab(
              child: Row(
                spacing: 5,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.electric_bolt_rounded),
                  Text("Behavior"),
                ],
              ),
            ), //icon: Icon(Icons.style)
          ],
          listTabCont: [
            PropsViewer(
              key: widget.factory.keyPropsViewer,
              factory: widget.factory,
            ),
            Column(
              children: [
                StyleSelectorViewer(
                  key: widget.factory.keyStyleSelectorViewer,
                  factory: widget.factory,
                ),
                Expanded(
                  child: StyleViewer(
                    key: widget.factory.keyStyleViewer,
                    factory: widget.factory,
                  ),
                ),
              ],
            ),
            BehaviorSelectorViewer(
              key: widget.factory.keyBehaviorViewer,
              factory: widget.factory,
            ),
          ],
          heightTab: 40,
        ),
        widget.factory.largeDesigner
            ? SplitView(
              secondaryWidth: 300,
              primaryWidth: -1,
              children: [getPageViewer(rootSlot), getTabComponent()],
            )
            : getPageViewer(rootSlot),
      ],
    );
  }

  Widget getPageViewer(Widget rootSlot) {
    return GestureDetector(
      onTap: () {}, // evite le bip au cliq
      child: PagesDesignerViewer(
        cWDesignerMode: true,
        aFactory: widget.factory,
        child: rootSlot,
      ),
    );
  }

  Widget getTabComponent() {
    return WidgetTab(
      listTab: [Tab(text: 'Components'), Tab(text: 'Pages & dialogs')],
      listTabCont: [
        WidgetChoiser(factory: widget.factory),
        WidgetPages(factory: widget.factory),
      ],
      heightTab: 30,
    );
  }
}
