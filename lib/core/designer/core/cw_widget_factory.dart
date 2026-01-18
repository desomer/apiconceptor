import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/core/designer/core/widget_catalog/cw_app.dart';
import 'package:jsonschema/core/designer/editor/view/helper/widget_hover.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_drag_utils.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_event_bus.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_overlay_selector.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_popup_action.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_selectable.dart';
import 'package:jsonschema/core/designer/core/cw_factory_style.dart';
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
import 'package:jsonschema/main.dart';
import 'package:jsonschema/widget/tree_editor/tree_view.dart';

typedef BuilderWidget = CwWidget Function(CwWidgetCtx ctx);
typedef CacheWidget =
    Widget Function(CwWidgetCtx ctx, BoxConstraints? constraints);
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
const String cwType = 'type';
const String cwRouteId = 'uid';
const String cwRoutePath = 'path';
const String cwRouteName = 'name';

LruCache cacheLinkPage = LruCache(5);

class WidgetFactory {
  GlobalKey keyPropsViewer = GlobalKey(debugLabel: "keyPropsViewer");
  GlobalKey keyStyleViewer = GlobalKey(debugLabel: "keyStyleViewer");
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
    keyStyleViewer = GlobalKey(debugLabel: "keyStyleViewer");
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
  Function? onStarted;

  List<Widget> listPropsEditor = [];
  List<Widget> listStyleEditor = [];

  var cwFactoryStyle = CWFactoryStyle();

  TabController? controllerTabProps;
  GoRouter? router;

  WidgetFactory() {
    CwApp.initFactory(this);
    CwPage.initFactory(this);
    CwAppBar.initFactory(this);
    CwInput.initFactory(this);
    CwContainer.initFactory(this);
    CwTabBar.initFactory(this);
    CwAction.initFactory(this);
    CwList.initFactory(this);
    CwDivider.initFactory(this);
    CwTable.initFactory(this);
    CwRow.initFactory(this);
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

  Widget getRootSlot(String routePath) {
    var d = appData[cwApp];

    if (d == null) {
      return Container();
    }

    rootCtx =
        CwWidgetCtx(slotId: d[cwSlotId], aFactory: this, parentCtx: null)
          ..selectorCtxIfDesign?.inSlotName = 'application'
          ..dataWidget = d;

    return CwSlot(config: CwSlotConfig(ctx: rootCtx!)..withDragAndDrop = false);
  }

  void displayProps(CwWidgetCtx ctx) {
    listPropsEditor.clear();

    var config = ctx.getConfig();

    CwWidgetCtx? aCtx = ctx;
    while (aCtx != null) {
      bool isIterable = addPropsLayer(
        aCtx,
        ctx == aCtx ? config : aCtx.getConfig(),
      );
      if (isIterable && listPropsEditor.length > 1) {
        addIterrableBox(aCtx, ctx);
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

    for (CwWidgetProperties prop in config?.style ?? const []) {
      listStyleEditor.add(prop.input!);
    }

    var initAlignment = cwFactoryStyle.initAlignment(ctx);
    addAllStyleWidget(initAlignment, 'Alignment');
    var initPadding = cwFactoryStyle.initPadding(ctx);
    addAllStyleWidget(initPadding, 'Margin');
    var initBorder = cwFactoryStyle.initBorder(ctx);
    addAllStyleWidget(initBorder, 'Border & Elevation');
    var initBackground = cwFactoryStyle.initBackground(ctx);
    addAllStyleWidget(initBackground, 'Background');
    var initMargin = cwFactoryStyle.initMargin(ctx);
    addAllStyleWidget(initMargin, 'Padding');
    var initText = cwFactoryStyle.initText(ctx);
    addAllStyleWidget(initText, 'Text');

    // var initElevation = cwFactoryStyle.initElevation(ctx);
    // addAllStyleWidget(initElevation, 'Elevation');

    if (keyStyleViewer.currentState?.mounted == true) {
      // ignore: invalid_use_of_protected_member
      keyStyleViewer.currentState?.setState(
        () {},
      ); // force refresh props viewer
    }
  }

  void addIterrableBox(CwWidgetCtx aCtx, CwWidgetCtx ctx) {
    var aIterable = listPropsEditor.removeLast();

    if (aCtx.isType('table') && !ctx.isType('row')) {
      if (ctx.slotProps?.type == 'header') {
        aCtx.dataWidget![cwSlots]?['h-row'] ??= {
          cwImplement: 'row',
          cwProps: <String, dynamic>{},
        };
        CwWidgetCtx? rowHeaderCtx = aCtx.getSlotCtx('h-row', virtual: true);
        rowHeaderCtx.selectorCtxIfDesign?.inSlotName = 'header row';
        addPropsLayer(rowHeaderCtx, rowHeaderCtx.getConfig());
      } else {
        aCtx.dataWidget![cwSlots]?['d-row'] ??= {
          cwImplement: 'row',
          cwProps: <String, dynamic>{},
        };
        CwWidgetCtx? rowCtx = aCtx.getSlotCtx('d-row', virtual: true);
        rowCtx.selectorCtxIfDesign?.inSlotName = 'data row';
        addPropsLayer(rowCtx, rowCtx.getConfig());
      }
    }

    var header = Container(
      margin: EdgeInsets.fromLTRB(10, 5, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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

  void addAllStyleWidget(List<CwWidgetProperties> styles, String name) {
    if (styles.isNotEmpty) {
      listStyleEditor.add(getHeaderStyle(name));
      for (CwWidgetProperties prop in styles) {
        listStyleEditor.add(prop.input!);
      }
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

  bool addPropsLayer(CwWidgetCtx aCtx, CwWidgetConfig? config) {
    List<Widget> listPropsWidget = [];
    var name =
        '${aCtx.getData()?[cwImplement] ?? 'Empty'} [${aCtx.selectorCtx.inSlotName}]';

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
      WidgetHoverCmp(
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
        child: Row(
          children: [
            Expanded(
              child: Center(
                child: Text(
                  name,
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                aCtx.aFactory.controllerTabProps?.animateTo(1);
                aCtx.selectOnDesigner();
              },
              icon: Icon(Icons.style, size: 17),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ],
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
