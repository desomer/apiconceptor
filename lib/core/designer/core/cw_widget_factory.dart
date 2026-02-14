import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/core/designer/editor/view/bloc_properties.dart';
import 'package:jsonschema/core/designer/core/widget_catalog/cw_app.dart';
import 'package:jsonschema/core/designer/core/widget_catalog/cw_indicator.dart';
import 'package:jsonschema/core/designer/core/widget_catalog/cw_page_indicator.dart';
import 'package:jsonschema/core/designer/editor/view/helper/widget_hover.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_drag_utils.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_event_bus.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_overlay_selector.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_popup_action.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_selectable.dart';
import 'package:jsonschema/core/designer/core/cw_repository.dart';
import 'package:jsonschema/core/designer/core/widget_catalog/cw_action.dart';
import 'package:jsonschema/core/designer/core/widget_catalog/cw_appbar.dart';
import 'package:jsonschema/core/designer/core/widget_catalog/cw_container.dart';
import 'package:jsonschema/core/designer/core/widget_catalog/cw_divider.dart';
import 'package:jsonschema/core/designer/core/widget_catalog/cw_input.dart';
import 'package:jsonschema/core/designer/core/widget_catalog/cw_list.dart';
import 'package:jsonschema/core/designer/core/widget_catalog/cw_app_page.dart';
import 'package:jsonschema/core/designer/core/cw_slot.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';
import 'package:jsonschema/core/designer/core/widget_catalog/cw_tab.dart';
import 'package:jsonschema/core/designer/core/widget_catalog/cw_table.dart';
import 'package:jsonschema/core/designer/core/widget_catalog/cw_table_row.dart';
import 'package:jsonschema/core/util.dart';
import 'package:jsonschema/feature/design/page_designer.dart';
import 'package:jsonschema/widget/tree_editor/tree_view.dart';

class BuildInfo {
  bool isWidthChanged = false;
  BuildInfo();
}

typedef BuilderWidget = CwWidget Function(CwWidgetCtx ctx);
typedef CacheWidgetBuilder =
    Widget Function(
      CwWidgetCtx ctx,
      BoxConstraints? constraints,
      BuildInfo buildInfo,
    );
typedef BuilderWidgetConfig = CwWidgetConfig Function(CwWidgetCtx ctx);
typedef OnDrapWidgetConfig = void Function(CwWidgetCtx ctx, DropCtx drag);
typedef OnDropWidgetConfig = void Function(CwWidgetCtx ctx, DropCtx drag);
typedef OnActionWidgetConfig =
    void Function(CwWidgetCtx ctx, DesignAction action);

//const String cwRoutes = 'routes';
const String cwApp = 'app';
const String cwImplement = 'impl';
const String cwSlotId = 'slotId';
const String cwProps = 'props';
const String cwPropsSlot = 'propsSlot';
const String cwRepos = 'repositories';
const String cwSlots = 'slots';
const String cwStyle = 'style';
const String cwBehaviors = 'behaviors';
const String cwComputed = 'computed';
const String cwType = 'type';
const String cwRouteId = 'uid';
const String cwRoutePath = 'path';
const String cwRouteName = 'name';

LruCache cacheLinkPage = LruCache(5);
bool withWidgetCache = true;

class WidgetFactory {
  bool largeDesigner = false;
  GlobalKey keyPropsViewer = GlobalKey(debugLabel: "keyPropsViewer");
  GlobalKey keyStyleViewer = GlobalKey(debugLabel: "keyStyleViewer");
  GlobalKey keyStyleSelectorViewer = GlobalKey(
    debugLabel: "keyStyleSelectorViewer",
  );
  GlobalKey keyBehaviorViewer = GlobalKey(debugLabel: "keyBehaviorViewer");

  GlobalKey<TreeViewState> keyPagesViewer = GlobalKey(
    debugLabel: 'keyPagesViewer',
  );

  GlobalKey<WidgetPopupActionState> popupActionKey =
      GlobalKey<WidgetPopupActionState>(debugLabel: "popupActionKey");

  GlobalKey designRootKey = GlobalKey(debugLabel: 'designRoot');
  GlobalKey pageDesignerKey = GlobalKey(debugLabel: "pageDesignerKey");

  GlobalKey designViewPortKey = GlobalKey(debugLabel: 'designViewPortKey');
  GlobalKey designerKey = GlobalKey(debugLabel: 'designerKey');
  GlobalKey scaleKeyMin = GlobalKey(debugLabel: 'scaleKeyMin');
  GlobalKey scaleKey100 = GlobalKey(debugLabel: 'scaleKey100');
  GlobalKey scaleKeyMax = GlobalKey(debugLabel: 'scaleKeyMax');

  ValueNotifier<String>? routeControllerDesigner;
  ValueNotifier<String>? routeControllerViewer;

  List<Map> listSlotsPageInRouter = [];
  Map<String, String> mapPath2PathSlot = {};

  void initAllGlobalKeys() {
    keyPropsViewer = GlobalKey(debugLabel: "keyPropsViewer");
    keyStyleSelectorViewer = GlobalKey(debugLabel: "keyStyleSelectorViewer");
    keyStyleViewer = GlobalKey(debugLabel: "keyStyleViewer");
    keyBehaviorViewer = GlobalKey(debugLabel: "keyBehaviorViewer");

    keyPagesViewer = GlobalKey(debugLabel: 'keyPagesViewer');

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

    removeAllCache(rootCtx);
  }

