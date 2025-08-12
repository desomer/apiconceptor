import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/repaint_manager.dart';
import 'package:jsonschema/feature/api/pan_api_editor.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/pages/call_api_detail_page.dart';
import 'package:jsonschema/pages/design_api_page.dart';
import 'package:jsonschema/pages/design_model_detail_json_page.dart';
import 'package:jsonschema/pages/design_model_detail_page.dart';
import 'package:jsonschema/pages/design_model_detail_scrum_page.dart';
import 'package:jsonschema/pages/design_model_graph_page.dart';
import 'package:jsonschema/pages/design_model_page.dart';
import 'package:jsonschema/pages/domain_page.dart';
import 'package:jsonschema/pages/env_page.dart';
import 'package:jsonschema/pages/glossary_page.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget/widget_md_doc.dart';
import 'package:jsonschema/widget_state/state_api.dart';
import 'package:yaml/yaml.dart';
import 'router_layout.dart';
import 'home_page.dart';
import 'about_page.dart';

enum Pages {
  home("/"),
  glossary("/glossary"),
  domain("/domain"),

  models('/models'),
  modelDetail("/models/detail"),
  modelJsonSchema('/models/modelJsonSchema'),
  modelGraph('/models/graph'),
  modelScrum('/models/scrum'),

  api("/apis"),
  apiByTree("/apis/doc-by-tree"),
  apiDetail("/apis/detail"),
  env('/env');

  const Pages(this.urlpath);
  final String urlpath;

  String id(String id) {
    return '$urlpath?id=$id';
  }

  void goto(BuildContext ctx) {
    RouteManager.goto(urlpath, ctx);
  }
}

final routeObserver = RouteObserver<PageRoute>();

Map<String, RouteManager> allroute = {};
GoRoute addRoute(
  GoRoute route,
  Widget Function(BuildContext, GoRouterState) builder,
) {
  allroute[route.path] = RouteManager(builder: builder);
  return route;
}

GoRoute addRouteBy(Pages path, GenericPage page, {PageInit? init}) {
  var route = GoRoute(path: path.urlpath, pageBuilder: getPageAnim);
  allroute[route.path] = RouteManager(
    builder: (context, state) => page as Widget,
  );
  return route;
}

//bool isPageInit = false;

String? last;
int forcePage = 0;

Widget getPage(BuildContext context, GoRouterState state) {
  // if (!isPageInit) {
  //   isPageInit = true;
  //   for (var element in allroute.values) {
  //     element.cache ??= element.builder(context, state);
  //   }
  // }
  var path = state.uri.path;
  if (last == path && forcePage > 0) {
    forcePage = forcePage - 1;
    allroute[path]!.cache = null;
  } else {
    forcePage = 0;
  }

  last = path;
  if (allroute.containsKey(path)) {
    allroute[path]!.cache ??= allroute[path]!.builder(context, state);
    return allroute[path]!.cache!;
  }
  return const HomePage();
}

CustomTransitionPage getPageAnim(BuildContext context, GoRouterState state) {
  Widget page = getPage(context, state);
  return buildPageWithSlide(context: context, state: state, child: page);
}

// List<Widget> getAllPages(BuildContext context) {
//   return allroute.values.map((e) => e.cache!).toList();
// }

// int indexOfPage(String path) {
//   return allroute.keys.toList().indexOf(path);
// }

CustomTransitionPage<T> buildPageWithSlide<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final offsetAnimation = Tween<Offset>(
        begin: Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(animation);
      return SlideTransition(position: offsetAnimation, child: child);
    },
  );
}

class RouteManager {
  final Widget Function(BuildContext, GoRouterState) builder;
  Widget? cache;
  RouteManager({required this.builder});

