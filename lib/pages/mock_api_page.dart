import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart' show GoRouterState;
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/server.dart';
import 'package:url_launcher/url_launcher.dart';

class MockApiPage extends GenericPageStateless {
  const MockApiPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsGeometry.all(10),
      child: Column(
        children: [
          TextButton(
            onPressed: () {
              startServer();
              Future.delayed(Duration(seconds: 1)).then((value) {
                _launchUrl('http://localhost:1234/all/api');
              });
            },
            child: Text('Start'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url))) {
      throw Exception('Could not launch $url');
    }
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
