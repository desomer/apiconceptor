import 'package:flutter/material.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/model/pan_model_version_list.dart';
import 'package:jsonschema/feature/pan_attribut_editor_detail.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/widget/editor/doc_editor.dart';
import 'package:jsonschema/widget/tree_editor/pan_yaml_tree.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';
import 'package:jsonschema/widget/widget_comment.dart';
import 'package:jsonschema/widget/widget_glasspan.dart';
import 'package:jsonschema/widget/widget_glossary_indicator.dart';
import 'package:jsonschema/widget/widget_tab.dart';

import '../../widget/tree_editor/tree_view.dart';

var withGlosarryIndicator = true;

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
        key: ValueKey(
          '${schema.getVersionId()}%${attr.info.name}%${attr.info.numUpdateForKey}',
        ),
        acces: ModelAccessorAttr(
          node: attr,
          schema: schema,
          propName: 'title',
          editable: !attr.info.type.startsWith('\$'),
        ),
      ),
    );

    attr.info.isHoover = ValueNotifier(false);
    row.add(
      ValueListenableBuilder<bool>(
        valueListenable: attr.info.isHoover!,
        builder: (context, isHovered, child) {
          return SizedBox(
            height: rowHeight,
            width: 30,
            // decoration:
            //     isHovered
            //         ? BoxDecoration(border: Border.all(color: Colors.grey))
            //         : null,
            //color: Colors.blueAccent,
            //margin: EdgeInsets.only(left: 10),
            child: Row(
              children: [
                ThreadCommentCell(
                  contextId: '${attr.info.getMasterID()}@${schema.id}', // unique par attribut
                  childIfComment: Icon(Icons.comment, color: Colors.white),
                  childOver:
                      isHovered
                          ? Icon(Icons.add_comment_outlined, color: Colors.grey)
                          : SizedBox.shrink(),
                ),
                // if (isHovered)
                //   Icon(Icons.add_comment_outlined, color: Colors.grey),
                // Text(
                //   'comment',
                //   style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                // ),
              ],
            ),
          );
        },
      ),
    );

    bool minmax =
        (attr.info.properties?['minimum'] != null) ||
        (attr.info.properties?['maximun'] != null) ||
        (attr.info.properties?['minLength'] != null) ||
        (attr.info.properties?['maxLength'] != null) ||
        (attr.info.properties?['minItems'] != null) ||
        (attr.info.properties?['maxItems'] != null);

    if (withGlosarryIndicator) {
      attr.info.cacheIndicatorWidget ??= WidgetGlossaryIndicator(
        attr: attr.info,
      );
    }

    row.addAll(<Widget>[
      //SizedBox(width: 10),
      if (attr.info.properties?['required'] == true)
        Icon(Icons.check_circle_outline),
      if (attr.info.properties?['#nullable'] == true)
        getChip(Text('nullable'), color: null),
      if (attr.info.properties?['const'] != null)
        getChip(Text('const'), color: null),
      if (attr.info.properties?['enum'] != null) Icon(Icons.checklist),
      if (attr.info.properties?['pattern'] != null)
        getChip(Text('regex'), color: null),
      if (attr.info.properties?['format'] != null)
        getChip(Text(attr.info.properties?['format']), color: null),
      if (minmax) Icon(Icons.tune),
      if (attr.info.properties?['#enumLabel'] != null)
        Icon(Icons.label_outline),
      if (attr.info.properties?['#link'] != null)
        getChip(Text('link'), color: Colors.blue),
    ]);

    if (attr.info.properties?['#tag'] != null) {
      List<dynamic> tags = attr.info.properties?['#tag'];
      for (var element in tags) {
        row.add(
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey, width: 1),
            ),
            padding: EdgeInsets.symmetric(vertical: 1, horizontal: 8),
            child: Text(element),
          ),
        );
      }
    }

    if (attr.info.cacheIndicatorWidget != null) {
      row.addAll(<Widget>[Spacer(), attr.info.cacheIndicatorWidget!]);
    }
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
          return ApiRequestNavigator().getModel(widget.idModel);
        },
      ),
    );
  }
}

