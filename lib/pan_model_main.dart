import 'package:flutter/material.dart';
import 'package:jsonschema/pan_model_selector.dart';
import 'package:jsonschema/widget/widget_keep_alive.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget/widget_tab.dart';

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
        Tab(text: 'Entities'),
      ],
      listTabCont: [
        KeepAliveWidget(
          child: WidgetModelSelector(listModel: currentCompany.listModel, typeModel: 'Business model'),
        ),
        KeepAliveWidget(
          child: WidgetModelSelector(listModel: currentCompany.listComponent, typeModel: 'Component'),
        ),
        WidgetTab(
          listTab: [Tab(text: 'Request'), Tab(text: 'Response')],
          listTabCont: [
            WidgetModelSelector(listModel: currentCompany.listRequest, typeModel: 'Request'),
            Container(),
          ],
          heightTab: 40,
        ),
        Container(),
      ],
      heightTab: 40,
    );
  }


}
