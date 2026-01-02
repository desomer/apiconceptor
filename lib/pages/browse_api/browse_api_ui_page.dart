import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/api/call_api_manager.dart';
import 'package:jsonschema/core/api/widget_request_helper.dart';
import 'package:jsonschema/feature/api/pan_api_selector.dart';
import 'package:jsonschema/feature/api/pan_api_selector_tag.dart';
import 'package:jsonschema/feature/transform/pan_response_viewer.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';
import 'package:jsonschema/widget/widget_disable_overlay.dart';
import 'package:jsonschema/widget/widget_keep_alive.dart';

class BrowseAPIUIPage extends GenericPageStateful {
  const BrowseAPIUIPage({
    required this.namespace,
    required this.byTag,
    super.key,
  });
  final String namespace;
  final bool byTag;

  @override
  State<StatefulWidget> createState() {
    return BrowseAPIPageState();
  }

  @override
  NavigationInfo initNavigation(
    GoRouterState routerState,
    BuildContext context,
    PageInit? pageInit,
  ) {
    return NavigationInfo()
      ..navLeft = [
        BreadNode(
          icon: const Icon(Icons.tag),
          settings: const RouteSettings(name: 'API by tag'),
          type: BreadNodeType.widget,
          path: Pages.apiBrowserTag.urlpath,
        ),

        BreadNode(
          icon: const Icon(Icons.api_outlined),
          settings: const RouteSettings(name: 'API UI'),
          type: BreadNodeType.widget,
          path: Pages.apiBrowserUI.urlpath,
        ),

        BreadNode(
          icon: const Icon(Icons.api_outlined),
          settings: const RouteSettings(name: 'API Tree'),
          type: BreadNodeType.widget,
          path: Pages.apiBrowser.urlpath,
        ),

        BreadNode(
          icon: const Icon(Icons.bubble_chart),
          settings: const RouteSettings(name: 'Graph view'),
          type: BreadNodeType.widget,
        ),
      ]
      ..breadcrumbs = [
        BreadNode(
          settings: const RouteSettings(name: 'List API'),
          type: BreadNodeType.widget,
        ),
        BreadNode(
          settings: const RouteSettings(name: 'Domain'),
          type: BreadNodeType.domain,
          path: byTag ? Pages.apiBrowserTag.urlpath : Pages.apiBrowser.urlpath,
        ),
      ];
  }
}

class BrowseAPIPageState extends GenericPageState<BrowseAPIUIPage> {
  final cController = CarouselController(initialItem: 0);

  final disableSelector = ValueNotifier(false);
  final disableExample = ValueNotifier(false);
  final refreshUI = ValueNotifier(0);

  GlobalKey paramKey = GlobalKey(debugLabel: 'paramKey');

  WidgetRequestHelper? requestHelper;

  var flexWeights = [1, 10, 1];

  APICallManager getAPICall(String namespace, NodeAttribut attr) {
    String httpOpe = attr.info.name.toLowerCase();
    var apiCallInfo = APICallManager(
      namespace: namespace,
      attrApi: attr.info,
      httpOperation: httpOpe,
    );
    return apiCallInfo;
  }

  GlobalKey exampleKey = GlobalKey(debugLabel: "exampleKey");
  String currentIdApi = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    disableSelector.dispose();
    disableExample.dispose();
    refreshUI.dispose();
    cController.dispose();
    super.dispose();
  }

  var currentNamespace = "";

  @override
  Widget build(BuildContext context) {
    if (currentNamespace != widget.namespace) {
      currentIdApi = '';
      requestHelper = null;
      disableSelector.value = false;
      disableExample.value = false;
      refreshUI.value++;

      cController.animateToItem(
        0,
        curve: Curves.easeInOut,
        duration: Duration(milliseconds: 200),
      );
    }

    Widget panAPISelector;
    if (widget.byTag) {
      panAPISelector = PanApiSelectorTag(
        getSchemaFct: () async {
          await loadAllAPIGlobal();
          return currentCompany.listAPI!;
        },
        onSelModel: (idApi) {
          gotoApi(idApi);
        },
      );
    } else {
      panAPISelector = PanAPISelector(
        browseOnly: true,
        onSelModel: (idApi) {
          gotoApi(idApi);
        },
        //   key: keySel,
        getSchemaFct: () async {
          await loadAllAPIGlobal();
          return currentCompany.listAPI!;
        },
      );
    }

    var viewSelector = KeepAliveWidget(
      child: WidgetToggleDisabled(
        toogle: disableSelector,
        child: panAPISelector,
        onTapForEnable: () {
          disableSelector.value = false;
          cController.animateToItem(
            0,
            curve: Curves.easeInOut,
            duration: Duration(milliseconds: 200),
          );
          currentIdApi = "";
          requestHelper = null;
          refreshUI.value++;
        },
      ),
    );

    return CarouselView.weighted(
      consumeMaxWeight: true,
      controller: cController,
      enableSplash: false,
      flexWeights: flexWeights,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadiusGeometry.all(Radius.circular(10)),
      ),
      children: [viewSelector, getViewerUI()],
    );
  }

  Widget getViewerUI() {
    return ValueListenableBuilder(
      valueListenable: refreshUI,
      builder: (context, value, child) {
        if (currentIdApi != '' && requestHelper != null) {
          return PanResponseViewer(
            key: ObjectKey(requestHelper),
            requestHelper: requestHelper!,
            modeLegacy: false,
          );
        }
        return Container();
      },
    );
  }

  void gotoApi(String idApi) {
    disableSelector.value = true;
    cController.animateToItem(
      1,
      curve: Curves.easeInOut,
      duration: Duration(milliseconds: 200),
    );

    var attr = currentCompany.listAPI!.nodeByMasterId[idApi]!;
    currentCompany.listAPI!.selectedAttr = attr;

    requestHelper = null;
    currentIdApi = '';

    Future.delayed(Duration(milliseconds: 10)).then((value) {
      SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
        requestHelper = WidgetRequestHelper(
          apiNode: attr,
          apiCallInfo: getAPICall(
            currentCompany.currentNameSpace,
            currentCompany.listAPI!.selectedAttr!,
          ),
        );
        currentIdApi = idApi;
        refreshUI.value++;
      });
    });
  }
}
