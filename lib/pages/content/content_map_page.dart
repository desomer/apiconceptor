import 'package:animated_tree_view/tree_view/tree_node.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/list_editor/widget_list_editor.dart';
import 'package:jsonschema/widget/tree_editor/tree_view.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/core/json_browser.dart';

class ContentMapPage extends GenericPageStateless {
  ContentMapPage({super.key});

  final appsChanged = ValueNotifier(0);

  @override
  Widget build(BuildContext context) {
    return WidgetListEditor(
      withSpacer: false,
      model: null,
      getModel: () {
        return loadDataMap("all", false);
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

class InfoManagerDataMap extends InfoManager with WidgetHelper {
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
          currentCompany.currentDataMap = schema;
          schema.selectedAttr = attr;
          currentCompany.currentDataMapSel = attr;
          RouteManager.goto(Pages.mapDataDetail.id(attr.info.masterID!), context);
        },
        child: Text('Configure data map'),
      ),
    );
    // row.add(
    //   ElevatedButton(
    //     onPressed: () {
    //       cacheLinkPage.clear();
    //       cachePage.clear();
    //       sessionStorage.clear;
    //       clearRouteCache(Pages.appPage);
    //       RouteManager.goto(Pages.appPage.id(attr.info.masterID!), context);
    //     },
    //     child: Text('View data'),
    //   ),
    // );
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
  Function? getValidateKey() {
    return null;
  }

  @override
  Widget getAttributHeaderOLD(TreeNode<NodeAttribut> node) {
    throw UnimplementedError();
  }

  @override
  Widget getRowHeader(TreeNodeData<NodeAttribut> node, BuildContext context) {
    throw UnimplementedError();
  }
}
