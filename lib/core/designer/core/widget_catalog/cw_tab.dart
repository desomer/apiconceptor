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

class CwBar extends CwWidget {
  const CwBar({super.key, required super.ctx});

  static void initFactory(WidgetFactory factory) {
    factory.register(
      id: 'bar',
      build: (ctx) => CwBar(key: ctx.getKey(), ctx: ctx),
      config: (ctx) {
        return CwWidgetConfig()
            .addProp(
              CwWidgetProperties(id: 'type', name: 'view type')..isToogle(ctx, [
                {'icon': Icons.tab, 'value': 'tab'},
                {'icon': Icons.toggle_off_outlined, 'value': 'toggle'},
                {'icon': Icons.smart_button_rounded, 'value': 'bar'},
              ], defaultValue: 'label'),
            )
            .addProp(
              CwWidgetProperties(id: 'bottomView', name: 'with view bottom')
                ..isBool(ctx),
            );
      },
      populateOnDrag: (ctx, drag) {
        bool hasBottomView = true;
        if (const [
          'bottombar',
          'appbarbottom',
        ].contains(ctx.slotProps?.type ?? "")) {
          hasBottomView = false;
        }
        drag.childData![cwProps]?['nbchild'] = 2;
        drag.childData![cwProps]?['bottomView'] = hasBottomView;

        if (ctx.slotProps?.type == 'bottombar') {
          drag.childData![cwProps]?['type'] = 'bar';
        }

        // ajoute deux onglets par défaut
        ctx.aFactory.addInSlot(drag.childData!, 'tab_0', {
          cwImplement: 'action',
          cwProps: <String, dynamic>{'label': 'Tab Title 1'},
        });
        ctx.aFactory.addInSlot(drag.childData!, 'tab_1', {
          cwImplement: 'action',
          cwProps: <String, dynamic>{'label': 'Tab Title 2'},
        });
      },
    );
  }

  @override
  State<CwBar> createState() => _CwTabBarState();
}

class _CwTabBarState extends CwWidgetState<CwBar>
    with HelperEditor, TickerProviderStateMixin {
  TabController? ctlr;

  @override
  Widget build(BuildContext context) {
    return buildWidget(true, ModeBuilderWidget.constraintBuilder, (
      ctx,
      constraints,
    ) {
      List<Widget> tabs = [];
      List<Widget> tabsView = [];

      int nbTab = getIntProp(ctx, 'nbchild') ?? 1;
      String apparence = getStringProp(ctx, 'type') ?? 'tab';
      if (apparence == 'bar' && nbTab < 2) {
        nbTab = 2;
      }

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

      String? typeAction;
      switch (apparence) {
        case "tab":
          typeAction = "tab";
          break;
        case "toggle":
          typeAction = "tabslider";
          break;
        case "bar":
          typeAction = "navigationdestination";
          break;
        default:
      }

      for (var i = 0; i < nbTab; i++) {
        tabs.add(
          buildTab(
            apparence,
            getSlot(
              CwSlotProp(
                id: 'tab_$i',
                name: 'Tab',
                onAction: onActionCell,
                type: typeAction,
              ),
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

      bool withBottomView = getBoolProp(ctx, 'bottomView') ?? false;
      Color? fgColor = styleFactory.getColor('fgColor');
      Color? bgColor = styleFactory.getColor('bgColor');

      if (apparence == "toggle") {
        return SizedBox(
          width: !hasBoundedWidth ? 300 : null,
          height: !hasBoundedHeight ? 300 : null,
          child: WidgetTabSlider(listTab: tabs, listTabCont: tabsView),
        );
      }

      if (apparence == "bar") {
        return NavigationBar(
          destinations: tabs,
          indicatorColor: fgColor,
          backgroundColor: bgColor,
          labelPadding: styleFactory.config.edgePadding,
          elevation: styleFactory.getElevation(),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            return styleFactory.getTextStyle(null);
          }),
        );
      }

      if (!withBottomView) {
        if (nbTab != ctlr?.length) {
          ctlr?.dispose();
          ctlr = null;
        }
        ctlr ??= TabController(length: nbTab, vsync: this);
        return hasBoundedWidth
            ? TabBar(
              indicatorColor: fgColor,
              labelColor: fgColor,
              controller: ctlr,
              tabs: tabs,
            )
            : IntrinsicWidth(
              child: TabBar(
                indicatorColor: fgColor,
                labelColor: fgColor,
                controller: ctlr,
                tabs: tabs,
              ),
            );
      }

      if (!hasBoundedWidth) {
        return SizedBox(
          width: 100.0 * nbTab,
          child: WidgetTab(
            listTab: tabs,
            fgColor: fgColor,
            listTabCont: tabsView,
            heightTab: 40,
            heightContent: !hasBoundedHeight,
          ),
        );
      } else {
        return WidgetTab(
          listTab: tabs,
          fgColor: fgColor,
          listTabCont: tabsView,
          heightTab: 40,
          heightContent: !hasBoundedHeight,
        );
      }
    });
  }

  Widget buildTab(String apparence, Widget child) {
    if (apparence == "tab") {
      return Tab(child: child);
      // } else if (apparence == "bar") {
      //   return NavigationDestination(icon: child, label: 'toto');
    } else {
      return child;
    }
  }
}
