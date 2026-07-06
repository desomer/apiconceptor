import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/feature/apm/pan_apm_application.dart';
import 'package:jsonschema/feature/apm/pan_apm_technologie.dart';

import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_tab.dart';

class ApmPage extends GenericPageStateless {
  const ApmPage({super.key});

  @override
  Widget build(BuildContext context) {
    return WidgetTab(
      onInitController: (TabController tab) {},
      listTab: [
        Tab(text: 'Applications'),
        Tab(text: 'Infrastructures'),
        Tab(text: 'Technologies'),
      ],
      listTabCont: [
        PanAPMApplication(
          getSchemaFct: () async {
            // currentCompany.glossaryManager.dico.clear();
            // currentCompany.listGlossary = await loadGlossary('glossary', 'Glossary');
            currentCompany.currentAPM = await loadApm('all', true);
            return currentCompany.currentAPM!;
          },
        ),
        Container(
          padding: const EdgeInsets.all(20),
          child: const Text('Infrastructures', style: TextStyle(fontSize: 20)),
        ),
        PanAPMTechnologie(
          getSchemaFct: () async {
            // currentCompany.glossaryManager.dico.clear();
            // currentCompany.listGlossary = await loadGlossary('glossary', 'Glossary');
            currentCompany.currentAPM = await loadApmTechnologie('all', true);
            return currentCompany.currentAPM!;
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
