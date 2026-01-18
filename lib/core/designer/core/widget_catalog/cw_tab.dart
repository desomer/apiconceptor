import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jsonschema/core/designer/core/cw_factory_action.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_overlay_selector.dart';
import 'package:jsonschema/core/designer/editor/view/prop_editor/helper_editor.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/core/cw_slot.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';
import 'package:jsonschema/widget/widget_tab.dart';
import 'package:jsonschema/widget/widget_tab_slider.dart';

class CwTabBar extends CwWidget {
  const CwTabBar({super.key, required super.ctx});

  static void initFactory(WidgetFactory factory) {
    factory.register(
      id: 'tabbar',
      build: (ctx) => CwTabBar(key: ctx.getKey(), ctx: ctx),
      config: (ctx) {
        return CwWidgetConfig();
      },
      populateOnDrag: (ctx, drag) {
        // ajoute deux onglets par défaut
        ctx.aFactory.addInSlot(drag.childData!, 'tab0', {
          cwImplement: 'input',
          cwProps: <String, dynamic>{'label': 'Tab Title 1'},
        });
        ctx.aFactory.addInSlot(drag.childData!, 'tab1', {
          cwImplement: 'input',
          cwProps: <String, dynamic>{'label': 'Tab Title 2'},
        });
      },
    );
  }

  @override
  State<CwTabBar> createState() => _CwTabBarState();
}

class _CwTabBarState extends CwWidgetState<CwTabBar> with HelperEditor {
  String getApparence() {
    return "SLIDING";
  }

  @override
  Widget build(BuildContext context) {
    return buildWidget(true, ModeBuilderWidget.constraintBuilder, (
      ctx,
      constraints,
    ) {
      List<Widget> tabs = [];
      List<Widget> tabsView = [];

      int nbTab = getIntProp(ctx, 'nbchild') ?? 1;
      String apparence = getApparence();

      void onActionCell(CwWidgetCtx ctx, DesignAction action) {
        int nbCol = getIntProp(ctx.parentCtx!, 'nbchild') ?? 1;
        var props = ctx.parentCtx!.initPropsIfNeeded();
        int idx = int.parse(ctx.slotId.split('_').last);
        var actMgr = CwFactoryAction(ctx: ctx);
        print('OnActionCell action=$action');
        switch (action) {
          case DesignAction.delete:
            break;
          case DesignAction.addLeft:
            props['nbchild'] = nbCol + 1;
            actMgr.moveSlot('tab_', nbCol, idx);
            actMgr.moveSlot('tabview_', nbCol, idx);
            break;
          case DesignAction.addRight:
            props['nbchild'] = nbCol + 1;
            actMgr.moveSlot('tab_', nbCol, idx + 1);
            actMgr.moveSlot('tabview_', nbCol, idx + 1);
            break;
          case DesignAction.addBottom:
            break;
          case DesignAction.addTop:
            break;
          default:
        }
        SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
          if (mounted) {
            setState(() {});
            ctx.selectParentOnDesigner();
          }
        });
      }

      for (var i = 0; i < nbTab; i++) {
        tabs.add(
          buildTab(
            apparence,
            getSlot(
              CwSlotProp(id: 'tab_$i', name: 'Tab', onAction: onActionCell),
            ),
          ),
        );
        tabsView.add(
          getSlot(
            CwSlotProp(
              id: 'tabview_$i',
              name: 'Tab view',
              onAction: onActionCell,
            ),
          ),
        );
      }
      bool hasBoundedHeight = constraints?.hasBoundedHeight ?? true;
      bool hasBoundedWidth = constraints?.hasBoundedWidth ?? true;

      if (apparence == "SLIDING") {
        return SizedBox(
          width: !hasBoundedWidth ? 300 : null,
          height: !hasBoundedHeight ? 300 : null,
          child: WidgetTabSlider(listTab: tabs, listTabCont: tabsView),
        );
      }

      if (!hasBoundedWidth) {
        return SizedBox(
          width: 100.0 * nbTab,
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

  Widget buildTab(String apparence, Widget child) {
    if (apparence == "SLIDING") {
      return child;
    } else {
      return Tab(child: child);
    }
  }
}
