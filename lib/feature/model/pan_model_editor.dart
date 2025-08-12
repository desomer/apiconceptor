import 'package:flutter/material.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/model/pan_model_change_log.dart';
import 'package:jsonschema/feature/model/pan_model_version_list.dart';
import 'package:jsonschema/feature/pan_attribut_editor_detail.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/widget/editor/doc_editor.dart';
import 'package:jsonschema/widget/tree_editor/pan_yaml_tree.dart';
import 'package:jsonschema/widget/widget_glossary_indicator.dart';
import 'package:jsonschema/widget/widget_tab.dart';

import '../../widget/tree_editor/tree_view.dart';

mixin PanModelEditorHelper {
  Widget getChip(Widget content, {required Color? color, double? height}) {
    var w = Chip(
      labelPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 5),
      color: WidgetStatePropertyAll(color),
      padding: EdgeInsets.all(0),
      label: content, // SelectionArea(child: content),
    );
    if (height != null) {
      return SizedBox(height: height, child: w);
    }
    return w;
  }

  void addAttributWidget(
    List<Widget> row,
    NodeAttribut attr,
    ModelSchema schema,
  ) {
    row.add(
      CellEditor(
        inArray: true,
        key: ValueKey(attr.info.numUpdateForKey),
        acces: ModelAccessorAttr(node: attr, schema: schema, propName: 'title'),
      ),
    );

    bool minmax =
        (attr.info.properties?['minimum'] != null) ||
        (attr.info.properties?['maximun'] != null) ||
        (attr.info.properties?['minLength'] != null) ||
        (attr.info.properties?['maxLength'] != null) ||
        (attr.info.properties?['minItems'] != null) ||
        (attr.info.properties?['maxItems'] != null);

    attr.info.cacheIndicatorWidget ??= WidgetGlossaryIndicator(attr: attr.info);
    row.addAll(<Widget>[
      SizedBox(width: 10),
      if (attr.info.properties?['required'] == true)
        Icon(Icons.check_circle_outline),
      if (attr.info.properties?['const'] != null)
        getChip(Text('const'), color: null),
      if (attr.info.properties?['enum'] != null) Icon(Icons.checklist),
      if (attr.info.properties?['pattern'] != null)
        getChip(Text('regex'), color: null),
      if (minmax) Icon(Icons.tune),
      Spacer(),
      attr.info.cacheIndicatorWidget!,
    ]);
  }
}

class PanModelEditorMain extends StatefulWidget {
  const PanModelEditorMain({super.key, required this.idModel});
  final String idModel;

  @override
  State<PanModelEditorMain> createState() => _PanModelEditorMainState();
}

class _PanModelEditorMainState extends State<PanModelEditorMain> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: PanModelEditor(
        getSchemaFct: () async {
          return GoTo().initModel(widget.idModel);
        },
      ),
    );
  }
}

// ignore: must_be_immutable
class PanModelEditor extends PanYamlTree with PanModelEditorHelper {
  PanModelEditor({super.key, required super.getSchemaFct});

  final GlobalKey keyVersion = GlobalKey();
  final GlobalKey keyChangeViewer = GlobalKey();
  late TabController tabEditor;

  @override
  Widget getLoader() {
    return Row(
      children: [
        SizedBox(
          width: 350,
          child: WidgetTab(
            listTab: [
              Tab(text: 'Structure'),
              Tab(text: 'Info'),
              Tab(text: 'Version'),
              Tab(text: 'Restore point'),
            ],
            listTabCont: [
              super.getLoader(),
              Container(),
              Container(),
              Container(),
            ],
            heightTab: 40,
          ),
        ),
        Expanded(child: super.getLoader()),
      ],
    );
  }

  @override
  void addRowWidget(
    TreeNodeData<NodeAttribut> node,
    ModelSchema schema,
    List<Widget> row,
    BuildContext context,
  ) {
    var attr = node.data;
    if (attr.info.type == 'root') {
      return;
    }

    addAttributWidget(row, attr, schema);
  }

  @override
  Future<void> onActionRow(
    TreeNodeData<NodeAttribut> node,
    BuildContext context,
  ) async {
    if (node.children?.isNotEmpty ?? false) {
      node.doToogle();
    } else {
      doShowAttrEditor(node.data);
    }
  }

  //----------------------------------------------------------------------------

