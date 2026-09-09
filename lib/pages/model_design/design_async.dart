import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart' show GoRouterState;
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/core/yaml_browser.dart';
import 'package:jsonschema/feature/async_api/pan_async_selector.dart';
import 'package:jsonschema/feature/home/background_screen.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/pages/router_layout.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';
import 'package:jsonschema/widget/widget_glowing_halo.dart';

class DesignAsyncPage extends GenericPageStateless {
  const DesignAsyncPage({super.key, this.state});
  final GoRouterState? state;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const BackgroundScreen(num: 1),
        Container(
          color: Colors.black87,
          child: Column(
            children: [
              getAction(),
              Expanded(
                child: PanAsyncSelector(
                  key: ValueKey(state?.uri.toString() ?? ''),
                  getSchemaFct: () async {
                    await Future.delayed(Duration(milliseconds: gotoDelay));
                    await loadAsync(currentCompany.currentNameSpace, false);
                    return currentCompany.listAsync!;
                  },
                  type: TypeAsyncSelector.model,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget getAction() {
    var style = ElevatedButton.styleFrom(
      backgroundColor: Colors.blueGrey.shade800,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5), // button's shape
      ),
      elevation: 5, // button's elevation when it's pressed
    );

    return SizedBox(
      height: 30,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        spacing: 10,
        children: [
          SizedBox(width: 1),
          GlowingHalo(
            child: ElevatedButton.icon(
              icon: Icon(Icons.wifi),
              onPressed: () async {
                await addChannelSend();
              },
              style: style,
              label: Text('New send channel'),
            ),
          ),

          ElevatedButton.icon(
            icon: Icon(Icons.wifi),
            onPressed: () async {
              await addChannelReceive();
            },
            style: style,
            label: Text('New receive Channel'),
          ),

          ElevatedButton.icon(
            icon: Icon(Icons.storage_rounded),
            onPressed: () async {
              await addStorage('new Storage');
            },
            style: style,
            label: Text('New storage'),
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.create_new_folder_outlined),
            onPressed: () async {
              await addStorage('new Ftp');
            },
            style: style,
            label: Text('New Ftp'),
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.schedule),
            onPressed: () async {
              await addScheduler('new Scheduler');
            },
            style: style,
            label: Text('New scheduler'),
          ),
        ],
      ),
    );
  }

  Future<void> addChannelReceive() async {
    var listAsync = currentCompany.listAsync;
    String yaml = listAsync!.modelYaml;
    YamlDoc docYaml = YamlDoc();
    docYaml.load(yaml);
    docYaml.doAnalyse();

    String? subdomain = 'new Receive Channel';

    YamlLine? domain;
    for (var element in docYaml.listRoot) {
      if (element.name?.toLowerCase() == subdomain.toLowerCase()) {
        domain = element;
        break;
      }
    }

    domain ??= docYaml.addAtEnd(subdomain, '');
    docYaml.addChild(domain, 'new-topic', 'channel');
    docYaml.addChild(domain, 'new-event', 'message');
    docYaml.addChild(domain, 'new-sub', 'receive');
    YamlLine subNode = docYaml.addChild(domain, 'new-sub-dlq', '');
    docYaml.addChild(subNode, 'new-topic-dlq', 'channel');
    docYaml.addChild(subNode, 'new-dlq-sub', 'receive');

    var newYaml = docYaml.getDoc();
    listAsync.modelYaml = newYaml;
    await listAsync.saveYaml(currentYamlTree!.getYamlConfig(), true, 'import');
    await bddStorage.doStoreSync();
  }

