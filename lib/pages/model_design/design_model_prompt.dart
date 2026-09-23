import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart' show GoRouterState;
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/json_browser/browse_model.dart';
import 'package:jsonschema/feature/documentation/documentation_options.dart';
import 'package:jsonschema/feature/model/pan_model_methods_rules.dart';
import 'package:jsonschema/pages/apm/widget_download_prompt.dart';
import 'package:jsonschema/prompts/prompt_header.dart';
import 'package:jsonschema/prompts/prompt_model.dart';
import 'package:jsonschema/prompts/prompt_persistence.dart';
import 'package:jsonschema/prompts/prompt_test.dart';
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

  String getPromptTest(String md, String module, HeaderSpec kind) {
    return fillHeader(
      promptTestDomain,
      kind,
    ).replaceAll('{{spec}}', md).replaceAll('{{module}}', module);
  }

  String getPromptModel(String md, String module, HeaderSpec kind) {
    return fillHeader(
      promptModel,
      kind,
    ).replaceAll('{{spec}}', md).replaceAll('{{module}}', module);
  }

  String getPromptPersistance(String md, String module, HeaderSpec kind) {
    return fillHeader(
      promptPersistence,
      kind,
    ).replaceAll('{{spec}}', md).replaceAll('{{module}}', module);
  }

  // String getPromptUseCase(String module, String aggregates) {
  //   // remplace {{definition du domaine}} par le contenu de md
  //   return promptUseCase
  //       .replaceAll('{{module}}', module)
  //       .replaceAll('{{aggregates}}', aggregates);
  // }

  // String getPromptInterface(String module, String aggregates) {
  //   // remplace {{definition du domaine}} par le contenu de md
  //   return promptInterface
  //       .replaceAll('{{module}}', module)
  //       .replaceAll('{{aggregates}}', aggregates);
  // }

  // String getPromptIntegration(String module) {
  //   return promptIntegration.replaceAll('{{MODULE}}', module);
  // }

  Future<Map<String, String>> initIAContext() async {
    var result = await loadBehaviour(
      currentCompany.currentModel!.namespace!,
      currentCompany.currentModel!.id,
      true,
    );

    BrowseSingle(config: BrowserConfig()).browse(result, false);

    StringBuffer mdModel = StringBuffer();
    StringBuffer mdPersistance = StringBuffer();

    result.modelPropertiesByPath.forEach((key, value) {
      Map<String, dynamic> props = value;
      AttributInfo attr = result.mapInfoByJsonPath[key]!;

      String? invariantsBehaviors = props['invariantsBehaviors'];
      String? stateChangingBehaviors = props['stateChangingBehaviors'];
      String? queryBehavior = props['queryBehaviors'];
      String? policyBehaviors = props['policyBehaviors'];
      String? domainEventBehaviors = props['domainEventBehaviors'];
      String? factoryBehaviors = props['factoryBehaviors'];
      String? persistenceBehaviors = props['persistencePolicy'];

      mdModel.writeln('# set of features ${attr.name} at ${attr.type}\n');

      if (invariantsBehaviors != null && invariantsBehaviors.isNotEmpty) {
        mdModel.writeln('## Invariants behaviors\n');
        mdModel.writeln(invariantsBehaviors);
      }
      if (stateChangingBehaviors != null && stateChangingBehaviors.isNotEmpty) {
        mdModel.writeln('## State‑changing behaviors\n');
        mdModel.writeln(stateChangingBehaviors);
      }
      if (queryBehavior != null && queryBehavior.isNotEmpty) {
        mdModel.writeln('## Query behaviors\n');
        mdModel.writeln(queryBehavior);
      }
      if (policyBehaviors != null && policyBehaviors.isNotEmpty) {
        mdModel.writeln('## Policy Services\n');
        mdModel.writeln(policyBehaviors);
      }
      if (domainEventBehaviors != null && domainEventBehaviors.isNotEmpty) {
        mdModel.writeln('## Domain event behaviors\n');
        mdModel.writeln(domainEventBehaviors);
      }
      if (factoryBehaviors != null && factoryBehaviors.isNotEmpty) {
        mdModel.writeln('## Factory behaviors\n');
        mdModel.writeln(factoryBehaviors);
      }
      if (persistenceBehaviors != null && persistenceBehaviors.isNotEmpty) {
        mdModel.writeln('## Persistence behaviors\n');
        mdModel.writeln(persistenceBehaviors);
        mdPersistance.writeln('## Persistence Policy\n');
        mdPersistance.writeln(persistenceBehaviors);
      }
    });

    return {
      'mdModel': mdModel.toString(),
      'mdPersistance': mdPersistance.toString(),
    };
  }

  @override
  Widget build(BuildContext context) {
    DocumentationConfig info = DocumentationConfig();
    info.showExampleAvro = false;
    info.showExampleDto = false;
    info.showExampleMongoose = false;

    return FutureBuilder<Map<String, String>>(
      future: initIAContext(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Text('Erreur : ${snapshot.error}');
        }

        return getPromptSelectedWidget(snapshot.data ?? {}, info, context);
      },
    );
  }

  Widget getPromptSelectedWidget(
    Map<String, String> extendedMd,
    DocumentationConfig info,
    BuildContext context,
  ) {
    var mdModel = DocumentationGenerator(config: info)
        .getModelDocumentation('\n${extendedMd['mdModel'] ?? ''}\n');

    var mdPersistance = DocumentationGenerator(config: info)
        .getModelDocumentation('\n${extendedMd['mdPersistance'] ?? ''}\n');

    // var mdOther = DocumentationGenerator(
    //   config: info,
    // ).getModelDocumentation("");

    //return MiroLikeWidget();

    var module =
        currentCompany.listModel!.selectedAttr?.parent?.info.name ?? 'module';

    var aggregate =
        currentCompany.listModel!.selectedAttr?.info.name ?? 'aggregate';

    var kind = currentCompany.listModel!.selectedAttr?.info.type ?? 'kind';
    var title =
        currentCompany.listModel!.selectedAttr?.info.properties?['title'] ??
        'title';
    var description =
        currentCompany
            .listModel!
            .selectedAttr
            ?.info
            .properties?['description'] ??
        'description';
    var version =
        currentCompany.listModel!.selectedAttr?.info.properties?['#version'] ??
        '0.0.0';

    WidgetPrompt promptWidget = WidgetPrompt(
      listPrompt: [
        PromptItem(
          name: 'domain',
          isSelectable: true,
          markdownBuild: getPromptModel(
            mdModel,
            module,
            HeaderSpec(
              kind: kind,
              name: aggregate,
              title: title,
              domain: currentCompany.listDomain?.selectedAttr?.info.name ?? '?',
              description: description,
              created: DateTime.now().toIso8601String(),
              updated: DateTime.now().toIso8601String(),
              tags: '   - $kind',
              version: version,
              generationDomain: '''
    domain: true
    application: false
    infrastructure: false
    openapi: false
    tests: false
    documentation: true
''',
            ),
          ),
          markdownKownledge: mdModel,
          fileName: 'domain-$module-$aggregate.md',
        ),
        PromptItem(
          name: 'persistence',
          isSelectable: true,
          markdownBuild: getPromptPersistance(
            mdPersistance,
            module,
            HeaderSpec(
              kind: 'entity',
              name: aggregate,
              title: title,
              domain: currentCompany.listDomain?.selectedAttr?.info.name ?? '?',
              description: description,
              created: DateTime.now().toIso8601String(),
              updated: DateTime.now().toIso8601String(),
              version: version,
              tags: '   - $kind',
              generationDomain: '''
    domain: false
    application: false
    infrastructure: true
    openapi: false
    tests: false
    documentation: true
''',
            ),
          ),
          markdownKownledge: mdPersistance,
          fileName: 'persistence-$module-$aggregate.md',
        ),
        PromptItem(
          name: 'domain unit test',
          isSelectable: true,
          markdownBuild: getPromptTest(
            mdModel,
            module,
            HeaderSpec(
              kind: 'test',
              name: aggregate,
              title: title,
              domain: currentCompany.listDomain?.selectedAttr?.info.name ?? '?',
              description: description,
              created: DateTime.now().toIso8601String(),
              updated: DateTime.now().toIso8601String(),
              tags: '   - test',
              version: version,
              generationDomain: '''
    domain: false
    application: false
    infrastructure: false
    openapi: false
    tests: true
    documentation: true
''',
            ),
          ),
          markdownKownledge: '',
          fileName: 'domain_unit_test-$module-$aggregate.md',
        ),
        // PromptItem(
        //   name: 'use case',
        //   isSelectable: true,
        //   markdownBuild: getPromptUseCase(module, aggregate),
        //   markdownKownledge: '',
        //   fileName: 'usecase-$module-$aggregate.md',
        // ),
        // PromptItem(
        //   name: 'interface',
        //   isSelectable: true,
        //   markdownBuild: getPromptInterface(module, aggregate),
        //   markdownKownledge: '',
        //   fileName: 'interface-$module-$aggregate.md',
        // ),
        // PromptItem(
        //   name: 'check integration',
        //   isSelectable: true,
        //   markdownBuild: getPromptIntegration(module),
        //   markdownKownledge: '',
        //   fileName: 'check-integration-$module.md',
        // ),
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
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('copied to clipboard')));
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
          settings: const RouteSettings(name: 'AI agent spec'),
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
          settings: const RouteSettings(name: 'List model & contract'),
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
