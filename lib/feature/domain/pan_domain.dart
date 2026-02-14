import 'package:animated_tree_view/tree_view/tree_node.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/list_editor/widget_list_editor.dart';
import 'package:jsonschema/widget/tree_editor/tree_view.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget/widget_tab.dart';

class PanDomain extends StatelessWidget {
  PanDomain({super.key});

  final envChanged = ValueNotifier(0);

  @override
  Widget build(BuildContext context) {
    currentCompany.listDomain.onChange = (_) {
      if (currentCompany.listDomain.selectedAttr == null &&
          currentCompany.listDomain.useAttributInfo.isNotEmpty) {
        currentCompany.listDomain.setCurrentAttr(
          currentCompany.listDomain.useAttributInfo.first,
        );
      }
    };

    var listTab = <Widget>[];
    var listTabCont = <Widget>[];

    currentCompany.listEnv.mapInfoByTreePath.forEach((key, value) {
      listTab.add(Tab(text: value.name));
      listTabCont.add(
        WidgetListEditor(
          withSpacer: false,
          model: null,
          getModel: () {
            return loadVarEnv(
              currentCompany.listDomain.selectedAttr!.info.masterID!,
              value.masterID!,
              "variables",
              false
            );
          },
          change: envChanged,
        ),
      );
    });

    return Column(
      children: [
        SizedBox(
          height: 300,
          child: WidgetListEditor(
            model: currentCompany.listDomain,
            change: ValueNotifier(0),
            onSelectRow: () {
              envChanged.value++;
            },
          ),
        ),
        ValueListenableBuilder(
          valueListenable: envChanged,
          builder: (context, value, child) {
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              width: double.infinity,
              height: 30,
              color: Colors.blue,
              child: Row( spacing: 10,
                children: [
                  Icon(Icons.data_object),
                  Text(
                    '${currentCompany.listDomain.selectedAttr?.info.name ?? ''} domain variables ',
                  ),
                ],
              ),
            );
          },
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: BoxBorder.fromLTRB(
                top: BorderSide(color: Colors.grey, width: 1),
              ),
            ),
            child: WidgetTab(
              listTab: listTab,
              listTabCont: listTabCont,
              heightTab: 40,
            ),
          ),
        ),
      ],
    );
  }
}

//-------------------------------------------------------------
class InfoManagerDomain extends InfoManager with WidgetHelper {
  @override
  void addRowWidget(
    NodeAttribut attr,
    ModelSchema schema,
    List<Widget> row,
    BuildContext context,
  ) {
    row.add(
      CellEditor(
        inArray: true,
        key: ValueKey(attr.info.numUpdateForKey),
        acces: ModelAccessorAttr(node: attr, schema: schema, propName: 'title'),
      ),
    );
  }

  @override
  Widget getAttributHeaderOLD(TreeNode<NodeAttribut> node) {
    throw UnimplementedError();
  }

  @override
  String getTypeTitle(NodeAttribut node, String name, dynamic type) {
    return type.toString();
  }

  @override
  InvalidInfo? isTypeValid(
    NodeAttribut nodeAttribut,
    String name,
    type,
    String typeTitle,
  ) {
    return null; // No specific validation for environment variables
  }

  @override
  Widget getRowHeader(TreeNodeData<NodeAttribut> node, BuildContext context) {
    // TODO: implement getRowHeader
    throw UnimplementedError();
  }
}

//-------------------------------------------------------------
class InfoManagerDomainVariables extends InfoManager with WidgetHelper {
  @override
  void addRowWidget(
    NodeAttribut attr,
    ModelSchema schema,
    List<Widget> row,
    BuildContext context,
  ) {
    row.add(
      Expanded(child: CellEditor(
        inArray: true,
        widthInfinite: true,
        key: ValueKey(attr.info.numUpdateForKey),
        acces: ModelAccessorAttr(node: attr, schema: schema, propName: 'value'),
      ),
    ));
  }

  @override
  Widget getAttributHeaderOLD(TreeNode<NodeAttribut> node) {
    throw UnimplementedError();
  }

  @override
  String getTypeTitle(NodeAttribut node, String name, dynamic type) {
    return type.toString();
  }

  @override
  InvalidInfo? isTypeValid(
    NodeAttribut nodeAttribut,
    String name,
    type,
    String typeTitle,
  ) {
    return null; // No specific validation for environment variables
  }

  @override
  Widget getRowHeader(TreeNodeData<NodeAttribut> node, BuildContext context) {
    // TODO: implement getRowHeader
    throw UnimplementedError();
  }
}