// ignore: must_be_immutable
class PanModelEditor extends PanYamlTree
    with PanModelEditorHelper, GlassPaneMixin {
  PanModelEditor({super.key, required super.getSchemaFct});

  final GlobalKey keyVersion = GlobalKey();
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
              //Tab(text: 'Restore point'),
            ],
            listTabCont: [
              super.getLoader(),
              Container(),
              Container(),
              //Container(),
            ],
            heightTab: 30,
          ),
        ),
        Expanded(child: super.getLoader()),
      ],
    );
  }

  Widget buildStarsFromPercent(double percent) {
    // Convertit 0–100% en 0–5 étoiles
    final rating = (percent / 100) * 5;

    final fullStars = rating.floor(); // étoiles pleines
    final hasHalfStar = (rating - fullStars) >= 0.5; // demi-étoile ?
    final emptyStars = 5 - fullStars - (hasHalfStar ? 1 : 0);

    return Row(
      children: [
        // Étoiles pleines
        for (int i = 0; i < fullStars; i++)
          const Icon(Icons.star, color: Colors.amber, size: 20),

        // Demi-étoile
        if (hasHalfStar)
          const Icon(Icons.star_half, color: Colors.amber, size: 20),

        // Étoiles vides
        for (int i = 0; i < emptyStars; i++)
          const Icon(Icons.star_border, color: Colors.amber, size: 20),
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
      ModelSchemaQuality modelCompletude = schema.getModelQualityInfo();
      schema.qualityInfo = modelCompletude;
      row.add(buildStarsFromPercent(modelCompletude.completude));
      row.add(SizedBox(width: 10));
      row.add(
        Text('Completude ${modelCompletude.completude.toStringAsFixed(2)}%'),
      );
      row.add(SizedBox(width: 10));
      row.add(
        Text(
          'Duplicate ${modelCompletude.wordDuplication.toString()} (${modelCompletude.wordDuplicationNumber.toStringAsFixed(2)})',
        ),
      );
      return;
    }

    addAttributWidget(row, attr, schema);
  }

  bool toogleOnTap() {
    return false;
  }

  @override
  void doDoubleTapRow(NodeAttribut data) {
    scrollCodeEditorTo(data);
  }

  @override
  Future<void> onActionRow(
    TreeNodeData<NodeAttribut> node,
    BuildContext context,
  ) async {
    if (toogleOnTap() && (node.children?.isNotEmpty ?? false)) {
      node.doToogleChild();
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
          // if (tab.indexIsChanging && tab.index == 3) {
          //   // ignore: invalid_use_of_protected_member
          //   keyChangeViewer.currentState?.setState(() {});
          // }
        });
      },
      listTab: [
        Tab(text: 'Schema detail'),
        Tab(text: 'Documentation'),
        // Tab(text: 'Change log'),
        // Tab(text: 'Life cycle method'),
        // Tab(text: 'Mapping rules'),
        // Tab(text: 'Recommendation'),
      ],
      listTabCont: [
        viewer,
        WidgetDoc(accessorAttr: getDocAccessor()),
        //_getChangeLogTab(),
        //getLifeCycleTab(),
        //Container(),
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
        //Container(),
      ],
      heightTab: 30,
    );
  }

  ModelAccessorAttr getDocAccessor() {
    ModelSchema model = currentCompany.currentModel!;
    var examplesNode = model.getExtendedNode("#doc");

    var access = ModelAccessorAttr(
      node: examplesNode,
      schema: model,
      propName: '#doc',
    );
    return access;
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
      heightTab: 30,
    );
  }

  //-----------------------------------------------------------------------------

  @override
  Widget getLeftPan(bool withSep, BuildContext context) {
    return WidgetTab(
      listTab: [
        Tab(text: 'Structure'),
        Tab(text: 'Info'),
        Tab(text: 'Version'),
        //Tab(text: 'Restore point'),
      ],
      listTabCont: [
        super.getLeftPan(withSep, context),
        getInfoForm(),
        getVersionTab(context),
        //Container(),
      ],
      heightTab: 30,
    );
  }

  Widget getVersionTab(BuildContext context) {
    var model = currentCompany.currentModel!;
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () async {
            await addVersion(context, model);
          },
          label: Text('add version'),
          icon: Icon(Icons.add_box_outlined),
        ),
        Expanded(
          child: PanModelVersionList(
            key: keyVersion,
            schema: model,
            modelParent: currentCompany.listModel!,
            onTap: (ModelVersion version) async {
              showGlassPane(context);
              tabEditor.animateTo(0);
              await bddStorage.prepareSaveModel(model);
              await bddStorage.doStoreSync();
              model.currentVersion = version;
              model.clear();
              await changeVersion(model);
              hideGlassPane();
            },
          ),
        ),
      ],
    );
  }

  Future<void> addVersion(BuildContext context, ModelSchema model) async {
    showGlassPane(context);
    tabEditor.animateTo(0);
    await model.addVersion();
    
    // await bddStorage.prepareSaveModel(model);
    // await bddStorage.doStoreSync();
    // var versionNum = int.parse(model.versions!.first.version) + 1;
    // ModelVersion version = ModelVersion(
    //   id: model.id,
    //   version: '$versionNum',
    //   data: {
    //     'state': 'D',
    //     'by': currentCompany.shortUserId,
    //     'versionTxt': '0.0.$versionNum',
    //   },
    // );
    // model.versions!.insert(0, version);
    // model.currentVersion = version;
    // await bddStorage.storeVersion(model, version);
    // String modelYaml = model.modelYaml;
    // var modelProperties = [...model.useAttributInfo];
    // var extend = {...model.modelPropExtended};
    // model.clear();
    // await bddStorage.duplicateVersion(
    //   model,
    //   version,
    //   modelYaml,
    //   modelProperties,
    //   extend,
    // );
    await Future.delayed(Duration(seconds: 2));
    await changeVersion(model);
    // ignore: invalid_use_of_protected_member
    keyVersion.currentState?.setState(() {});
    hideGlassPane();
  }

  Future<void> changeVersion(ModelSchema model) async {
    await model.loadYamlAndProperties(cache: false, withProperties: true);
    model.doChangeAndRepaintYaml(getYamlConfig(), false, 'event');
    BreadCrumbNavigator.currentNavigationInfo?.breadcrumbs.removeLast();
    BreadCrumbNavigator.currentNavigationInfo?.breadcrumbs.add(
      BreadNode(
        settings: RouteSettings(name: model.getVersionText()),
        type: BreadNodeType.widget,
      ),
    );

    // ignore: invalid_use_of_protected_member
    BreadCrumbNavigator.keyBreadcrumb.currentState?.setState(() {});
  }

  Widget getInfoForm() {
    var info = currentCompany.listModel!.selectedAttr!;
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
      onClose: () {
        doShowAttrEditor(null);
      },
    );
  }
}