  @override
  Widget getRightPan(Widget viewer, BuildContext context) {
    return WidgetTab(
      onInitController: (TabController tab) {
        tabEditor = tab;
        tab.addListener(() {
          // raffraichi lr change log
          if (tab.indexIsChanging && tab.index == 3) {
            // ignore: invalid_use_of_protected_member
            keyChangeViewer.currentState?.setState(() {});
          }
        });
      },
      listTab: [
        Tab(text: 'Schema detail'),
        Tab(text: 'Life cycle method'),
        Tab(text: 'Mapping rules'),
        Tab(text: 'Change log'),
        Tab(text: 'Documentation'),
        Tab(text: 'Recommendation'),
      ],
      listTabCont: [
        viewer,
        getLifeCycleTab(),
        Container(),
        // PanDestSelector(
        //   getSchemaFct: () async {
        //     var m = ModelSchema(
        //       category: Category.model,
        //       headerName: "",
        //       id: currentCompany.currentModel!.id,
        //       infoManager: InfoManagerDest(),
        //     );
        //     await m.loadYamlAndProperties(cache: false, withProperties: true);

        //     return m;
        //   },
        // ),
        _getChangeLogTab(),
        DocEditor(),
        Container(),
      ],
      heightTab: 40,
    );
  }

  Widget getLifeCycleTab() {
    return WidgetTab(
      onInitController: (TabController tab) {},
      listTab: [
        Tab(text: 'Create use cases'),
        Tab(text: 'Enhancement use cases'),
        Tab(text: 'Delete use cases'),
      ],
      listTabCont: [Container(), Container(), Container()],
      heightTab: 40,
    );
  }

  Widget _getChangeLogTab() {
    if (currentCompany.currentModel == null) return Container();

    return PanModelChangeLog(key: keyChangeViewer);
  }
  //-----------------------------------------------------------------------------

  @override
  Widget getLeftPan(BuildContext context) {
    return WidgetTab(
      listTab: [
        Tab(text: 'Structure'),
        Tab(text: 'Info'),
        Tab(text: 'Version'),
        Tab(text: 'Restore point'),
      ],
      listTabCont: [
        super.getLeftPan(context),
        getInfoForm(),
        getVersionTab(),
        Container(),
      ],
      heightTab: 40,
    );
  }

  Widget getVersionTab() {
    var model = currentCompany.currentModel!;
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () async {
            var versionNum = int.parse(model.versions!.first.version) + 1;
            ModelVersion version = ModelVersion(
              id: model.id,
              version: '$versionNum',
              data: {
                'state': 'D',
                'by': currentCompany.userId,
                'versionTxt': '0.0.$versionNum',
              },
            );
            model.versions!.insert(0, version);
            model.currentVersion = version;
            await bddStorage.addVersion(model, version);
            // ignore: invalid_use_of_protected_member
            keyVersion.currentState?.setState(() {});
            String modelYaml = model.modelYaml;
            var modelProperties = model.useAttributInfo;
            model.clear();
            await bddStorage.duplicateVersion(
              model,
              version,
              modelYaml,
              modelProperties,
            );
            await model.loadYamlAndProperties(
              cache: false,
              withProperties: true,
            );
            model.doChangeAndRepaintYaml(getYamlConfig(), false, 'event');
          },
          label: Text('add version'),
          icon: Icon(Icons.add_box_outlined),
        ),
        Expanded(
          child: PanModelVersionList(
            key: keyVersion,
            schema: model,
            onTap: (ModelVersion version) async {
              model.currentVersion = version;
              model.clear();
              await model.loadYamlAndProperties(
                cache: false,
                withProperties: true,
              );
              model.doChangeAndRepaintYaml(getYamlConfig(), false, 'event');
              // model.initBreadcrumb();
            },
          ),
        ),
      ],
    );
  }

  Widget getInfoForm() {
    var info = currentCompany.listModel!.currentAttr!;
    return Padding(
      padding: EdgeInsets.all(10),
      child: Column(
        spacing: 10,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CellSelectEditor(),
          CellEditor(
            key: ValueKey('description#${info.info.masterID}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: currentCompany.listModel!,
              propName: 'description',
            ),
            line: 5,
            inArray: false,
          ),
          CellEditor(
            key: ValueKey('link#${info.info.masterID}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: currentCompany.listModel!,
              propName: 'link',
            ),
            line: 5,
            inArray: false,
          ),
        ],
      ),
    );
  }

  @override
  Widget? getAttributProperties(BuildContext context) {
    return AttributProperties(
      typeAttr: TypeAttr.detailmodel,
      key: keyAttrEditor,
      getModel: () {
        return getSchema();
      },
    );
  }
}
