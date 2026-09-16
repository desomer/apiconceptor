import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart' show GoRouterState, GoRouterHelper;
import 'package:jsonschema/core/api/widget_api_helper.dart';
import 'package:jsonschema/core/util.dart';
import 'package:jsonschema/feature/documentation/documentation_options.dart';
import 'package:jsonschema/pages/apm/widget_prompt.dart';
import 'package:jsonschema/pages/model_design/design_api_detail_page.dart';
import 'package:jsonschema/prompts/prompt_integration.dart';
import 'package:jsonschema/prompts/prompt_interface.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/prompts/prompt_usecase.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';
import 'package:markdown_widget/config/configs.dart';
import 'package:markdown_widget/widget/markdown.dart';

// ignore: must_be_immutable
class DesignApiPromptPage extends GenericPageStateless {
  DesignApiPromptPage({super.key});
  String query = '';

  // String getPromptTest(String md, String module) {
  //   return promptTest
  //       .replaceAll('{{definition du domaine}}', md)
  //       .replaceAll('{{module}}', module);
  // }

  String getPromptInterface(String module, String swagger) {
    // remplace {{definition du domaine}} par le contenu de md
    return promptInterface
        .replaceAll('{{module}}', module)
        .replaceAll('{{swagger}}', swagger);
  }

  String getPromptIntegration(String module) {
    return promptIntegration.replaceAll('{{MODULE}}', module);
  }

  String getPromptUseCase(String module, String aggregates) {
    // remplace {{definition du domaine}} par le contenu de md
    return promptUseCase
        .replaceAll('{{module}}', module)
        .replaceAll('{{aggregates}}', aggregates);
  }

  String endpointToFileName(String endpoint) {
    return endpoint
        .replaceAllMapped(RegExp(r'\{([^}]+)\}'), (m) => 'by_${m.group(1)}')
        .replaceAll('/', '_')
        .replaceAll(RegExp(r'^_+|_+$'), '')
        .replaceAll(RegExp(r'_+'), '_');
  }

  Future<Map<String, dynamic>> initIAContext() async {
    var attr = currentCompany.listAPI!.getNodeByMasterIdPath(query)!;
    currentCompany.listAPI!.selectedAttr = attr;

    //rechercher de l'avant derrier noeud
    var parentAttr = attr.parent;
    while (parentAttr?.parent?.info.name != "root") {
      parentAttr = parentAttr!.parent;
    }

    var requestHelper = WidgetAPIHelper(
      apiNodeForCalculatePath: attr,
      apiCallInfo: getAPICall(
        currentCompany.currentNameSpace,
        currentCompany.listAPI!.selectedAttr!.info,
      ),
    );

    var aSwaggerinfo = await getSwaggerFromApiCallInfo(requestHelper);
    var endpointName = endpointToFileName(requestHelper.apiCallInfo.url);

    // var _schema = currentCompany.current

    // ExportToSwagger export = ExportToSwagger(
    //   config: BrowserConfig(isApi: true),
    // );
    // export.browse(_schema, false);

    // var result = await loadBehaviour(
    //   currentCompany.currentModel!.namespace!,
    //   currentCompany.currentModel!.id,
    //   true,
    // );

    // BrowseSingle(config: BrowserConfig()).browse(result, false);

    // StringBuffer mdModel = StringBuffer();
    // StringBuffer mdPersistance = StringBuffer();

    // result.modelPropertiesByPath.forEach((key, value) {
    //   Map<String, dynamic> props = value;
    //   AttributInfo attr = result.mapInfoByJsonPath[key]!;

    //   String? invariantsBehaviors = props['invariantsBehaviors'];
    //   String? stateChangingBehaviors = props['stateChangingBehaviors'];
    //   String? queryBehavior = props['queryBehaviors'];
    //   String? policyBehaviors = props['policyBehaviors'];
    //   String? domainEventBehaviors = props['domainEventBehaviors'];
    //   String? factoryBehaviors = props['factoryBehaviors'];
    //   String? persistenceBehaviors = props['persistencePolicy'];

    //   mdModel.writeln('# set of features ${attr.name} at ${attr.type}\n');

    //   if (invariantsBehaviors != null && invariantsBehaviors.isNotEmpty) {
    //     mdModel.writeln('## Invariants behaviors\n');
    //     mdModel.writeln(invariantsBehaviors);
    //   }
    //   if (stateChangingBehaviors != null && stateChangingBehaviors.isNotEmpty) {
    //     mdModel.writeln('## State‑changing behaviors\n');
    //     mdModel.writeln(stateChangingBehaviors);
    //   }
    //   if (queryBehavior != null && queryBehavior.isNotEmpty) {
    //     mdModel.writeln('## Query behaviors\n');
    //     mdModel.writeln(queryBehavior);
    //   }
    //   if (policyBehaviors != null && policyBehaviors.isNotEmpty) {
    //     mdModel.writeln('## Policy Services\n');
    //     mdModel.writeln(policyBehaviors);
    //   }
    //   if (domainEventBehaviors != null && domainEventBehaviors.isNotEmpty) {
    //     mdModel.writeln('## Domain event behaviors\n');
    //     mdModel.writeln(domainEventBehaviors);
    //   }
    //   if (factoryBehaviors != null && factoryBehaviors.isNotEmpty) {
    //     mdModel.writeln('## Factory behaviors\n');
    //     mdModel.writeln(factoryBehaviors);
    //   }
    //   if (persistenceBehaviors != null && persistenceBehaviors.isNotEmpty) {
    //     mdModel.writeln('## Persistence behaviors\n');
    //     mdModel.writeln(persistenceBehaviors);
    //     mdPersistance.writeln('## Persistence Policy\n');
    //     mdPersistance.writeln(persistenceBehaviors);
    //   }
    // });

    return {
      'swagger': aSwaggerinfo.swagger,
      'subdomain': parentAttr!.info.name,
      'aggregate': endpointName,
    };
  }

