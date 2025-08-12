import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart' show GoRouterState;
import 'package:jsonschema/pages/router_generic_page.dart';

class AboutPage extends GenericPageStateless {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('about', style: TextStyle(fontSize: 24)));
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