  void removeAllCache(CwWidgetCtx? aCtx) {
    aCtx?.clearWidgetCache(clearInnerWidget: true);
    List<CwWidgetCtx> object =
        aCtx?.childrenCtx?.entries.map((e) => e.value).toList() ?? [];
    for (CwWidgetCtx element in object) {
      removeAllCache(element);
    }
  }

  DesignMode mode = DesignMode.designer;

  Map<String, BuilderWidget> builderWidget = {};
  Map<String, BuilderWidgetConfig> builderConfig = {};
  Map<String, OnDrapWidgetConfig> builderDragConfig = {};

  Map<String, dynamic> appData = {cwRepos: <String, dynamic>{}};
  Map<String, CwRepository> mapRepositories = {};

  CwWidgetCtx? rootCtx;
  CwWidgetCtx? lastSelectedCtx;

  Map<String, Size> cacheSizeSlots = {};
  Map<String, Widget> cachePagesDesign = {};
  Map<String, Widget> cachePagesViewer = {};

  Function? onStarted;

  TabController? controllerTabProps;
  GoRouter? router;
  late WidgetFactoryProperty cwFactoryProps;

  WidgetFactory() {
    CwApp.initFactory(this);
    CwPage.initFactory(this);
    CwAppBar.initFactory(this);
    CwInput.initFactory(this);
    CwContainer.initFactory(this);
    CwBar.initFactory(this);
    CwAction.initFactory(this);
    CwList.initFactory(this);
    CwDivider.initFactory(this);
    CwTable.initFactory(this);
    CwRow.initFactory(this);
    CwAdvancedPager.initFactory(this);
    CwIndicator.initFactory(this);

    cwFactoryProps = WidgetFactoryProperty(cwFactory: this);
  }

  set isStarted(bool isStarted) {}

  void register({
    required String id,
    BuilderWidget? build,
    required BuilderWidgetConfig config,
    OnDrapWidgetConfig? populateOnDrag,
  }) {
    if (build != null) {
      builderWidget[id] = build;
    }
    builderConfig[id] = config;
    if (populateOnDrag != null) {
      builderDragConfig[id] = populateOnDrag;
    }
  }

  Map<String, dynamic> getEmptyApp() {
    mapRepositories.clear();
    appData = {
      'version': '1.0.0',
      cwApp: <String, dynamic>{},
      cwRepos: <String, dynamic>{},
    };

    Map<String, dynamic> emptyPage = {
      cwSlotId: '/',
      cwImplement: 'page',
      cwRouteId: '/',
      cwRoutePath: '/',
      cwRouteName: 'Home',
    };

    appData[cwApp] = {
      cwSlotId: '',
      cwImplement: 'app',
      cwSlots: <String, dynamic>{'/': emptyPage},
      cwProps: <String, dynamic>{'color': 'FF448AFF'},
    };

    initEmptyPageContent(emptyPage);
    return emptyPage;
  }

  void initEmptyPageContent(Map<String, dynamic> emptyPage) {
    emptyPage[cwProps] = <String, dynamic>{
      'fullheight': true,
      'drawer': true,
      'fixDrawer': true,
    };

    addInSlot(emptyPage, 'body', {
      cwImplement: 'container',
      cwProps: <String, dynamic>{},
    });
    var appbar = addInSlot(emptyPage, 'appbar', <String, dynamic>{
      cwImplement: 'appbar',
      cwProps: <String, dynamic>{},
    });
    addInSlot(appbar, 'title', {
      cwImplement: 'input',
      cwProps: <String, dynamic>{'label': 'Page Title'},
    });
  }

  bool isModeDesigner() {
    return mode == DesignMode.designer;
  }

  bool isModeViewer() {
    return mode == DesignMode.viewer;
  }

  CwSlot getSlot(CwWidgetCtx parent, String id, {Map? data}) {
    var ctx = parent.getSlotCtx(id, data: data);
    var cwSlotConfig = CwSlotConfig(ctx: ctx);
    return CwSlot(config: cwSlotConfig);
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
    child[cwSlotId] = id;
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
      cwImplement: cmpType,
      if (props != null) cwProps: props,
      if (slotProps != null) cwPropsSlot: slotProps,
    };
    child[cwSlotId] = id;
    slots[id] = child;
    return child;
  }

  CwWidget getWidget(CwWidgetCtx ctx) {
    var w = builderWidget[ctx.getData()![cwImplement]]!(ctx);
    return w;
  }

  CwSlot? rootSlot;

  Widget getRootSlot(String routePath) {
    var d = appData[cwApp];

    if (d == null) {
      return Container();
    }
    if (withWidgetCache &&
        rootSlot != null &&
        rootCtx != null &&
        rootCtx!.getData()![cwRoutePath] == routePath) {
      return rootSlot!;
    }

    rootCtx =
        CwWidgetCtx(slotId: d[cwSlotId], aFactory: this, parentCtx: null)
          ..selectorCtxIfDesign?.inSlotName = 'application'
          ..dataWidget = d;

    rootSlot = CwSlot(
      config: CwSlotConfig(ctx: rootCtx!)..withDragAndDrop = false,
    );
    return rootSlot!;
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
