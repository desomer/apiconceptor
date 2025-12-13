import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/core/api/call_manager.dart';
import 'package:jsonschema/core/api/sessionStorage.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/util.dart';
import 'package:jsonschema/feature/api/api_widget_request_helper.dart';
import 'package:jsonschema/feature/api/pan_api_example.dart';
import 'package:jsonschema/feature/transform/pan_response_viewer.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/core/designer/component/pages_viewer.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';
import 'package:yaml/yaml.dart';

// ignore: must_be_immutable
class AppsPage extends GenericPageStateless {
  AppsPage({super.key});
  String queryId = '';
  String? paramId = '';

  bool isLoading = false;
  Widget? cache;
  String? url;

  @override
  void setUrlPath(String path) {
    url = path;
  }

  @override
  String? getUrlPath() {
    return url;
  }

  @override
  Widget build(BuildContext context) {
    if (cache != null) return cache!;
    if (isLoading) {
      return Text("loading $queryId");
    }

    return FutureBuilder<Widget>(
      future: loadAppConfig('all', queryId),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          isLoading = false;
          cache = snapshot.data;
          return cache ?? Text('error');
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          return Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  Future<Widget> loadAppConfig(String domain, String id) async {
    isLoading = true;
    var apps = await loadPage(domain, false);
    var b = BrowseSingle();
    b.browse(apps, false);

    var app = apps.nodeByMasterId[id];
    print('load app $id name = ${app!.info.name}');

    var configText = app.info.properties!['config'];
    Map config = {};
    try {
      config = loadYaml(configText, recover: true);
    } catch (e) {
      print(e);
    }

    return _loadDataSrc(config);
  }

  Future<Widget> _loadDataSrc(Map config) async {
    WidgetRequestHelper? helper;

    var domain = getValueFromPath(config, 'domain');
    var shortName = getValueFromPath(config, 'api');
    var param = getValueFromPath(config, 'param');

    var pagination = getValueFromPath(config, 'pagination');
    List? links = getValueFromPath(config, 'links');

    var configApp = ConfigApp()..name = shortName;

    if (pagination != null) {
      configApp.criteria.paginationVariable = pagination['variable'];
      configApp.criteria.min = pagination['min'] ?? 0;
    }

    for (var link in links ?? []) {
      configApp.data.links.add(
        ConfigLink(
          onPath: link['link']['on'],
          title: link['link']['title'],
          toDatasrc: link['link']['toDatasrc'],
        ),
      );
    }

    var v = currentCompany.listDomain;
    var r = v.allAttributInfo.values.firstWhereOrNull((element) {
      return element.name.toLowerCase() == domain;
    });
    if (r != null) {
      var allApi = await loadAllAPI(namespace: r.masterID);
      var api = allApi.allAttributInfo.values.firstWhereOrNull((element) {
        return element.properties?['short name']?.toString().toLowerCase() ==
            shortName;
      });

      if (api != null) {
        String httpOpe = api.name.toLowerCase();
        var apiCallInfo = APICallManager(
          namespace: r.masterID!,
          attrApi: api,
          httpOperation: httpOpe,
        );
        if (paramId != null) {
          // affecte la session du parent
          apiCallInfo.parentData = sessionStorage.get(paramId);
        }
        var apiNode = allApi.nodeByMasterId[api.masterID!]!;
        String url = apiCallInfo.getURLfromNode(apiNode);
        var def = await loadAPI(id: api.masterID!, namespace: r.masterID);
        print("api $url ${def.id} ");

        if (param != null) {
          var paramModel = ModelSchema(
            category: Category.exampleApi,
            headerName: 'example',
            id: 'example/temp/${apiNode.info.masterID!}',
            infoManager: InfoManagerApiExample(),
            ref: null,
          )..namespace = r.masterID;
          await paramModel.loadYamlAndProperties(
            cache: false,
            withProperties: true,
          );

          var a = BrowseSingle();
          a.browse(paramModel, false);

          var paramAttr = paramModel.mapInfoByName[param]?.firstOrNull;
          configApp.paramToLoad = paramAttr;
        }

        var v = getValueFromPath(config, '/data/path');
        if (v != null) {
          configApp.data.dataDisplayPath = v.toString().split(';');
        }
        v = getValueFromPath(config, '/criteria/path');
        if (v != null) {
          configApp.criteria.dataDisplayPath = v.toString().split(';');
        }

        helper = WidgetRequestHelper(
          apiNode: apiNode,
          apiCallInfo: apiCallInfo,
        );
      }
    }

    if (helper != null) {
      return PagesDesignerViewer(
        cWDesignerMode: false,
        child: PanResponseViewer(requestHelper: helper, configApp: configApp),
      );
    }
    return Text('api $domain.$shortName not found');
  }

  @override
  NavigationInfo initNavigation(
    GoRouterState routerState,
    BuildContext context,
    PageInit? pageInit,
  ) {
    queryId = routerState.uri.queryParameters['id']!;
    paramId = routerState.uri.queryParameters['param'];
    return NavigationInfo();
  }
}


  //  return NavigationInfo()..breadcrumbs = goTo.getBreadcrumbApi(query);
  
