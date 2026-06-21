import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/feature/home/background_screen.dart';
import 'package:jsonschema/pages/model_design/design_model_page.dart';

import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/pages/router_layout.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/show_case/showcase.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';
import 'package:jsonschema/widget/widget_menu_btn.dart';

class HomePage extends GenericPageStateless {
  HomePage({super.key});
  final ShowCaseInfo showCaseInfo = ShowCaseInfo();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const BackgroundScreen(num: 0),
        SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: ValueListenableBuilder(
            valueListenable: zoom,
            builder: (context, value, child) {
              return Column(
                spacing: 20,
                children: [
                  // getExpansible("Get started", getMenuStarted(context)),
                  // SizedBox(height: 30),
                  getExpansible(
                    "For architect & tech designer",
                    getMenuArchitect(context),
                  ),
                  getExpansible("For developer", getMenuDevelopper(context)),
                  getExpansible(
                    "For content manager & app designer",
                    getMenuCM(context),
                  ),
                  getExpansible("For UX/UI", getMenuUXUI(context)),
                  getExpansible("For quality assurance", getMenuQA(context)),
                  getExpansible("For administrator", getMenuAdmin(context)),
                ],
              );
            },
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
      headerBuilder: (_, animation) => GestureDetector(
        onTap: () {
          controller.isExpanded ? controller.collapse() : controller.expand();
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
      bodyBuilder: (_, animation) =>
          FadeTransition(opacity: animation, child: child),
      expansibleBuilder: (_, header, body, _) => Column(
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
            key: showCaseInfo.keys['glossary'] = GlobalKey(),
            label: 'Company Glossary',
            icon: Icons.language,
            route: Pages.glossary,
          ),
          WidgetMenuBtn(
            key: showCaseInfo.keys['model'] = GlobalKey(),
            label: 'Design Model',
            icon: Icons.data_object,
            route: Pages.models,
          ),
          WidgetMenuBtn(
            key: showCaseInfo.keys['api'] = GlobalKey(),
            label: 'Design API',
            icon: Icons.api,
            route: Pages.api,
          ),
          WidgetMenuBtn(
            key: showCaseInfo.keys['message'] = GlobalKey(),
            label: 'Design Message',
            icon: Icons.message_outlined,
            route: Pages.asyncApi,
          ),
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
            label: 'Browse API documentation',
            icon: Icons.insert_drive_file_outlined,
            route: Pages.apiBrowserTag,
          ),
          WidgetMenuBtn(
            label: 'Your favorite API',
            icon: Icons.call_end_outlined,
            // route: Pages.apiByTree,
          ),
          WidgetMenuBtn(
            label: 'Mock API',
            icon: Icons.av_timer,
            route: Pages.mock,
          ),
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
            label: 'Data source',
            icon: Icons.dataset_linked,
            route: Pages.dataSource,
          ),
          WidgetMenuBtn(
            label: 'Create content',
            icon: Icons.content_paste_rounded,
            route: Pages.content,
          ),
          WidgetMenuBtn(
            label: 'Browse content',
            icon: Icons.content_paste_search,
          ),
          WidgetMenuBtn(
            label: 'Map content',
            icon: Icons.map,
            route: Pages.mapData,
          ),
        ],
      ),
    );
  }

  Widget getMenuUXUI(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Wrap(
        spacing: 5, // espace horizontal entre les blocs
        runSpacing: 5, // espace vertical entre les lignes
        alignment: WrapAlignment.start,
        children: [
          WidgetMenuBtn(label: 'Design system', icon: Icons.color_lens),
          WidgetMenuBtn(
            label: 'Design pages',
            icon: Icons.design_services,
            route: Pages.listApps,
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
          WidgetMenuBtn(
            label: 'Manage user',
            icon: Icons.person,
            route: Pages.user,
          ),
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
          WidgetMenuBtn(label: 'Log', icon: Icons.article, route: Pages.log),
        ],
      ),
    );
  }

  @override
  NavigationInfo initNavigation(
    GoRouterState routerState,
    BuildContext context,
    GlobalKey keyPage,
    PageInit? pageInit,
  ) {
    void showCoach(BuildContext aContext) async {
      var keys = showCaseInfo.keys;
      await ShowcaseCoach.show(
        config: ShowcaseCoachConfig(
          primaryColor: Colors.blue,
          tooltipPosition: ShowcaseTooltipPosition.right,
        ),
        aContext,
        steps: [
          CoachStep(
            targetKey: keys['glossary']!,
            title: 'glossary',
            description: [
              "Glossaire des termes utilisés dans l'entreprise",
              "Permet de définir les mots autorisés pour les modèles, les API et les messages",
            ],
          ),
          CoachStep(
            targetKey: keys['model']!,
            title: 'New modeling',
            description: [
              "Ajout d'un nouveau modèle",
              "différents modèles possibles",
            ],
          ),
          CoachStep(
            targetKey: keys["api"]!,
            title: 'Modeling new API',
            description: [
              "Ajout d'une nouvelle API",
              "basées sur les modèles définis précédemment",
            ],
          ),
          CoachStep(
            targetKey: keys['message']!,
            title: 'Modeling new message',
            description: [
              'ajout d\'un nouveau message',
              "basées sur les modèles définis précédemment",
            ],
          ),
        ],
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      CWInheritedPage page = keyPage.currentContext!
          .getInheritedWidgetOfExactType<CWInheritedPage>()!;

      page.showCase = showCoach;

      if (mustShowCoach) {
        mustShowCoach = false;
      }
    });

    return NavigationInfo()
      ..navLeft = [
        BreadNode(
          icon: const Icon(Icons.domain),
          settings: const RouteSettings(name: 'Organization'),
          path: Pages.organization.urlpath,
          type: BreadNodeType.widget,
        ),
        BreadNode(
          icon: const Icon(Icons.account_circle_outlined),
          settings: const RouteSettings(name: 'Profil'),
          path: Pages.profile.urlpath,
          type: BreadNodeType.widget,
        ),
      ]
      ..actions = [
        IconButton(
          icon: const Icon(Icons.help_outline),
          tooltip: 'Start guide',
          onPressed: () {
            CWInheritedPage page = keyPage.currentContext!
                .getInheritedWidgetOfExactType<CWInheritedPage>()!;

            //showCoach((page.key as GlobalKey).currentContext!);
            page.doShowCase();
          },
        ),
      ];
  }
}
