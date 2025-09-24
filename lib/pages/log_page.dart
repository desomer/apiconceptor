import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';

class LogPage extends GenericPageStateless {
  const LogPage({super.key});

  @override
  Widget build(BuildContext context) {
    List<String> log = currentCompany.log;

    return SingleChildScrollView(
      child:
          log.isEmpty
              ? Text("No log")
              : Column(crossAxisAlignment: CrossAxisAlignment.start,
                children:
                    log
                        .map(
                          (e) => Text(e),
                        )
                        .toList(),
              ),
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
