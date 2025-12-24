import 'dart:developer' as dev show log;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/repaint_manager.dart';
import 'package:jsonschema/core/api/call_api_manager.dart';
import 'package:jsonschema/core/util.dart';
import 'package:jsonschema/feature/api/pan_api_editor.dart';
import 'package:jsonschema/json_browser/browse_api.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/pages/apps/apps_page.dart';
import 'package:jsonschema/pages/apps/apps_page_designer.dart';
import 'package:jsonschema/pages/apps/apps_page_detail.dart';
import 'package:jsonschema/pages/browse_api/browse_api_page.dart';
import 'package:jsonschema/pages/browse_api/browse_api_ui_page.dart';
import 'package:jsonschema/pages/content_page.dart';
import 'package:jsonschema/pages/apps/data_sources_page.dart';
import 'package:jsonschema/pages/design/design_api_detail_page.dart';
import 'package:jsonschema/pages/design/design_api_detail_ui.dart';
import 'package:jsonschema/pages/design/design_api_page.dart';
import 'package:jsonschema/pages/design/design_model_jsonschema_page.dart';
import 'package:jsonschema/pages/design/design_model_detail_page.dart';
import 'package:jsonschema/pages/design/design_model_detail_scrum_page.dart';
import 'package:jsonschema/pages/design/design_model_graph_page.dart';
import 'package:jsonschema/pages/design/design_model_page.dart';
import 'package:jsonschema/pages/design/design_model_ui_page.dart';
import 'package:jsonschema/pages/domain_page.dart';
import 'package:jsonschema/pages/env_page.dart';
import 'package:jsonschema/pages/glossary_page.dart';
import 'package:jsonschema/pages/log_page.dart';
import 'package:jsonschema/pages/mock_api_page.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/pages/user_page.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget/widget_md_doc.dart';
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
  modelUI('/models/ui'),

  api("/apis"),
  apiBrowser("/apis/browser"),
  apiBrowserUI("/apis/browserUI"),
  apiBrowserTag("/apis/browserByTag"),
  //apiByTree("/apis/doc-by-tree"),
  apiDetail("/apis/detail"),
  apiUI("/apis/ui"),
  env('/env'),
  log('/log'),
  content("/content"),
  contentPages("/content/pages"),
  mock("/apis/mock"),
  user("/user"),
  appPage("/app/page"),
  appPageDetail("/app/page/detail"),
  pageDesigner("/pages/designer");

  const Pages(this.urlpath);
  final String urlpath;

  String id(String id) {
    return '$urlpath?id=$id';
  }

  String param(String id, String param) {
    return '$urlpath?id=$id&$param';
  }

  void goto(BuildContext ctx) {
    RouteManager.goto(urlpath, ctx);
  }
}

final routeObserver = RouteObserver<PageRoute>();

Map<String, RouteManager> cacheRoute = {};
LruCache cachePage = LruCache(5);

GoRoute addRoute(
  GoRoute route,
  Widget Function(BuildContext, GoRouterState) builder,
) {
  cacheRoute[route.path] = RouteManager(builder: builder);
  return route;
}

GoRoute addRouteBy(Pages path, GenericPage page, {PageInit? init}) {
  var route = GoRoute(path: path.urlpath, pageBuilder: getPageAnim);
  cacheRoute[route.path] = RouteManager(
    builder: (context, state) => page as Widget,
  );
  return route;
}

GoRoute addRouteByIndexed(
  Pages path,
  Widget Function(BuildContext ctx, GoRouterState state) builder, {
  PageInit? init,
}) {
  var route = GoRoute(path: path.urlpath, pageBuilder: getPageNoAnim);
  cacheRoute[route.path] = RouteManager(builder: builder);
  return route;
}

String? lastPagePath;
int forceNewPage = 0;

void noCacheOnNextLink(int nb) {
  forceNewPage = nb;
}

void clearRouteCache(Pages page) {
  cacheRoute[page.urlpath]!.cache = null;
}

