import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/component/helper/over_props_viewer.dart';
import 'package:jsonschema/core/designer/core/widget_drag_utils.dart';
import 'package:jsonschema/core/designer/core/widget_event_bus.dart';
import 'package:jsonschema/core/designer/core/widget_overlay_selector.dart';
import 'package:jsonschema/core/designer/core/widget_popup_action.dart';
import 'package:jsonschema/core/designer/core/widget_selectable.dart';
import 'package:jsonschema/core/designer/cw_factory_style.dart';
import 'package:jsonschema/core/designer/cw_repository.dart';
import 'package:jsonschema/core/designer/widget/cw_action.dart';
import 'package:jsonschema/core/designer/widget/cw_appbar.dart';
import 'package:jsonschema/core/designer/widget/cw_container.dart';
import 'package:jsonschema/core/designer/widget/cw_divider.dart';
import 'package:jsonschema/core/designer/widget/cw_input.dart';
import 'package:jsonschema/core/designer/widget/cw_list.dart';
import 'package:jsonschema/core/designer/widget/cw_page.dart';
import 'package:jsonschema/core/designer/cw_slot.dart';
import 'package:jsonschema/core/designer/cw_widget.dart';
import 'package:jsonschema/core/designer/widget/cw_tab.dart';
import 'package:jsonschema/core/designer/widget/cw_table.dart';
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
const String cwStyle = 'style';

class WidgetFactory {
  GlobalKey keyPropsViewer = GlobalKey(debugLabel: "keyPropsViewer");
  GlobalKey keyStyleViewer = GlobalKey(debugLabel: "keyStyleViewer");
  GlobalKey<WidgetPopupActionState> popupActionKey =
      GlobalKey<WidgetPopupActionState>(debugLabel: "popupActionKey");

  GlobalKey designRootKey = GlobalKey(debugLabel: 'designRoot');
  GlobalKey pageDesignerKey = GlobalKey(debugLabel: "pageDesignerKey");

  GlobalKey designViewPortKey = GlobalKey(debugLabel: 'designViewPortKey');
  GlobalKey designerKey = GlobalKey(debugLabel: 'designerKey');
  GlobalKey scaleKeyMin = GlobalKey(debugLabel: 'scaleKeyMin');
  GlobalKey scaleKey100 = GlobalKey(debugLabel: 'scaleKey100');
  GlobalKey scaleKeyMax = GlobalKey(debugLabel: 'scaleKeyMax');

  void initAllGlobalKeys() {
    keyPropsViewer = GlobalKey(debugLabel: "keyPropsViewer");
    keyStyleViewer = GlobalKey(debugLabel: "keyStyleViewer");
    popupActionKey = GlobalKey<WidgetPopupActionState>(
      debugLabel: "popupActionKey",
    );

    designRootKey = GlobalKey(debugLabel: 'designRoot');
    pageDesignerKey = GlobalKey(debugLabel: "pageDesignerKey");

    designViewPortKey = GlobalKey(debugLabel: 'designViewPortKey');
    designerKey = GlobalKey(debugLabel: 'designerKey');
    scaleKeyMin = GlobalKey(debugLabel: 'scaleKeyMin');
    scaleKey100 = GlobalKey(debugLabel: 'scaleKey100');
    scaleKeyMax = GlobalKey(debugLabel: 'scaleKeyMax');
  }

  DesignMode mode = DesignMode.designer;

  Map<String, BuilderWidget> builderWidget = {};
  Map<String, BuilderWidgetConfig> builderConfig = {};
  Map<String, OnDrapWidgetConfig> builderDragConfig = {};

  Map<String, dynamic> data = {cwSlots: {}};
  Map<String, CwRepository> mapRepositories = {};

  CwWidgetCtx? rootCtx;
  CwWidgetCtx? lastSelectedCtx;

  Map<String, Size> cacheSizeSlots = {};
  Function? onStarted;

  List<Widget> listPropsEditor = [];
  List<Widget> listStyleEditor = [];

  var cwFactoryStyle = CWFactoryStyle();

