import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart' show GoRouterState;
import 'package:jsonschema/feature/home/background_screen.dart';
import 'package:jsonschema/feature/model/pan_model_editor.dart';
import 'package:jsonschema/pages/model_design/design_model_page.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/pages/router_layout.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/show_case/showcase.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';

bool mustShowCoach = true;

// ignore: must_be_immutable
class DesignModelDetailPage extends GenericPageStateless {
  DesignModelDetailPage({super.key});
  String query = '';
  final ShowCaseInfo showCaseInfo = ShowCaseInfo();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const BackgroundScreen(num: 1),
        PanModelEditorMain(idModel: query, showCaseInfo: showCaseInfo),
      ],
    );
  }

  @override
  NavigationInfo initNavigation(
    GoRouterState routerState,
    BuildContext context,
    GlobalKey keyPage,
    PageInit? pageInit,
  ) {
    query =
        routerState.uri.queryParameters['id'] ??
        currentCompany.currentModel!.id;
    var attr = currentCompany.listModel!.getNodeByMasterIdPath(query);
    var name = attr?.info.name;
    var version = attr?.info.properties?['#version'] ?? '0.0.1';
    if (currentCompany.currentModel?.id == query) {
      version = currentCompany.currentModel!.getVersionText();
    }

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
          // CoachStep(
          //   targetKey: keys['button']!,
          //   title: 'Create new modeling',
          //   description: [
          //     "Ajout d'un nouveau modèle",
          //     "différents modèles possibles",
          //   ],
          // ),
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
          settings: const RouteSettings(name: 'Design model'),
          type: BreadNodeType.widget,
          path: Pages.modelDetail.urlpath,
        ),

        BreadNode(
          icon: const Icon(Icons.verified),
          settings: const RouteSettings(name: 'Examples'),
          type: BreadNodeType.widget,
          path: Pages.modelJsonSchema.urlpath,
        ),

        BreadNode(
          icon: const Icon(Icons.devices),
          settings: const RouteSettings(name: 'UI view'),
          type: BreadNodeType.widget,
          path: Pages.modelUI.urlpath,
        ),

        BreadNode(
          icon: const Icon(Icons.bubble_chart),
          settings: const RouteSettings(name: 'Graph view'),
          type: BreadNodeType.widget,
        ),

        BreadNode(
          icon: const Icon(Icons.airplane_ticket),
          settings: const RouteSettings(name: 'Doc.'),
          type: BreadNodeType.widget,
          path: Pages.modelScrum.urlpath,
        ),

        BreadNode(
          // icon IA
          icon: const Icon(Icons.smart_toy),
          settings: const RouteSettings(name: 'Prompt AI'),
          type: BreadNodeType.widget,
          path: Pages.modelPromptAI.urlpath,
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
          path: Pages.models.urlpath,
        ),
        BreadNode(
          settings: RouteSettings(name: name),
          type: BreadNodeType.widget,
        ),
        BreadNode(
          settings: RouteSettings(name: version),
          type: BreadNodeType.widget,
        ),
        BreadNode(
          settings: RouteSettings(name: 'link'),
          type: BreadNodeType.link,
          path:
              '${Pages.modelDetail.urlpath}?id=$query&ns=${currentCompany.currentNameSpace}',
        ),
      ]
      ..actions = getDefaultActionModel(
        keyPage.currentContext ?? context,
        showCaseInfo,
      );
  }
}
