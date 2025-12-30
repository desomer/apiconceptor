import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/component/helper/helper_editor.dart';
import 'package:jsonschema/core/designer/cw_factory.dart';
import 'package:jsonschema/core/designer/cw_slot.dart';
import 'package:jsonschema/core/designer/cw_widget.dart';
import 'package:jsonschema/widget/widget_tab.dart';

class CwTabBar extends CwWidget {
  const CwTabBar({super.key, required super.ctx});

  static void initFactory(WidgetFactory factory) {
    factory.register(
      id: 'tabbar',
      build: (ctx) => CwTabBar(ctx: ctx),
      config: (ctx) {
        return CwWidgetConfig();
      },
      populateOnDrag: (ctx, drag) {
        // ajoute deux onglets par défaut
        ctx.aFactory.addInSlot(drag.childData!, 'tab0', {
          cwType: 'input',
          cwProps: <String, dynamic>{'label': 'Tab Title 1'},
        });
        ctx.aFactory.addInSlot(drag.childData!, 'tab1', {
          cwType: 'input',
          cwProps: <String, dynamic>{'label': 'Tab Title 2'},
        });
      },
    );
  }

  @override
  State<CwTabBar> createState() => _CwTabBarState();
}

class _CwTabBarState extends CwWidgetState<CwTabBar> with HelperEditor {
  @override
  Widget build(BuildContext context) {
    return buildWidget(true, (ctx, constraints) {
      List<Widget> tabs = [];
      List<Widget> tabsView = [];
      int nb = 2;
      for (var i = 0; i < nb; i++) {
        tabs.add(Tab(child: getSlot(CwSlotProp(id: 'tab$i', name: 'Tab'))));
        tabsView.add(getSlot(CwSlotProp(id: 'tabview$i', name: 'Tab view')));
      }
      bool hasBoundedHeight = constraints?.hasBoundedHeight ?? true;
      bool hasBoundedWidth = constraints?.hasBoundedWidth ?? true;
      if (!hasBoundedWidth) {
        return SizedBox(
          width: 100.0 * nb,
          child: WidgetTab(
            listTab: tabs,
            listTabCont: tabsView,
            heightTab: 40,
            heightContent: !hasBoundedHeight,
          ),
        );
      } else {
        return WidgetTab(
          listTab: tabs,
          listTabCont: tabsView,
          heightTab: 40,
          heightContent: !hasBoundedHeight,
        );
      }
    });
  }
}
