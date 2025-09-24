import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/feature/content/pan_content_selector.dart';
import 'package:jsonschema/pages/router_generic_page.dart';

class ContentPage extends GenericPageStateless {
  const ContentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PanContentSelector();
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
