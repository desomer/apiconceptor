import 'package:flutter/material.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/model/pan_model_selector.dart';
import 'package:jsonschema/widget/widget_keep_alive.dart';
import 'package:jsonschema/main.dart';
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
      listTab: [
        Tab(text: 'Business models'),
        Tab(text: 'Components'),
        Tab(text: 'DTO'),
        Tab(text: 'ORM Entities'),
      ],
      listTabCont: [
        KeepAliveWidget(child: stateModel.modelSelector),
        KeepAliveWidget(
          child: WidgetModelSelector(
            listModel: currentCompany.listComponent,
            typeModel: TypeModelBreadcrumb.component,
          ),
        ),
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
        KeepAliveWidget(
          child: WidgetModelSelector(
            listModel: currentCompany.listRequest,
            typeModel: TypeModelBreadcrumb.request,
          ),
        ),
        Container(),
      ],
      heightTab: 40,
    );
  }
}