  Future<void> addChannelSend() async {
    var listAsync = currentCompany.listAsync;
    String yaml = listAsync!.modelYaml;
    YamlDoc docYaml = YamlDoc();
    docYaml.load(yaml);
    docYaml.doAnalyse();

    String? subdomain = 'new Send Channel';

    YamlLine? domain;
    for (var element in docYaml.listRoot) {
      if (element.name?.toLowerCase() == subdomain.toLowerCase()) {
        domain = element;
        break;
      }
    }

    domain ??= docYaml.addAtEnd(subdomain, '');
    docYaml.addChild(domain, 'new-topic', 'channel');
    docYaml.addChild(domain, 'new-event', 'message');

    var newYaml = docYaml.getDoc();
    listAsync.modelYaml = newYaml;
    await listAsync.saveYaml(currentYamlTree!.getYamlConfig(), true, 'import');
    await bddStorage.doStoreSync();
  }

  Future<void> addStorage(String subdomain) async {
    var listAsync = currentCompany.listAsync;
    String yaml = listAsync!.modelYaml;
    YamlDoc docYaml = YamlDoc();
    docYaml.load(yaml);
    docYaml.doAnalyse();

    YamlLine? domain;
    for (var element in docYaml.listRoot) {
      if (element.name?.toLowerCase() == subdomain.toLowerCase()) {
        domain = element;
        break;
      }
    }

    domain ??= docYaml.addAtEnd(subdomain, '');
    docYaml.addChild(domain, 'new-bucket', 'bucket');
    docYaml.addChild(domain, 'new-file', 'flatfile');
    docYaml.addChild(domain, 'new-topic', 'channel');
    docYaml.addChild(domain, 'new-file-event', 'message');

    var newYaml = docYaml.getDoc();
    listAsync.modelYaml = newYaml;
    await listAsync.saveYaml(currentYamlTree!.getYamlConfig(), true, 'import');
    await bddStorage.doStoreSync();
  }

  Future<void> addScheduler(String subdomain) async {
    var listAsync = currentCompany.listAsync;
    String yaml = listAsync!.modelYaml;
    YamlDoc docYaml = YamlDoc();
    docYaml.load(yaml);
    docYaml.doAnalyse();

    YamlLine? domain;
    for (var element in docYaml.listRoot) {
      if (element.name?.toLowerCase() == subdomain.toLowerCase()) {
        domain = element;
        break;
      }
    }

    domain ??= docYaml.addAtEnd(subdomain, '');
    docYaml.addChild(domain, 'new-scheduler', 'scheduler');

    var newYaml = docYaml.getDoc();
    listAsync.modelYaml = newYaml;
    await listAsync.saveYaml(currentYamlTree!.getYamlConfig(), true, 'import');
    await bddStorage.doStoreSync();
  }


  @override
  NavigationInfo initNavigation(
    GoRouterState routerState,
    BuildContext context,
    GlobalKey keyPage,
    PageInit? pageInit,
  ) {
    String query = routerState.uri.queryParameters['id'] ?? '? ';
    print("query model: $query");
    //var goTo = GoTo();
    // goTo.initApi(query);
    // goTo.getBreadcrumbApi(query);

    return NavigationInfo()
      ..navLeft = [
        BreadNode(
          icon: const Icon(Icons.data_object),
          settings: const RouteSettings(name: 'async events'),
          type: BreadNodeType.widget,
          path: Pages.models.urlpath,
        ),

        // BreadNode(
        //   icon: const Icon(Icons.dataset_rounded),
        //   settings: const RouteSettings(name: 'List ORM'),
        //   type: BreadNodeType.widget,
        // ),

        // BreadNode(
        //   icon: const Icon(Icons.bubble_chart),
        //   settings: const RouteSettings(name: 'Graph view'),
        //   type: BreadNodeType.widget,
        //   path: Pages.modelGraph.urlpath,
        // ),
      ]
      ..breadcrumbs = [
        BreadNode(
          settings: const RouteSettings(name: 'Domain'),
          type: BreadNodeType.domain,
          path: Pages.asyncApi.urlpath,
        ),
        // BreadNode(
        //   settings: const RouteSettings(name: 'List model'),
        //   type: BreadNodeType.widget,
        // ),
      ]
    //..actions = getDefaultActionModel()
    ;
  }
}
