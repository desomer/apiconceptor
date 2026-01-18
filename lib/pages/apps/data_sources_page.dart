import 'package:animated_tree_view/tree_view/tree_node.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:highlight/languages/yaml.dart';
import 'package:jsonschema/core/api/sessionStorage.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/pages/apps/data_sources_link_viewer.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/widget/list_editor/widget_list_editor.dart';
import 'package:jsonschema/widget/tree_editor/tree_view.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/core/json_browser.dart';

class ContentAppsPage extends GenericPageStateless {
  ContentAppsPage({super.key});

  final appsChanged = ValueNotifier(0);

  @override
  Widget build(BuildContext context) {
    return WidgetListEditor(
      withSpacer: false,
      model: null,
      getModel: () {
        return loadDataSource("all", false);
      },
      change: appsChanged,
    );
  }

  @override
  NavigationInfo initNavigation(
    GoRouterState routerState,
    BuildContext context,
    PageInit? pageInit,
  ) {
    return NavigationInfo();
  }
}

class InfoManagerPages extends InfoManager with WidgetHelper {
  Future<void> showConfigDialog(
    NodeAttribut attr,
    ModelSchema schema,
    BuildContext ctx,
  ) async {
    return showDialog<void>(
      context: ctx,
      barrierDismissible: true, // user must tap button!
      builder: (BuildContext context) {
        Size size = MediaQuery.of(ctx).size;
        double width = size.width * 0.9;
        double height = size.height * 0.8;

        return AlertDialog(
          content: SizedBox(
            width: width,
            height: height,
            child: _getCode(attr, schema),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
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
  void addRowWidget(
    NodeAttribut attr,
    ModelSchema schema,
    List<Widget> row,
    BuildContext context,
  ) {
    row.add(
      ElevatedButton(
        onPressed: () {
          showConfigDialog(attr, schema, context);
        },
        child: Text('Configure data source'),
      ),
    );
    row.add(
      ElevatedButton(
        onPressed: () {
          cacheLinkPage.clear();
          cachePage.clear();
          sessionStorage.clear;
          clearRouteCache(Pages.appPage);
          context.push(Pages.appPage.id(attr.info.masterID!));
        },
        child: Text('View data'),
      ),
    );
  }

  @override
  String getTypeTitle(NodeAttribut node, String name, dynamic type) {
    String? typeStr;
    typeStr ??= '$type';
    return typeStr;
  }

  @override
  InvalidInfo? isTypeValid(
    NodeAttribut nodeAttribut,
    String name,
    dynamic type,
    String typeTitle,
  ) {
    return null;
  }

  @override
  Widget getRowHeader(TreeNodeData<NodeAttribut> node) {
    // TODO: implement getAttributHeaderOLD
    throw UnimplementedError();
  }

  Widget getWidgetType(NodeAttribut attr, bool isModel, bool isRoot) {
    // TODO: implement getAttributHeaderOLD
    throw UnimplementedError();
  }

  @override
  Widget getAttributHeaderOLD(TreeNode<NodeAttribut> node) {
    // TODO: implement getAttributHeaderOLD
    throw UnimplementedError();
  }
}
