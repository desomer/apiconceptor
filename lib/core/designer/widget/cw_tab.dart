import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/component/helper/helper_editor.dart';
import 'package:jsonschema/core/designer/cw_factory.dart';
import 'package:jsonschema/core/designer/cw_slot.dart';
import 'package:jsonschema/core/designer/cw_widget.dart';
import 'package:jsonschema/widget/widget_tab.dart';

class CwTabBar extends CwWidget {
  const CwTabBar({super.key, required super.ctx});

  static void initFactory(WidgetFactory factory) {
    factory.builderWidget['tabbar'] = (ctx) {
      return CwTabBar(ctx: ctx);
    };

    factory.builderConfig['tabbar'] = (ctx) {
      return CwWidgetConfig(id: "tabbar")
      // .addProp(
      //   CwWidgetProperties(id: 'drawer', name: 'with drawer')..isBool(
      //     ctx,
      //     onJsonChanged: (value) {
      //       ctx.onValueChange(repaint: false)(value);
      //       ctx.parentCtx!.onValueChange()(value);
      //     },
      //   ),
      // )
      ;
    };

    factory.builderDragConfig['tabbar'] = (ctx, drag) {
      ctx.aFactory.addInSlot(drag.childData!, 'tab0', {
        cwType: 'input',
        cwProps: <String, dynamic>{'label': 'Tab Title 1'},
      });      
      ctx.aFactory.addInSlot(drag.childData!, 'tab1', {
        cwType: 'input',
        cwProps: <String, dynamic>{'label': 'Tab Title 2'},
      });
    };
  }

  @override
  State<CwTabBar> createState() => _CwPageState();
}

class _CwPageState extends CwWidgetState<CwTabBar> with HelperEditor {
  @override
  Widget build(BuildContext context) {
    return buildWidget((ctx) {
      List<Widget> tabs = [];
      List<Widget> tabsView = [];
      for (var i = 0; i < 2; i++) {
        tabs.add(Tab(child: getSlot(CwSlotProp(id: 'tab$i', name: 'Tab'))));
        tabsView.add(getSlot(CwSlotProp(id: 'tabview', name: 'Tab view')));
      }

      return WidgetTab(listTab: tabs, listTabCont: tabsView, heightTab: 40);
    });
  }
}
