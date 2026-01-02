import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/core/api/call_ds_manager.dart';
import 'package:jsonschema/feature/transform/pan_response_viewer.dart';
import 'package:jsonschema/core/designer/component/pages_viewer.dart';
import 'package:jsonschema/pages/router_generic_page.dart';

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
    return _loadDataSrc(domain, id);
  }

  Future<Widget> _loadDataSrc(String domain, String id) async {
    CallerDatasource caller = CallerDatasource();

    var helper = await caller.loadConfig(domain, id, paramId);

    if (helper != null) {
      return PagesDesignerViewer(
        cWDesignerMode: false,
        aFactory: null,
        child: PanResponseViewer(
          requestHelper: helper,
          callerDatasource: caller,
        ),
      );
    } else {
      return Text('api ${caller.domainDs}.${caller.apiShortName} not found');
    }
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
  
