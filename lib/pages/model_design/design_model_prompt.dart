import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart' show GoRouterState;
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/json_browser/browse_model.dart';
import 'package:jsonschema/feature/documentation/documentation_options.dart';
import 'package:jsonschema/feature/model/pan_model_methods_rules.dart';
import 'package:jsonschema/pages/apm/widget_prompt.dart';
import 'package:jsonschema/pages/model_design/prompts/prompt_integration.dart';
import 'package:jsonschema/pages/model_design/prompts/prompt_interface.dart';
import 'package:jsonschema/pages/model_design/prompts/prompt_model.dart';
import 'package:jsonschema/pages/model_design/prompts/prompt_persistence.dart';
import 'package:jsonschema/pages/model_design/prompts/prompt_test.dart';
import 'package:jsonschema/pages/model_design/prompts/prompt_usecase.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';
import 'package:markdown_widget/config/configs.dart';
import 'package:markdown_widget/widget/markdown.dart';

// ignore: must_be_immutable
class DesignModelPromptPage extends GenericPageStateless {
  DesignModelPromptPage({super.key});
  String query = '';

  String getPromptTest(String md, String module) {
    return promptTest
        .replaceAll('{{definition du domaine}}', md)
        .replaceAll('{{module}}', module);
  }

  String getPromptModel(String md, String module) {
    return promptModel
        .replaceAll('{{definition du domaine}}', md)
        .replaceAll('{{module}}', module);
  }

  String getPromptPersistance(String md, String module) {
    return promptPersistence
        .replaceAll('{{definition du domaine}}', md)
        .replaceAll('{{module}}', module);
  }

  String getPromptUseCase(String module, String aggregates) {
    // remplace {{definition du domaine}} par le contenu de md
    return promptUseCase
        .replaceAll('{{module}}', module)
        .replaceAll('{{aggregates}}', aggregates);
  }

  String getPromptInterface(String module, String aggregates) {
    // remplace {{definition du domaine}} par le contenu de md
    return promptInterface
        .replaceAll('{{module}}', module)
        .replaceAll('{{aggregates}}', aggregates);
  }

  String getPromptIntegration(String module) {
    return promptIntegration.replaceAll('{{MODULE}}', module);
  }

  Future<String> initModel() async {
    var result = await loadBehaviour(
      currentCompany.currentModel!.namespace!,
      currentCompany.currentModel!.id,
      true,
    );

    BrowseSingle(config: BrowserConfig()).browse(result, false);

    StringBuffer md = StringBuffer();

    result.modelPropertiesByPath.forEach((key, value) {
      Map<String, dynamic> props = value;
      AttributInfo attr = result.mapInfoByJsonPath[key]!;

      String? invariantsBehaviors = props['invariantsBehaviors'];
      String? stateChangingBehaviors = props['stateChangingBehaviors'];
      String? queryBehavior = props['queryBehaviors'];
      String? policyBehaviors = props['policyBehaviors'];
      String? domainEventBehaviors = props['domainEventBehaviors'];
      String? factoryBehaviors = props['factoryBehaviors'];

      md.writeln('# set of features ${attr.name} at ${attr.type}\n');

      if (invariantsBehaviors != null && invariantsBehaviors.isNotEmpty) {
        md.writeln('## Invariants behaviors\n');
        md.writeln(invariantsBehaviors);
      }
      if (stateChangingBehaviors != null && stateChangingBehaviors.isNotEmpty) {
        md.writeln('## State‑changing behaviors\n');
        md.writeln(stateChangingBehaviors);
      }
      if (queryBehavior != null && queryBehavior.isNotEmpty) {
        md.writeln('## Query behaviors\n');
        md.writeln(queryBehavior);
      }
      if (policyBehaviors != null && policyBehaviors.isNotEmpty) {
        md.writeln('## Policy Services\n');
        md.writeln(policyBehaviors);
      }
      if (domainEventBehaviors != null && domainEventBehaviors.isNotEmpty) {
        md.writeln('## Domain event behaviors\n');
        md.writeln(domainEventBehaviors);
      }
      if (factoryBehaviors != null && factoryBehaviors.isNotEmpty) {
        md.writeln('## Factory behaviors\n');
        md.writeln(factoryBehaviors);
      }
    });

    return md.toString();
  }

  @override
  Widget build(BuildContext context) {
    DocumentationInfo info = DocumentationInfo();
    info.showExampleAvro = false;
    info.showExampleDto = false;
    info.showExampleMongoose = false;

    return FutureBuilder<String>(
      future: initModel(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Text('Erreur : ${snapshot.error}');
        }

        return getPromptSelectedWidget(snapshot.data ?? '', info, context);
      },
    );
  }

  Widget getPromptSelectedWidget(
    String extendedMd,
    DocumentationInfo info,
    BuildContext context,
  ) {
    var mdModel = DocumentationOptions(
      info: info,
      context: context,
    ).getModelDocumentation('\n$extendedMd\n');

    var mdOther = DocumentationOptions(
      info: info,
      context: context,
    ).getModelDocumentation("");

    //return MiroLikeWidget();

    var module =
        currentCompany.listModel!.selectedAttr?.parent?.info.name ?? 'module';

    var aggregate =
        currentCompany.listModel!.selectedAttr?.info.name ?? 'aggregate';

    WidgetPrompt promptWidget = WidgetPrompt(
      listPrompt: [
        PromptItem(
          name: 'domain',
          isSelectable: true,
          markdown: getPromptModel(mdModel, module),
          fileName: 'domain-$module-$aggregate.md',
        ),
        PromptItem(
          name: 'persistence',
          isSelectable: true,
          markdown: getPromptPersistance(mdOther, module),
          fileName: 'persistence-$module-$aggregate.md',
        ),
        PromptItem(
          name: 'domain unit test',
          isSelectable: true,
          markdown: getPromptTest(mdModel, module),
          fileName: 'domain_unit_test-$module-$aggregate.md',
        ),
        PromptItem(
          name: 'use case',
          isSelectable: true,
          markdown: getPromptUseCase(module, aggregate),
          fileName: 'usecase-$module-$aggregate.md',
        ),
        PromptItem(
          name: 'interface',
          isSelectable: true,
          markdown: getPromptInterface(module, aggregate),
          fileName: 'interface-$module-$aggregate.md',
        ),
        PromptItem(
          name: 'check integration',
          isSelectable: true,
          markdown: getPromptIntegration(module),
          fileName: 'check-integration-$module.md',
        ),
      ],
    );

    return promptWidget;
  }

  Widget getPromptWidget(String md, BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.copy),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: md));
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('copied to clipboard')));
          },
          label: Text('Prompt in clipboard'),
        ),
        Expanded(
          child: MarkdownWidget(data: md, config: MarkdownConfig.darkConfig),
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
    query =
        routerState.uri.queryParameters['id'] ??
        currentCompany.currentModel!.id;
    var attr = currentCompany.listModel!.getNodeByMasterIdPath(query);
    var name = attr?.info.name;
    var version = attr?.info.properties?['#version'] ?? '0.0.1';
    if (currentCompany.currentModel?.id == query) {
      version = currentCompany.currentModel!.getVersionText();
    }

    return NavigationInfo()
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
      ];
  }
}
