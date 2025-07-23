import 'package:flutter/material.dart';
import 'package:jsonschema/widget/widget_keep_alive.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget/widget_tab.dart';
import 'package:jsonschema/widget_state/state_model.dart';

class WidgetModelMain extends StatelessWidget with WidgetModelHelper {
  const WidgetModelMain({super.key});

  @override
  Widget build(BuildContext context) {
    return getBrowser(context);
  }

  Widget getBrowser(BuildContext context) {
    return WidgetTab(
      onInitController: (TabController tab) {
        stateModel.tabSubModel = tab;
        tab.addListener(() {
          stateModel.setTab();
        });
      },
      listTab: [
        Tab(text: 'Business models'),
        Tab(text: 'Components'),
        Tab(text: 'DTO'),
        Tab(text: 'ORM Entities'),
      ],
      listTabCont: [
        KeepAliveWidget(child: stateModel.modelSelector),
        KeepAliveWidget(child: stateModel.componentSelector),
        KeepAliveWidget(child: stateModel.requestSelector),

        // WidgetTab(
        //   listTab: [Tab(text: 'Request'), Tab(text: 'Response')],
        //   listTabCont: [
        //     WidgetModelSelector(
        //       listModel: currentCompany.listRequest,
        //       typeModel: TypeModelBreadcrumb.request,
        //     ),
        //     Container(),
        //   ],
        //   heightTab: 40,
        // ),
        Container(),
      ],
      heightTab: 40,
    );
  }
}
