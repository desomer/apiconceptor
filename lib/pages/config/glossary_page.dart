import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/feature/glossary/pan_glossary.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_tab.dart';

class GlossaryPage extends GenericPageStateless {
  const GlossaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return WidgetTab(
      onInitController: (TabController tab) {},
      listTab: [
        Tab(text: 'Notion naming'),
        Tab(text: 'Available suffix & prefix'),
      ],
      listTabCont: [
        WidgetGlossary(
          schemaGlossary: currentCompany.listGlossary,
          typeModel: 'Notion Glossary',
        ),
        WidgetGlossary(
          schemaGlossary: currentCompany.listGlossarySuffixPrefix,
          typeModel: 'Suffix & prefix',
        ),
      ],
      heightTab: 40,
    );
  }

  @override
  NavigationInfo initNavigation(
    GoRouterState routerState,
    BuildContext context,
    PageInit? pageInit
  ) {
    return NavigationInfo();
  }
}