Widget getPage(BuildContext context, GoRouterState state) {
  // print("getPage ${state.uri}");

  var path = state.uri.path;
  if (lastPagePath == path && forceNewPage > 0) {
    forceNewPage = forceNewPage - 1;
    cacheRoute[path]!.cache = null;
  } else {
    forceNewPage = 0;
  }

  String uri = state.uri.toString();
  lastPagePath = path;
  if (cacheRoute.containsKey(path)) {
    if (cacheRoute[path]!.cache is GenericPageStateless) {
      GenericPageStateless page =
          cacheRoute[path]!.cache as GenericPageStateless;
      var urlPath = page.getUrlPath();
      var pageInCache = cachePage.get(uri);
      if (pageInCache != null) {
        dev.log("load page $uri from LRU");
        return pageInCache;
      }
      if (urlPath != null && urlPath != state.uri.toString()) {
        // vide la cache a la route
        cacheRoute[path]!.cache = null;
      }
    }

    if (cacheRoute[path]!.cache != null) {
      dev.log("load page $uri from route cache");
    } else {
      dev.log("buid page $uri");
    }

    cacheRoute[path]!.cache ??= cacheRoute[path]!.builder(context, state);

    if (cacheRoute[path]!.cache is GenericPageStateless) {
      var page = (cacheRoute[path]!.cache as GenericPageStateless);
      page.setUrlPath(uri);
      var urlPath = page.getUrlPath(); // test si cache
      if (urlPath != null) {
        cachePage.put(urlPath, cacheRoute[path]!.cache!);
      }
    }

    return cacheRoute[path]!.cache!;
  }
  return const HomePage();
}

CustomTransitionPage getPageNoAnim(BuildContext context, GoRouterState state) =>
    NoTransitionPage(child: getPage(context, state));

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
    if (connect && state.fullPath != Pages.home.urlpath &&
        state.fullPath != Pages.domain.urlpath &&
        currentCompany.listDomain.selectedAttr == null) {
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
      builder: (context, state, child2) {
        return ValueListenableBuilder(
          valueListenable: zoom,
          builder: (context, value, child) {
            scale = (zoom.value - 5) / 100.0;
            rowHeight = 30 * scale;

            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale + 0.05),
                supportsShowingSystemContextMenu: true,
              ),
              child: Layout(
                routerState: state,
                navChild: child2, // 🔥 route actuelle
              ),
            );
          },
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
        addRouteBy(Pages.modelJsonSchema, DesignModelJsonSchemaPage()),
        addRouteBy(Pages.modelGraph, const DesignModelGraphPage()),
        addRouteBy(Pages.modelScrum, const DesignModelDetailScrumPage()),
        addRouteBy(Pages.modelUI, DesignModelUIPage()),
        //----------------------------------------------------------------
        addRouteBy(Pages.api, const DesignAPIPage()),
        addRouteBy(Pages.apiDetail, CallAPIPageDetail()),
        addRouteBy(Pages.apiUI, CallAPIPageDetailUI()),
        addRouteBy(Pages.env, const EnvPage()),
        addRoute(
          GoRoute(path: Pages.appPage.urlpath, pageBuilder: getPageNoAnim),
          (context, state) {
            return AppsPage();
          },
        ),
        addRoute(
          GoRoute(
            path: Pages.appPageDetail.urlpath,
            pageBuilder: getPageNoAnim,
          ),
          (context, state) {
            return AppsPageDetail();
          },
        ),

        //----------------------------------------------------------------
        addRouteBy(Pages.user, const UserPage()),

        //----------------------------------------------------------------
        addRouteByIndexed(Pages.apiBrowser, (ctx, state) {
          final namespace =
              state.uri.queryParameters['id'] ??
              currentCompany.currentNameSpace;
          return BrowseAPIPage(namespace: namespace, byTag: false);
        }),

        addRouteByIndexed(Pages.apiBrowserUI, (ctx, state) {
          final namespace =
              state.uri.queryParameters['id'] ??
              currentCompany.currentNameSpace;
          return BrowseAPIUIPage(namespace: namespace, byTag: true);
        }),

        addRouteByIndexed(Pages.apiBrowserTag, (ctx, state) {
          final namespace =
              state.uri.queryParameters['id'] ??
              currentCompany.currentNameSpace;
          return BrowseAPIPage(namespace: namespace, byTag: true);
        }),

        addRouteBy(Pages.mock, const MockApiPage()),

        //----------------------------------------------------------------
        addRouteBy(Pages.content, ContentPage()),
        addRouteBy(Pages.contentPages, ContentAppsPage()),
        addRouteBy(Pages.pageDesigner, AppsPageDesigner()),
        //----------------------------------------------------------------
        addRouteBy(Pages.log, LogPage()),
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

