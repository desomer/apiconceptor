import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/feature/apm/pan_application_flow.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_tab.dart';

class AppFlowPage extends GenericPageStateless {
  const AppFlowPage({super.key});

  @override
  Widget build(BuildContext context) {
    return WidgetTab(
      onInitController: (TabController tab) {},
      listTab: [Tab(text: 'Applications flow')],
      listTabCont: [
        PanApplicationFlow(
          getSchemaFct: () async {
            // currentCompany.glossaryManager.dico.clear();
            // currentCompany.listGlossary = await loadGlossary('glossary', 'Glossary');
            currentCompany.currentFlow = await loadAppFlow('all', true);
            return currentCompany.currentFlow!;
          },
        ),
      ],
      heightTab: 40,
    );
  }

  @override
  NavigationInfo initNavigation(
    GoRouterState routerState,
    BuildContext context,
    GlobalKey keyPage,
    PageInit? pageInit,
  ) {
    return NavigationInfo();
  }
}
