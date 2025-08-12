import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart' show GoRouterState;
import 'package:jsonschema/feature/api/pan_api_env.dart';
import 'package:jsonschema/pages/router_generic_page.dart';

class EnvPage extends GenericPageStateless {
  const EnvPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: EdgeInsetsGeometry.all(10), child: PanApiEnv());
  }

  @override
  NavigationInfo initNavigation(
    GoRouterState routerState,
    BuildContext context,
    PageInit? pageInit
  ) {
    return NavigationInfo();
  }
}
