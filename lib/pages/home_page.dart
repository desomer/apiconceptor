import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/feature/home/background_screen.dart';

import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';
import 'package:jsonschema/widget/widget_menu_btn.dart';

class HomePage extends GenericPageStateless {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const BackgroundScreen(num: 0),
        SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            spacing: 40,
            children: [
              getExpansible("Get started", getMenuStarted(context)),
              SizedBox(height: 30),
              getExpansible(
                "For architect and tech designer",
                getMenuArchitect(context),
              ),
              getExpansible("For developer", getMenuDevelopper(context)),
              getExpansible("For content manager", getMenuCM(context)),
              getExpansible("For quality assurance", getMenuQA(context)),
              getExpansible("For administrator", getMenuAdmin(context)),
            ],
          ),
        ),
      ],
    );
  }

  Widget getExpansible(String name, Widget child) {
    final controller = ExpansibleController();
    controller.expand();

    return Expansible(
      controller: controller,
      headerBuilder:
          (_, animation) => GestureDetector(
            onTap: () {
              controller.isExpanded
                  ? controller.collapse()
                  : controller.expand();
            },
            child: Row(
              spacing: 10,
              children: [
                SizedBox(width: 10),
                Text(name, style: TextStyle(fontSize: 20)),
                Icon(Icons.arrow_circle_down_sharp),
                Spacer(),
              ],
            ),
          ),
      bodyBuilder:
          (_, animation) => FadeTransition(opacity: animation, child: child),
      expansibleBuilder:
          (_, header, body, __) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [header, body],
          ),
    );
  }

  Widget getMenuStarted(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Wrap(
        spacing: 5, // espace horizontal entre les blocs
        runSpacing: 5, // espace vertical entre les lignes
        alignment: WrapAlignment.start,
        children: [
          WidgetMenuBtn(
            label: 'Create domain',
            icon: Icons.domain_add,
            route: Pages.domain,
          ),
          WidgetMenuBtn(label: 'Import collection', icon: Icons.download),
          WidgetMenuBtn(
            label: 'Request API',
            icon: Icons.call,
            route: Pages.api,
          ),
        ],
      ),
    );
  }

  Widget getMenuArchitect(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Wrap(
        spacing: 5, // espace horizontal entre les blocs
        runSpacing: 5, // espace vertical entre les lignes
        alignment: WrapAlignment.start,
        children: [
          WidgetMenuBtn(
            label: 'Glossary',
            icon: Icons.language,
            route: Pages.glossary,
          ),
          WidgetMenuBtn(
            label: 'Design Model',
            icon: Icons.data_object,
            route: Pages.models,
          ),
          WidgetMenuBtn(label: 'Design API', icon: Icons.api, route: Pages.api),
          WidgetMenuBtn(label: 'Design Message', icon: Icons.message_outlined),
          WidgetMenuBtn(
            label: 'Validation Workflow',
            icon: Icons.wechat_rounded,
          ),
        ],
      ),
    );
  }

  Widget getMenuDevelopper(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Wrap(
        spacing: 5, // espace horizontal entre les blocs
        runSpacing: 5, // espace vertical entre les lignes
        alignment: WrapAlignment.start,
        children: [
          WidgetMenuBtn(
            label: 'Browse documentation',
            icon: Icons.insert_drive_file_outlined,
            route: Pages.apiBrowser,
          ),
          WidgetMenuBtn(
            label: 'Call API',
            icon: Icons.call_end_outlined,
            // route: Pages.apiByTree,
          ),
          WidgetMenuBtn(label: 'Mock API', icon: Icons.av_timer),
          WidgetMenuBtn(label: 'Proxy API', icon: Icons.call_merge_outlined),
          WidgetMenuBtn(label: 'Generate Code', icon: Icons.code),
          WidgetMenuBtn(
            label: 'JSON Tools',
            icon: Icons.travel_explore_outlined,
          ),
          WidgetMenuBtn(
            label: 'Validation Workflow',
            icon: Icons.wechat_rounded,
          ),
        ],
      ),
    );
  }

  Widget getMenuCM(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Wrap(
        spacing: 5, // espace horizontal entre les blocs
        runSpacing: 5, // espace vertical entre les lignes
        alignment: WrapAlignment.start,
        children: [
          WidgetMenuBtn(
            label: 'Create content',
            icon: Icons.content_paste_rounded,
          ),
          WidgetMenuBtn(
            label: 'Browse content',
            icon: Icons.content_paste_search,
          ),
        ],
      ),
    );
  }

  Widget getMenuQA(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Wrap(
        spacing: 5, // espace horizontal entre les blocs
        runSpacing: 5, // espace vertical entre les lignes
        alignment: WrapAlignment.start,
        children: [
          WidgetMenuBtn(
            label: 'Unit test API',
            icon: Icons.bug_report_outlined,
          ),
          WidgetMenuBtn(label: 'Book test API', icon: Icons.menu_book_rounded),
          WidgetMenuBtn(
            label: 'Monkey bug proxy API',
            icon: Icons.account_tree_outlined,
          ),
        ],
      ),
    );
  }

  Widget getMenuAdmin(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Wrap(
        spacing: 5, // espace horizontal entre les blocs
        runSpacing: 5, // espace vertical entre les lignes
        alignment: WrapAlignment.start,
        children: [
          WidgetMenuBtn(label: 'Manage user', icon: Icons.person),
          WidgetMenuBtn(
            label: 'Manage domain',
            icon: Icons.domain,
            route: Pages.domain,
          ),
          WidgetMenuBtn(label: 'Naming rules', icon: Icons.settings),
          WidgetMenuBtn(
            label: 'Environnements',
            icon: Icons.settings,
            route: Pages.env,
          ),
          WidgetMenuBtn(label: 'Vault', icon: Icons.lock_open_outlined),
          WidgetMenuBtn(label: 'Plugins', icon: Icons.publish_outlined),
        ],
      ),
    );
  }

  @override
  NavigationInfo initNavigation(
    GoRouterState routerState,
    BuildContext context,
    PageInit? pageInit,
  ) {
    return NavigationInfo()
      ..navLeft = [
        BreadNode(
          icon: const Icon(Icons.domain),
          settings: const RouteSettings(name: 'Organization'),
          type: BreadNodeType.widget,
        ),
        BreadNode(
          icon: const Icon(Icons.account_circle_outlined),
          settings: const RouteSettings(name: 'Profil'),
          type: BreadNodeType.widget,
        ),
      ];
  }
}
