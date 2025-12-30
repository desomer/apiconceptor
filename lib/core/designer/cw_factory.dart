import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/component/helper/over_props_viewer.dart';
import 'package:jsonschema/core/designer/core/widget_drag_utils.dart';
import 'package:jsonschema/core/designer/core/widget_event_bus.dart';
import 'package:jsonschema/core/designer/core/widget_overlay_selector.dart';
import 'package:jsonschema/core/designer/core/widget_selectable.dart';
import 'package:jsonschema/core/designer/cw_repository.dart';
import 'package:jsonschema/core/designer/widget/cw_action.dart';
import 'package:jsonschema/core/designer/widget/cw_appbar.dart';
import 'package:jsonschema/core/designer/widget/cw_container.dart';
import 'package:jsonschema/core/designer/widget/cw_input.dart';
import 'package:jsonschema/core/designer/widget/cw_list.dart';
import 'package:jsonschema/core/designer/widget/cw_page.dart';
import 'package:jsonschema/core/designer/cw_slot.dart';
import 'package:jsonschema/core/designer/cw_widget.dart';
import 'package:jsonschema/core/designer/widget/cw_tab.dart';
import 'package:jsonschema/feature/design/page_designer.dart';
import 'package:jsonschema/main.dart';

typedef BuilderWidget = CwWidget Function(CwWidgetCtx ctx);
typedef CacheWidget =
    Widget Function(CwWidgetCtx ctx, BoxConstraints? constraints);
typedef BuilderWidgetConfig = CwWidgetConfig Function(CwWidgetCtx ctx);
typedef OnDrapWidgetConfig = void Function(CwWidgetCtx ctx, DropCtx drag);
typedef OnDropWidgetConfig = void Function(CwWidgetCtx ctx, DropCtx drag);
typedef OnActionWidgetConfig =
    void Function(CwWidgetCtx ctx, DesignAction action);

const String cwType = 'type';
const String cwId = 'id';
const String cwProps = 'props';
const String cwPropsSlot = 'propsSlot';
const String cwSlots = 'slots';

class WidgetFactory {
  GlobalKey keyPropsViewer = GlobalKey();
  DesignMode mode = DesignMode.designer;

  WidgetFactory() {
    CwPage.initFactory(this);
    CwAppBar.initFactory(this);
    CwInput.initFactory(this);
    CwContainer.initFactory(this);
    CwTabBar.initFactory(this);
    CwAction.initFactory(this);
    CwList.initFactory(this);
  }

  void register({
    required String id,
    required BuilderWidget build,
    required BuilderWidgetConfig config,
    OnDrapWidgetConfig? populateOnDrag,
  }) {
    builderWidget[id] = build;
    builderConfig[id] = config;
    if (populateOnDrag != null) {
      builderDragConfig[id] = populateOnDrag;
    }
  }

  Map<String, BuilderWidget> builderWidget = {};
  Map<String, BuilderWidgetConfig> builderConfig = {};
  Map<String, OnDrapWidgetConfig> builderDragConfig = {};

  Map<String, dynamic> data = {cwSlots: {}};
  Map<String, CwRepository> mapRepositories = {};

  Map<String, dynamic> addPage() {
    Map<String, dynamic> pages = {
      cwId: '',
      cwType: 'page',
      cwProps: <String, dynamic>{
        'color': 'FF448AFF',
        'fullheight': true,
        'drawer': true,
        'fixDrawer': true,
      },
    };
    data[cwSlots][''] = pages;

    addInSlot(pages, 'body', {
      cwType: 'container',
      cwProps: <String, dynamic>{},
    });

    var appbar = addInSlot(pages, 'appbar', <String, dynamic>{
      cwType: 'appbar',
      cwProps: <String, dynamic>{},
    });
    addInSlot(appbar, 'title', {
      cwType: 'input',
      cwProps: <String, dynamic>{'label': 'Page Title'},
    });
    return pages;
  }

  bool isModeDesigner() {
    return mode == DesignMode.designer;
  }

  bool isModeViewer() {
    return mode == DesignMode.viewer;
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

  Map<String, dynamic> addCmpInSlot(
    Map<String, dynamic> wd,
    String id, {
    required String cmpType,
    Map<String, dynamic>? props,
    Map<String, dynamic>? slotProps,
  }) {
    var slots = wd[cwSlots] as Map?;
    if (slots == null) {
      slots = {};
      wd[cwSlots] = slots;
    }
    var child = <String, dynamic>{
      cwType: cmpType,
      if (props != null) cwProps: props,
      if (slotProps != null) cwPropsSlot: slotProps,
    };
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

  // String prettyPrintJson(dynamic input) {
  //   const JsonEncoder encoder = JsonEncoder.withIndent('  ');
  //   return encoder.convert(input);
  // }

  void displayProps(CwWidgetCtx ctx) {
    // print("frame json = ${prettyPrintJson(data[cwSlots][''])}");

    listPropsEditor.clear();

    CwWidgetCtx? aCtx = ctx;
    while (aCtx != null) {
      addPropsLayer(aCtx);
      aCtx = aCtx.parentCtx;
    }

    // ignore: invalid_use_of_protected_member
    keyPropsViewer.currentState?.setState(() {}); // force refresh props viewer
  }

  void addPropsLayer(CwWidgetCtx aCtx) {
    var config = aCtx.getConfig();
    List<Widget> listPropsWidget = [];
    var name = '${aCtx.getData()?[cwType] ?? 'Empty'} [${aCtx.inSlotName}]';

    listPropsWidget.add(getHeader(name, aCtx));

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
      WidgetOverCmp(
        path: aCtx,
        overMgr: HoverCmpManagerImpl(),
        child: Column(children: listPropsWidget),
      ),
    );

    //-------------------------------------------------
  }

  Widget getHeader(String name, CwWidgetCtx aCtx) {
    return GestureDetector(
      onTap: () {
        aCtx.selectOnDesigner();
      },
      child: Container(
        margin: EdgeInsets.fromLTRB(0, 0, 0, 5),
        width: double.infinity,
        padding: const EdgeInsets.all(3),
        color: ThemeHolder.theme.colorScheme.secondaryContainer,
        child: Center(
          child: Text(
            name,
            style: TextStyle(color: Colors.white60, fontSize: 14),
          ),
        ),
      ),
    );
  }
}

class HoverCmpManagerImpl extends HoverCmpManager {
  @override
  void onHover(CwWidgetCtx onCtx) {
    //print('hover on ${onCtx.aPath}');
    emit(
      CDDesignEvent.select,
      CWEventCtx()
        ..extra = {'displayProps': false}
        ..ctx = onCtx
        ..path = onCtx.aPath
        ..keybox = onCtx.selectableState?.captureKey,
    );
  }

  @override
  void onExit() {
    emit(CDDesignEvent.reselect, null);
  }
}
