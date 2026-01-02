import 'package:flutter/material.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/api/widget_request_helper.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/list_editor/widget_choise.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget/widget_overflow.dart';

class WidgetChoiseEnv extends StatefulWidget {
  const WidgetChoiseEnv({super.key, required this.widgetRequestHelper});

  final WidgetRequestHelper widgetRequestHelper;

  @override
  State<WidgetChoiseEnv> createState() => _WidgetChoiseEnvState();
}

const _textStyle = TextStyle(color: Colors.white, fontSize: 15);

class _WidgetChoiseEnvState extends State<WidgetChoiseEnv> with WidgetHelper {
  ValueNotifier<int> change = ValueNotifier<int>(0);

  @override
  Widget build(BuildContext context) {
    GlobalKey keyEnv = GlobalKey(debugLabel: 'keyDomain');
    BuildContext? aCtx;

    return ValueListenableBuilder(
      valueListenable: change,
      builder: (BuildContext context, int value, Widget? child) {
        return InkWell(
          onTap: () {
            dialogBuilderBelow(
              context,
              WidgetChoise(
                model: currentCompany.listEnv,
                onSelected: (AttributInfo sel) {
                  prefs.setString("currentEnv", sel.masterID!);
                  currentCompany.listEnv.setCurrentAttr(sel);
                  Navigator.of(aCtx!).pop();
                  change.value++;

                  // change l'url
                  widget.widgetRequestHelper.apiCallInfo.requestVariableValue
                      .clear();
                  widget.widgetRequestHelper.apiCallInfo.fillVar().then((
                    value,
                  ) {
                    widget.widgetRequestHelper.changeUrl.value++;
                  });

                  // Future.delayed(Duration(milliseconds: 200)).then((timeStamp) {
                  //   // attend fermeture du popup
                  //   forcePage = 2;
                  //   // ignore: use_build_context_synchronously
                  //   context.pushReplacement(
                  //     '${route.path}?id=${currentCompany.currentNameSpace}',
                  //   );
                  // });
                },
              ),
              keyEnv,
              Offset(-200, 0),
              (BuildContext ctx) {
                aCtx = ctx;
              },
            );
          },
          child: Container(
            color: Colors.blue,
            key: keyEnv,
            height: 30,
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: NoOverflowErrorFlex(
              direction: Axis.horizontal,
              children: [
                Icon(Icons.dns_rounded),
                SizedBox(width: 10),
                Text(
                  currentCompany.listEnv.selectedAttr?.info.name ?? 'No env',
                  style: _textStyle,
                ),
                SizedBox(width: 10),
                Icon(Icons.arrow_drop_down, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
