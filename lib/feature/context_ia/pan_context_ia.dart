import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/model/pan_model_selector.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_md_doc.dart';
import 'package:jsonschema/widget/widget_tab.dart';

// ignore: must_be_immutable
class PanContextIa extends StatelessWidget {
  PanContextIa({super.key});

  @override
  Widget build(BuildContext context) {
    return WidgetTab(
      onInitController: (TabController tab) {},
      listTab: [
        Tab(text: 'Select Models'),
        Tab(text: 'Select API'),
        Tab(text: 'Select Use cases'),
      ],
      listTabCont: [
        getModelContext(),
        Container(
          padding: const EdgeInsets.all(20),
          child: const Text('Infrastructures', style: TextStyle(fontSize: 20)),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          child: const Text('Technologies', style: TextStyle(fontSize: 20)),
        ),
      ],
      heightTab: 40,
    );
  }

  PanModelSelectorContext? panModelSelector;

  Widget getModelContext() {
    panModelSelector = PanModelSelectorContext(
      isEditable: false,
      type: TypeModelSelector.model,
      getSchemaFct: () async {
        await Future.delayed(Duration(milliseconds: 100));
        currentCompany.listModel = await loadSchema(
          TypeMD.listmodel,
          'model',
          'Business models',
          TypeModelBreadcrumb.businessmodel,
          namespace: currentCompany.currentNameSpace,
          config: BrowserConfig(),
        );
        currentCompany.listModel!.isReadOnlyModel =
            isDomainAllowed(currentCompany.currentNameSpace) == false;
        return currentCompany.listModel!;
      },
      showCaseInfo: null,
    );

    return panModelSelector!;
  }
}

// ignore: must_be_immutable
class PanModelSelectorContext extends PanModelSelector {
  PanModelSelectorContext({
    super.key,
    required super.getSchemaFct,
    required super.type,
    required super.showCaseInfo,
    required super.isEditable,
  });

  @override
  void onInitSchema(BuildContext context) {
    getSchema().isReadOnlyModel = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      keyTreeEditor.currentState?.toggleCheckboxMode();
    });
  }
}
