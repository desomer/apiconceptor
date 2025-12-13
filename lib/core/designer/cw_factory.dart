import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/component/helper/over_props_viewer.dart';
import 'package:jsonschema/core/designer/core/widget_drag_utils.dart';
import 'package:jsonschema/core/designer/core/widget_overlay_selector.dart';
import 'package:jsonschema/core/designer/widget/cw_appbar.dart';
import 'package:jsonschema/core/designer/widget/cw_container.dart';
import 'package:jsonschema/core/designer/widget/cw_input.dart';
import 'package:jsonschema/core/designer/widget/cw_page.dart';
import 'package:jsonschema/core/designer/cw_slot.dart';
import 'package:jsonschema/core/designer/cw_widget.dart';
import 'package:jsonschema/core/designer/widget/cw_tab.dart';
import 'package:jsonschema/main.dart';

typedef BuilderWidget = CwWidget Function(CwWidgetCtx ctx);
typedef CacheWidget = Widget Function(CwWidgetCtx ctx);
typedef BuilderWidgetConfig = CwWidgetConfig Function(CwWidgetCtx ctx);
typedef OnDrapWidgetConfig = void Function(CwWidgetCtx ctx, DropCtx drag);
typedef OnDropWidgetConfig = void Function(CwWidgetCtx ctx, DropCtx drag);
typedef OnActionWidgetConfig = void Function(CwWidgetCtx ctx, DesignAction action);

const String cwType = 'type';
const String cwId = 'id';
const String cwProps = 'props';
const String cwPropsSlot = 'propsSlot';
const String cwSlots = 'slots';

class WidgetFactory {
  GlobalKey keyPropsViewer = GlobalKey();

  WidgetFactory() {
    CwPage.initFactory(this);
    CwAppBar.initFactory(this);
    CwInput.initFactory(this);
    CwContainer.initFactory(this);
    CwTabBar.initFactory(this);
  }

  Map<String, BuilderWidget> builderWidget = {};
  Map<String, BuilderWidgetConfig> builderConfig = {};
  Map<String, OnDrapWidgetConfig> builderDragConfig = {};

  Map<String, dynamic> data = {cwSlots: {}};

  Map<String, dynamic> addPage() {
    Map<String, dynamic> pages = {
      cwId: '',
      cwType: 'page',
      cwProps: <String, dynamic>{'color': 'FF448AFF'},
    };
    data[cwSlots][''] = pages;

    addInSlot(pages, 'body', {
      cwType: 'container',
      cwProps: <String, dynamic>{},
    });

    var appbar = addInSlot(pages, 'appbar', <String, dynamic>{
      cwType: 'appbar',
    });
    addInSlot(appbar, 'title', {
      cwType: 'input',
      cwProps: <String, dynamic>{'label': 'Page Title'},
    });
    return pages;
  }

  CwSlot getSlot(CwWidgetCtx parent, String id) {
    var ctx = parent.getSlotCtx(id);
    return CwSlot(config: CwSlotConfig(ctx: ctx));
  }

  Map<String, dynamic> addInSlot(
    Map<String, dynamic> wd,
    String id,
    Map<String, dynamic> child,
  ) {
    var slots = wd[cwSlots] as Map?;
    if (slots == null) {
      slots = {};
      wd[cwSlots] = slots;
    }
    child[cwId] = id;
    slots[id] = child;
    return child;
  }

  CwWidget getWidget(CwWidgetCtx ctx) {
    var w = builderWidget[ctx.getData()![cwType]]!(ctx);
    return w;
  }

  CwSlot getRootSlot() {
    var d = data[cwSlots][''];
    return CwSlot(
      config: CwSlotConfig(
        ctx:
            CwWidgetCtx(id: d[cwId], aFactory: this)
              ..inSlotName = 'page'
              ..dataWidget = d,
      )..withDragAndDrop = false,
    );
  }

  List<Widget> listPropsEditor = [];

  String prettyPrintJson(dynamic input) {
    //const JsonDecoder decoder = JsonDecoder();
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(input);
  }

  void displayProps(CwWidgetCtx ctx) {
    print("frame json = ${prettyPrintJson(data[cwSlots][''])}");

    listPropsEditor.clear();

    CwWidgetCtx? aCtx = ctx;
    while (aCtx != null) {
      addPropsLayer(aCtx);
      aCtx = aCtx.parentCtx;
    }

    keyPropsViewer.currentState
    // ignore: invalid_use_of_protected_member
    ?.setState(() {}); // force refresh props viewer
  }

  void addPropsLayer(CwWidgetCtx aCtx) {
    var config = aCtx.getConfig();
    List<Widget> listPropsWidget = [];
    var data = '${aCtx.inSlotName} [${aCtx.getData()?[cwType] ?? 'Empty'}]';

    listPropsWidget.add(
      Container(
        margin: EdgeInsets.fromLTRB(0, 0, 0, 5),
        width: double.infinity,
        padding: const EdgeInsets.all(3),
        color: ThemeHolder.theme.colorScheme.secondaryContainer,
        child: Center(
          child: Text(
            data,
            style: TextStyle(color: Colors.white60, fontSize: 14),
          ),
        ),
      ),
    );

    for (CwWidgetProperties prop in config?.properties ?? []) {
      listPropsWidget.add(prop.input!);
    }

    if (aCtx.slotProps?.slotConfig != null) {
      // le config du slot
      config = aCtx.slotProps!.slotConfig!(aCtx.cloneForSlot());

      for (CwWidgetProperties prop in config.properties) {
        listPropsWidget.add(prop.input!);
      }
    }

    listPropsEditor.add(
      WidgetOverCmp(child: Column(children: listPropsWidget)),
    );

    //-------------------------------------------------
  }
}