  static int last = 0;
  static void goto(String location, BuildContext ctx) {
    int d = DateTime.now().millisecondsSinceEpoch;
    int v = d - last;
    if (v < 1000) return;
    ctx.push(location);
    last = d;
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'routerkey',
);

class Dialog with WidgetHelper {
  Future<void> doMustDomainFirst() async {
    return messageBuilder(
      navigatorKey.currentContext!,
      Text(
        textAlign: TextAlign.center,
        'Create your domain first',
        style: TextStyle(fontSize: 20),
      ),
    );
  }
}

final GoRouter router = GoRouter(
  observers: [routeObserver],
  redirect: (context, state) async {
    if (state.fullPath != Pages.home.urlpath &&
        state.fullPath != Pages.domain.urlpath &&
        currentCompany.listDomain.currentAttr == null) {
      await Dialog().doMustDomainFirst();
      return Pages.domain.urlpath;
    }

    if (state.fullPath == Pages.home.urlpath) {
      return null; // No redirection logic needed
    }
    return null; // No redirection logic needed
  },

  initialLocation: Pages.home.urlpath,
  routes: [
    ShellRoute(
      navigatorKey: navigatorKey,
      builder: (context, state, child) {
        return Layout(
          routerState: state,
          navChild: child, // 🔥 route actuelle
        );
      },
      routes: [
        addRoute(
          GoRoute(path: '/', pageBuilder: getPageAnim),
          (context, state) => const HomePage(),
        ),
        addRoute(
          GoRoute(path: '/about', pageBuilder: getPageAnim),
          (context, state) => const AboutPage(),
        ),
        //----------------------------------------------------------------
        addRouteBy(Pages.domain, const DomainPage()),

        addRoute(
          GoRoute(path: Pages.glossary.urlpath, pageBuilder: getPageAnim),
          (context, state) => const GlossaryPage(),
        ),
        //----------------------------------------------------------------
        addRouteBy(Pages.models, const DesignModelPage()),
        addRouteBy(Pages.modelDetail, DesignModelDetailPage()),
        addRouteBy(Pages.modelJsonSchema, const DesignModelDetailJsonPage()),
        addRouteBy(Pages.modelGraph, const DesignModelGraphPage()),
        addRouteBy(Pages.modelScrum, const DesignModelDetailScrumPage()),

        //----------------------------------------------------------------
        addRouteBy(Pages.api, const DesignAPIPage()),
        addRouteBy(Pages.apiDetail, CallAPIPageDetail()),
        addRouteBy(Pages.env, const EnvPage()),

        // addRoute(
        //   GoRoute(path: Pages.api.urlpath, pageBuilder: getPageAnim),
        //   (context, state) => DesignAPIPage(),
        // ),

        // addRoute(
        //   GoRoute(path: Pages.apiDetail.urlpath, pageBuilder: getPageAnim),
        //   (context, state) => CallAPIPageDetail(),
        // ),

        // addRoute(
        //   GoRoute(path: Pages.env.urlpath, pageBuilder: getPageAnim),
        //   (context, state) => const EnvPage(),
        // ),
      ],
    ),
  ],
);

int gotoDelay = 100;

class GoTo {
  List<BreadNode> getBreadcrumbApi(String id) {
    var attr = currentCompany.listAPI!.nodeByMasterId[id]!;
    var modelPath = <BreadNode>[];
    NodeAttribut? n = attr.parent;
    while (n != null) {
      if (n.parent != null) {
        modelPath.insert(
          0,
          BreadNode(
            settings: RouteSettings(name: n.info.name),
            type: BreadNodeType.widget,
          ),
        );
      }

      n = n.parent;
    }
    return modelPath;
  }

  Future<ModelSchema> initModel(String idModel) async {
    var attr = currentCompany.listModel!.nodeByMasterId[idModel]!;
    currentCompany.listModel!.currentAttr = attr;

    await Future.delayed(Duration(milliseconds: gotoDelay));

    currentCompany.currentModel = ModelSchema(
      category: Category.model,
      infoManager: InfoManagerModel(typeMD: TypeMD.model),
      headerName: attr.info.name,
      id: idModel,
    );
    currentCompany.currentModelSel = attr;
    //currentCompany.currentModel!.currentAttr = attr;
    if (withBdd) {
      await currentCompany.currentModel!.loadYamlAndProperties(
        cache: false,
        withProperties: true,
      );
    }
    return currentCompany.currentModel!;
  }

  Future<ModelSchema> initApiRequest(String idApi) async {
    await Future.delayed(Duration(milliseconds: gotoDelay));

    //currentCompany.listAPI!.currentAttr = null;
    var attr = currentCompany.listAPI!.nodeByMasterId[idApi]!;

    currentCompany.listModel = await loadSchema(
      TypeMD.listmodel,
      'model',
      'Business models',
      TypeModelBreadcrumb.businessmodel,
      namespace: currentCompany.currentNameSpace,
    );

    var key = attr.info.properties![constMasterID];
    currentCompany.currentAPIResquest = ModelSchema(
      category: Category.api,
      infoManager: InfoManagerAPIParam(typeMD: TypeMD.apiparam),
      headerName: "Parameters query, header, cookies, body",
      id: key,
    );

    await currentCompany.currentAPIResquest!.loadYamlAndProperties(
      cache: false,
      withProperties: true,
    );

    currentCompany.currentAPIResquest!.onChange = (change) {
      currentCompany.apiCallInfo?.params.clear();
      repaintManager.doRepaint(ChangeTag.apiparam);
    };

    initApiParam();

    return currentCompany.currentAPIResquest!;
  }

  Future<ModelSchema> initApiResponse(String idApi) async {
    await Future.delayed(Duration(milliseconds: gotoDelay));

    var attr = currentCompany.listAPI!.nodeByMasterId[idApi]!;
    var key = attr.info.properties![constMasterID];

    currentCompany.currentAPIResponse = ModelSchema(
      category: Category.api,
      infoManager: InfoManagerAPIParam(typeMD: TypeMD.apiresponse),
      headerName: '200, 404, ...',
      id: 'response/$key',
    );

    await currentCompany.currentAPIResponse!.loadYamlAndProperties(
      cache: false,
      withProperties: true,
    );

    //repaintManager.doRepaint(ChangeTag.apichange);

    return currentCompany.currentAPIResponse!;
  }

  void initApiParam() {
    if (currentCompany.currentAPIResquest!.modelYaml.isEmpty) {
      StringBuffer urlparam = StringBuffer();
      for (var element in stateApi.urlParam) {
        urlparam.writeln('  $element : string');
      }

      currentCompany.currentAPIResquest!.modelYaml = '''
path:
${urlparam}query:
header:        
cookies:        
body :
''';
      currentCompany.currentAPIResquest!.mapModelYaml = loadYaml(
        currentCompany.currentAPIResquest!.modelYaml,
        recover: true,
      );
    }
  }
}

// class NavigationService {

//   static Future<void> push(String routeName) {
//     return navigatorKey.currentContext!.push(routeName);
//   }

//   static void pop() {
//     navigatorKey.currentContext?.pop();
//   }
// }
