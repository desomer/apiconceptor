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
        Tab(text: 'Technologies'),
        Tab(text: 'Infrastructures'),
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
        PanAPMTechnologie(
          getSchemaFct: () async {
            // currentCompany.glossaryManager.dico.clear();
            // currentCompany.listGlossary = await loadGlossary('glossary', 'Glossary');
            currentCompany.currentTechno = await loadApmTechnologie('all', true);
            return currentCompany.currentTechno!;
          },
        ),
        getInfraWidget(),
      ],
      heightTab: 40,
    );
  }

  Container getInfraWidget() {
    return Container(
        padding: const EdgeInsets.all(20),
        child: const Text('''Infrastructures
        Couche Infrastructure (Where ?)

Elle décrit où les technologies sont hébergées.

Exemples :

VM VMware
Serveurs physiques
Clusters Kubernetes
Azure AKS
Réseau
Load Balancer
Firewall
Stockage

Questions :

Où est déployé le composant ?
Quelle disponibilité ?
Quelle zone réseau ?
Quel hébergement ?''', style: TextStyle(fontSize: 20)),
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