//////////////////////////////////////////////////////////////////////////////////////////////////////
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

  Future<ModelSchema> getModel(String idModel) async {
    var attr = currentCompany.listModel!.nodeByMasterId[idModel]!;
    currentCompany.listModel!.selectedAttr = attr;

    await Future.delayed(Duration(milliseconds: gotoDelay));

    currentCompany.currentModel = ModelSchema(
      category: Category.model,
      infoManager: InfoManagerModel(typeMD: TypeMD.model),
      headerName: attr.info.name,
      id: idModel,
      ref: currentCompany.listModel!,
    );
    currentCompany.currentModelSel = attr;
    //currentCompany.currentModel!.currentAttr = attr;
    if (withBdd) {
      await currentCompany.currentModel!.loadYamlAndProperties(
        cache: false,
        withProperties: true,
      );

      var accessor = ModelAccessorAttr(
        node: currentCompany.listModel!.selectedAttr!,
        schema: currentCompany.listModel!,
        propName: '#version',
      );
      accessor.set(currentCompany.currentModel!.getVersionText());
    }
    return currentCompany.currentModel!;
  }

  Future<ModelSchema> getApiRequestModel(
    APICallManager call,
    String domain,
    String idApi, {
    required bool withDelay,
  }) async {
    if (withDelay) {
      await Future.delayed(Duration(milliseconds: gotoDelay));
    }

    // var attr = currentCompany.listAPI!.nodeByMasterId[idApi]!;
    // var key = attr.info.properties![constMasterID];

    // currentCompany.listModel = await loadSchema(
    //   TypeMD.listmodel,
    //   'model',
    //   'Business models',
    //   TypeModelBreadcrumb.businessmodel,
    //   namespace: currentCompany.listAPI!.namespace,
    // );

    // recupere le models du domain
    currentCompany.listModel = await loadSchema(
      TypeMD.listmodel,
      'model',
      'Business models',
      TypeModelBreadcrumb.businessmodel,
      namespace: domain,
    );

    // recupere la définition de la request
    var currentAPIResquest = ModelSchema(
      category: Category.api,
      infoManager: InfoManagerAPIParam(typeMD: TypeMD.apiparam),
      headerName: "Parameters query, header, cookies, body",
      id: idApi,
      ref: currentCompany.listModel,
    )..namespace = domain;

    await currentAPIResquest.loadYamlAndProperties(
      cache: false,
      withProperties: true,
    );

    currentAPIResquest.onChange = (change) {
      // si changement de param
      call.params.clear();
      repaintManager.doRepaint(ChangeTag.apiparam);
    };

    call.initApiParamIfEmpty(currentAPIResquest);

    BrowseAPI().browse(currentAPIResquest, false);

    currentCompany.currentAPIResquest = currentAPIResquest;
    call.currentAPIRequest = currentAPIResquest;
    return currentAPIResquest;
  }

  Future<ModelSchema> getApiResponseModel(
    APICallManager call,
    String domain,
    String idApi, {
    required bool withDelay,
  }) async {
    if (withDelay) {
      await Future.delayed(Duration(milliseconds: gotoDelay));
    }

    // var attr = currentCompany.listAPI!.nodeByMasterId[idApi]!;
    // var key = attr.info.properties![constMasterID];

    currentCompany.currentAPIResponse = ModelSchema(
      category: Category.api,
      infoManager: InfoManagerAPIParam(typeMD: TypeMD.apiresponse),
      headerName: '200, 404, ...',
      id: 'response/$idApi',
      ref: currentCompany.listModel,
    )..namespace = domain;

    call.currentAPIResponse = currentCompany.currentAPIResponse!;

    await currentCompany.currentAPIResponse!.loadYamlAndProperties(
      cache: false,
      withProperties: true,
    );

    //repaintManager.doRepaint(ChangeTag.apichange);

    return currentCompany.currentAPIResponse!;
  }
}
