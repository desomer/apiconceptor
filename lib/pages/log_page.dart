import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/pages/router_generic_page.dart';


class LogPage extends GenericPageStateless {
  const LogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return  DebugScreen();
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