  @override
  Widget build(BuildContext context) {
    DocumentationConfig info = DocumentationConfig();
    info.showExampleAvro = false;
    info.showExampleDto = false;
    info.showExampleMongoose = false;

    return FutureBuilder<Map<String, dynamic>>(
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
    Map<String, dynamic> extendedMd,
    DocumentationConfig info,
    BuildContext context,
  ) {
    // var mdModel = DocumentationGenerator(
    //   config: info,
    // ).getModelDocumentation('\n${extendedMd['mdModel'] ?? ''}\n');

    // var mdPersistance = DocumentationGenerator(
    //   config: info,
    // ).getModelDocumentation('\n${extendedMd['mdPersistance'] ?? ''}\n');

    // var mdOther = DocumentationGenerator(
    //   config: info,
    // ).getModelDocumentation("");

    //return MiroLikeWidget();

    String subdomain = extendedMd['subdomain'] ?? '';
    String aggregate = extendedMd['aggregate'] ?? '';

    WidgetPrompt promptWidget = WidgetPrompt(
      listPrompt: [

        PromptItem(
          name: 'use case',
          isSelectable: true,
          markdownBuild: getPromptUseCase(subdomain, aggregate),
          markdownKownledge: '',
          fileName: 'usecase-$subdomain-$aggregate.md',
        ),

        PromptItem(
          name: 'interface',
          isSelectable: true,
          markdownBuild: getPromptInterface(subdomain, extendedMd["swagger"]!),
          markdownKownledge: '',
          fileName: 'interface-$subdomain-$aggregate-swagger.md',
        ),

        // PromptItem(
        //   name: 'domain unit test',
        //   isSelectable: true,
        //   markdownBuild: getPromptTest(mdModel, module),
        //   markdownKownledge: '',
        //   fileName: 'domain_unit_test-$module-$aggregate.md',
        // ),
        PromptItem(
          name: 'check integration',
          isSelectable: true,
          markdownBuild: getPromptIntegration(subdomain),
          markdownKownledge: '',
          fileName: 'check-integration-$subdomain.md',
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
    query = routerState.uri.queryParameters['id']!;
    var goTo = ApiRequestNavigator();

    return NavigationInfo()
      ..navLeft = getLeftNavApi(query)
      ..breadcrumbs = [
        BreadNode(
          settings: const RouteSettings(name: 'Domain'),
          type: BreadNodeType.domain,
          path: Pages.api.urlpath,
        ),
        BreadNode(
          settings: const RouteSettings(name: 'List API'),
          type: BreadNodeType.widget,
          path: Pages.api.urlpath,
          onTap: () {
            context.pop();
          },
        ),
        ...goTo.getBreadcrumbApi(query),
      ];
  }
}
