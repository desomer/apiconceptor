import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart' show GoRouterState;
import 'package:jsonschema/feature/home/background_screen.dart';
import 'package:jsonschema/feature/model/pan_model_main.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/pages/router_layout.dart';
import 'package:jsonschema/widget/show_case/showcase.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';

bool mustShowCoach = true;

class DesignListModelPage extends GenericPageStateless {
  DesignListModelPage({super.key, this.state});
  final GoRouterState? state;
  final ShowCaseInfo showCaseInfo = ShowCaseInfo();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const BackgroundScreen(num: 1),
        Container(
          color: Colors.black87,
          child: WidgetModelMain(
            key: ValueKey(state?.uri.toString() ?? ''),
            showCaseInfo: showCaseInfo,
          ),
        ),
      ],
    );
  }

  // Widget build2(BuildContext context) {
  //   return WidgetTab(
  //     key: stateModel.keyTab,
  //     onInitController: (TabController tab) {
  //       stateModel.tabModel = tab;
  //       tab.addListener(() {
  //         if (tab.index == 0) {
  //           stateModel.setTab();
  //         }
  //       });
  //     },
  //     tabDisable: stateModel.tabDisable,
  //     listTab: [
  //       Tab(text: 'Models Browser'),
  //       Tab(text: 'Model Editor'),
  //       Tab(text: 'Json schema'),
  //     ],
  //     listTabCont: [
  //       Column(
  //         children: [
  //           PanModelActionHub(),
  //           Expanded(child: KeepAliveWidget(child: WidgetModelMain())),
  //         ],
  //       ),
  //       KeepAliveWidget(
  //         child: WidgetModelEditor(key: stateModel.keyModelEditor),
  //       ),
  //       WidgetJsonValidator(),
  //     ],
  //     heightTab: 40,
  //   );
  // }

  @override
  NavigationInfo initNavigation(
    GoRouterState routerState,
    BuildContext context,
    GlobalKey keyPage,
    PageInit? pageInit,
  ) {
    String query = routerState.uri.queryParameters['id'] ?? '? ';
    print("query model: $query");

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
            targetKey: keys['domain']!,
            title: 'Domain selection',
            description: ["Sélection du domaine de modélisation"],
          ),
          CoachStep(
            targetKey: keys['button']!,
            title: 'Create new modeling',
            description: [
              "Ajout d'un nouveau modèle",
              "différents modèles possibles",
            ],
          ),
          CoachStep(
            targetKey: keys['yamlCard']!,
            title: 'Yaml simple structure',
            description: [
              'YAML utilisé pour définir la structure du modèle',
              'Juste le nom et le type de chaque attribut',
            ],
            onNext: () {
              showCaseInfo.action['openProperties']!();
            },
          ),
          CoachStep(
            targetKey: keys['structureCard']!,
            title: 'Card with model attributes',
            description: [
              'Détail de chaque attribut du modèle',
              'Possibilité de modifier le type, le libellé, la description, etc.',
            ],
          ),
          CoachStep(
            targetKey: keys['PropCard']!,
            title: 'Card with attribut properties',
            description: [
              'Détail de chaque propriété du modèle',
              'Respecte le standard JSON schema',
            ],
          ),
          CoachStep(
            targetKey: keys['search']!,
            title: 'Search attributes',
            tooltipPosition: ShowcaseTooltipPosition.below,
            description: [
              'Permet de rechercher un attribut par son nom',
              'Filtre par target',
            ],
          ),
          CoachStep(
            targetKey: keys['zoom']!,
            title: 'Open control',
            description: [
              'Permet de contrôler le facteur d\'ouverture du modèle',
              'Affecte l\'affichage de l\'arbre des attributs du modèle',
            ],
          ),
          CoachStep(
            targetKey: keys['replay']!,
            title: 'Replay guide',
            description: [
              'Permet de relancer le guide',
              'Affiche à nouveau les étapes du guide',
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
      ..showCaseInfo = showCaseInfo
      ..navLeft = [
        BreadNode(
          icon: const Icon(Icons.data_object),
          settings: const RouteSettings(name: 'List model'),
          type: BreadNodeType.widget,
          path: Pages.models.urlpath,
        ),

        BreadNode(
          icon: const Icon(Icons.dataset_rounded),
          settings: const RouteSettings(name: 'List ORM'),
          type: BreadNodeType.widget,
        ),

        BreadNode(
          icon: const Icon(Icons.bubble_chart),
          settings: const RouteSettings(name: 'Graph view'),
          type: BreadNodeType.widget,
          path: Pages.modelGraph.urlpath,
        ),
      ]
      ..breadcrumbs = [
        BreadNode(
          settings: const RouteSettings(name: 'Domain'),
          type: BreadNodeType.domain,
          path: Pages.models.urlpath,
        ),
        BreadNode(
          settings: const RouteSettings(name: 'List model'),
          type: BreadNodeType.widget,
        ),
      ]
      ..actions = getDefaultActionModel(
        keyPage.currentContext ?? context,
        showCaseInfo,
      );
  }
}

class ShowCaseInfo {
  final Map<String, GlobalKey> keys = {};
  final Map<String, Function> action = {};

  ShowCaseInfo();
}
