import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart' show GoRouterState;
import 'package:jsonschema/feature/domain/pan_domain.dart';
import 'package:jsonschema/pages/router_generic_page.dart';

class DomainPage extends GenericPageStateless {
  const DomainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: EdgeInsetsGeometry.all(10), child: PanDomain());
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
