import 'package:flutter/material.dart';
import 'package:jsonschema/widget/widget_tab.dart';


// ignore: must_be_immutable
class PanModelImportDialog extends StatelessWidget {
  PanModelImportDialog({super.key});

  late TabController tabImport;

  Widget _getImportTab(
    BuildContext ctx,
  ) {
    return WidgetTab(
      onInitController: (TabController tab) {
        tabImport = tab;
        tab.addListener(() {});
      },
      listTab: [
        Tab(text: 'From Json'),
      ],
      listTabCont: [
        Container(),
      ],
      heightTab: 40,
    );
  }



  @override
  Widget build(BuildContext context) {


    Size size = MediaQuery.of(context).size;
    double width = size.width * 0.8;
    double height = size.height * 0.8;

    return AlertDialog(
      title: const Text('Create model from ...'),
      content: SizedBox(
        width: width,
        height: height,

        child: _getImportTab(context),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: const Text('Create'),
          onPressed: () {
            if (tabImport.index == 0) {

            } else if (tabImport.index == 1) {

            }
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

}
