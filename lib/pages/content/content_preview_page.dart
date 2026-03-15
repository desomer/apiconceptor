import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';

class MapContentPreviewPage extends GenericPageStateless {
  const MapContentPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (currentCompany.currentModel == null) {
      return Center(child: Text('No model selected'));
    }

    return Container();
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