  WidgetFactory() {
    CwPage.initFactory(this);
    CwAppBar.initFactory(this);
    CwInput.initFactory(this);
    CwContainer.initFactory(this);
    CwTabBar.initFactory(this);
    CwAction.initFactory(this);
    CwList.initFactory(this);
    CwDivider.initFactory(this);
    CwTable.initFactory(this);
  }

  set isStarted(bool isStarted) {}

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

  Map<String, dynamic> initEmptyPage() {
    mapRepositories.clear();

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

  CwSlot getSlot(CwWidgetCtx parent, String id, {Map? data}) {
    var ctx = parent.getSlotCtx(id, data: data);
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

  Widget getRootSlot() {
    var d = data[cwSlots][''];

    if (d == null) {
      return Container();
    }

    rootCtx =
        CwWidgetCtx(slotId: d[cwId], aFactory: this, parentCtx: null)
          ..selectorCtxIfDesign?.inSlotName = 'page'
          ..dataWidget = d;

    return CwSlot(config: CwSlotConfig(ctx: rootCtx!)..withDragAndDrop = false);
  }

  // String prettyPrintJson(dynamic input) {
  //   const JsonEncoder encoder = JsonEncoder.withIndent('  ');
  //   return encoder.convert(input);
  // }

  void displayProps(CwWidgetCtx ctx) {
    listPropsEditor.clear();

    CwWidgetCtx? aCtx = ctx;
    while (aCtx != null) {
      bool isIterable = addPropsLayer(aCtx);
      if (isIterable && listPropsEditor.length > 1) {
        var aIterable = listPropsEditor.removeLast();
        var header = Container(
          margin: EdgeInsets.fromLTRB(10, 5, 0, 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: ThemeHolder.theme.colorScheme.primary,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
                padding: EdgeInsets.all(1),
                child: Column(children: [...listPropsEditor]),
              ),
              Container(
                color: ThemeHolder.theme.colorScheme.primary,
                child: Icon(Icons.rotate_right, size: 17),
              ),
            ],
          ),
        );
        listPropsEditor.clear();
        listPropsEditor.add(header);
        listPropsEditor.add(aIterable);
      }
      aCtx = aCtx.parentCtx;
    }

    if (keyPropsViewer.currentState?.mounted == true) {
      // ignore: invalid_use_of_protected_member
      keyPropsViewer.currentState?.setState(
        () {},
      ); // force refresh props viewer
    }

    // afficher les styles
    listStyleEditor.clear();

    var initMargin = cwFactoryStyle.initMargin(ctx);
    if (initMargin.isNotEmpty) {
      listStyleEditor.add(getHeaderStyle('Margin'));
      for (CwWidgetProperties prop in initMargin) {
        listStyleEditor.add(prop.input!);
      }
    }
    var initPadding = cwFactoryStyle.initPadding(ctx);
    if (initPadding.isNotEmpty) {
      listStyleEditor.add(getHeaderStyle('Padding'));
      for (CwWidgetProperties prop in initPadding) {
        listStyleEditor.add(prop.input!);
      }
    }
    if (keyStyleViewer.currentState?.mounted == true) {
      // ignore: invalid_use_of_protected_member
      keyStyleViewer.currentState?.setState(
        () {},
      ); // force refresh props viewer
    }
  }

  Widget getHeaderStyle(String name) {
    return Container(
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
    );
  }

  bool addPropsLayer(CwWidgetCtx aCtx) {
    var config = aCtx.getConfig();
    List<Widget> listPropsWidget = [];
    var name =
        '${aCtx.getData()?[cwType] ?? 'Empty'} [${aCtx.selectorCtx.inSlotName}]';

    listPropsWidget.add(getHeaderProps(name, aCtx));

    for (CwWidgetProperties prop in config?.properties ?? const []) {
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

    return aCtx.isType('list') || aCtx.isType('table');
  }

  Widget getHeaderProps(String name, CwWidgetCtx aCtx) {
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
        ..path = onCtx.aWidgetPath,
    );
  }

  @override
  void onExit() {
    emit(CDDesignEvent.reselect, null);
  }
}
