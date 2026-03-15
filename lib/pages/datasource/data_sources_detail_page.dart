import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:highlight/languages/yaml.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/widget/widget_tab.dart';

// ignore: must_be_immutable
class DataSrcDetailPage extends GenericPageStateless {
  DataSrcDetailPage({super.key});
  String queryId = '';
  String? paramId = '';
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Text("loading $queryId");
    }

    return FutureBuilder<Widget>(
      future: loadDS('all', queryId),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          isLoading = false;
          return snapshot.data!;
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          return Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  Future<Widget> loadDS(String domain, String id) async {
    isLoading = true;
    return _loadDataSrc(domain, id);
  }

  Future<Widget> _loadDataSrc(String domain, String id) async {
    // var apps = await loadDataSource(domain, false);
    // var b = BrowseSingle();
    // b.browse(apps, false);
    // late AttributInfo app;

    // CallerDatasource caller = CallerDatasource();
    // var dsModel = await caller.getDataSourceModel(domain);
    // var app = dsModel.getNodeByMasterIdPath(id);

    return WidgetTab(
      listTab: [
        Tab(child: Text('Global')),
        Tab(child: Text('Derived content')),
      ],
      listTabCont: [
        _getCode(
          currentCompany.currentDataSource!.selectedAttr!,
          currentCompany.currentDataSource!,
        ),
        Container(),
      ],
      heightTab: 30,
    );
  }

  Widget _getCode(NodeAttribut attr, ModelSchema schema) {
    var accessor = ModelAccessorAttr(
      node: attr,
      schema: schema,
      propName: 'config',
    );

    return TextEditor(
      config: CodeEditorConfig(
        mode: yaml,
        getText: () {
          var config = accessor.get();
          if (config == null || config == '') {
            config = '''
domain: example
api: getdog
param: none

next : x 
prev : x
filter :  
  - date : x

link : 
  - dematerialized : x
  - enhanced : x
  - channelState : x
  - creditNode : x
 lucrencobtre aérerencontre 
data:
   path: /data 
criteria:
   path: /data    
''';
          }
          return config;
        },
        onChange: (String json, CodeEditorConfig config) {
          accessor.set(json);
        },
        notifError: ValueNotifier(''),
      ),
      header: 'code',
    );
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
