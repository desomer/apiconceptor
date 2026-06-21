import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:fuzzy/data/result.dart' show Result;
import 'package:fuzzy/fuzzy.dart';
import 'package:jsonschema/authorization_manager.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/model/pan_model_version_list.dart';
import 'package:jsonschema/feature/pan_attribut_editor_detail.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/pages/model_design/design_model_page.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_layout.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/widget/editor/doc_editor.dart';
import 'package:jsonschema/widget/tree_editor/pan_yaml_tree.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';
import 'package:jsonschema/widget/widget_comment.dart';
import 'package:jsonschema/widget/widget_glasspan.dart';
import 'package:jsonschema/widget/widget_glossary_indicator.dart';
import 'package:jsonschema/widget/widget_overflow.dart';
import 'package:jsonschema/widget/widget_tab.dart';
import 'package:jsonschema/widget/widget_tooltip.dart';

import '../../widget/tree_editor/tree_view.dart';

var withGlossaryIndicator = true;

mixin PanModelEditorHelper {
  Widget getChip(
    Widget content, {
    required Color? color,
    double? height,
    double? width,
  }) {
    var w = Chip(
      labelPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 5),
      color: WidgetStatePropertyAll(color),
      padding: const EdgeInsets.all(0),
      label: content, // SelectionArea(child: content),
    );
    if (height != null || width != null) {
      return SizedBox(height: height, width: width, child: w);
    }
    return w;
  }

  List<Widget> getTooltipFromProposal(ProposalInfo? info) {
    List<Widget> tooltip = [];
    if (info?.properties != null) {
      for (var element in info!.properties!.entries) {
        if (!element.key.startsWith('\$\$') && !element.key.startsWith('#')) {
          tooltip.add(
            Text(
              '${element.key} = ${element.value}',
              style: const TextStyle(fontSize: 15),
            ),
          );
        }
      }
    }

    if (tooltip.isEmpty) {
      tooltip.add(const Text('No information'));
    }
    return tooltip;
  }

  void applyProposalToAttribut(
    NodeAttribut attr,
    ModelSchema schema,
    ProposalInfo proposal,
  ) {
    final props = proposal.properties;
    if (props == null) {
      return;
    }

    attr.info.cacheRowWidget = null;
    attr.info.numUpdateForKey++;
    for (final entry in props.entries) {
      ModelAccessorAttr(
        node: attr,
        schema: schema,
        propName: entry.key,
        editable: true,
      ).set(entry.value);
    }

    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      // ignore: invalid_use_of_protected_member
      currentYamlTree?.keyAttrEditor.currentState?.setState(() {});
    });
  }

  void addAttributWidget(
    List<Widget> row,
    NodeAttribut attr,
    ModelSchema schema,
    BuildContext context,
  ) {
    var accessor = ModelAccessorAttr(
      node: attr,
      schema: schema,
      propName: 'title',
      editable: !attr.info.type.startsWith('\$'),
    );

    bool proposal = false;
    if (accessor.isEditable() && (accessor.get()?.isEmpty ?? true) == true) {
      proposal = true;
      BuildContext? loadingContext;

      Future<Null> onTapProposal() async {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            loadingContext = dialogContext;
            return PopScope(
              canPop: false,
              child: AlertDialog(
                content: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(width: 14),
                    const Text('Recherche en cours...'),
                  ],
                ),
              ),
            );
          },
        );

        //pop le dialog de loading
        List<Result<ProposalInfo>> result = await searchProposal(attr);

        // ignore: use_build_context_synchronously
        Navigator.of(loadingContext!).pop();
        if (!context.mounted) return;

        showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text('Search results for "${attr.info.name}"'),
              content: SizedBox(
                width: 500,
                child: result.isEmpty
                    ? Text('No result found for "${attr.info.name}"')
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: result.length,
                        itemBuilder: (context, index) {
                          final r = result[index];
                          final scoreTxt = r.score.toStringAsFixed(3);
                          return AnimatedTooltip(
                            content: Column(
                              children: getTooltipFromProposal(r.item),
                            ),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blueGrey.withAlpha(130),
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                onTap: () {
                                  applyProposalToAttribut(attr, schema, r.item);
                                  Navigator.of(dialogContext).pop();
                                },
                                leading: getColorIndicatorFromScore(r.score),
                                title: Text(
                                  '${index + 1}.) ${r.item.name} from ${r.item.domain}.${r.item.model} ',
                                ),
                                subtitle: Text(
                                  '${r.item.path}  score: $scoreTxt',
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      }

      row.add(
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTapProposal,
            child: Container(
              margin: const EdgeInsets.all(5),
              width: 50,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.blueGrey,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  'Proposal',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
          ),
        ),
      );
    }

    row.add(
      CellEditor(
        width: proposal ? 190 : null,
        inArray: true,
        key: ValueKey(
          '${schema.getVersionId()}%${attr.info.name}%${attr.info.numUpdateForKey}',
        ),
        acces: accessor,
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
            child: //Row(
                //children: [
                ThreadCommentCell(
                  contextId:
                      '${attr.info.getMasterID()}@${schema.id}', // unique par attribut
                  childIfComment: const Icon(
                    Icons.comment,
                    color: Colors.white,
                  ),
                  childOver: isHovered
                      ? const Icon(
                          Icons.add_comment_outlined,
                          color: Colors.grey,
                        )
                      : const SizedBox.shrink(),
                ),
            // if (isHovered)
            //   Icon(Icons.add_comment_outlined, color: Colors.grey),
            // Text(
            //   'comment',
            //   style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            // ),
            //],
            //),
          );
        },
      ),
    );

    List<Widget> rowIndicator = [];

    bool minmax =
        (attr.info.properties?['minimum'] != null) ||
        (attr.info.properties?['maximun'] != null) ||
        (attr.info.properties?['minLength'] != null) ||
        (attr.info.properties?['maxLength'] != null) ||
        (attr.info.properties?['minItems'] != null) ||
        (attr.info.properties?['maxItems'] != null);

    if ((currentPropTabController?.index ?? 0) < 2) {
      rowIndicator.addAll(<Widget>[
        //SizedBox(width: 10),
        if (attr.info.properties?['required'] == true)
          const Icon(Icons.check_circle_outline),
        if (attr.info.properties?['#nullable'] == true)
          getChip(const Text('nullable'), color: null),
        if (attr.info.properties?['const'] != null)
          getChip(const Text('const'), color: null),
        if (attr.info.properties?['enum'] != null) const Icon(Icons.checklist),
        if (attr.info.properties?['pattern'] != null)
          getChip(const Text('regex'), color: null),
        if (attr.info.properties?['format'] != null)
          getChip(Text(attr.info.properties?['format']), color: null),
        if (minmax) const Icon(Icons.tune),
        if (attr.info.properties?['#enumLabel'] != null)
          const Icon(Icons.label_outline),
        if (attr.info.properties?['#link'] != null)
          getChip(const Text('link'), color: Colors.blue),
      ]);
    } else {
      if (attr.info.properties?['#source'] != null) {
        String source = attr.info.properties?['#source'];
        rowIndicator.add(
          Container(
            width: 200,
            padding: const EdgeInsets.only(left: 5),
            child: Align(
              alignment: Alignment.centerLeft,
              child: getChip(
                Text(source),
                color: Colors.greenAccent.withAlpha(100),
              ),
            ),
          ),
        );
      }
    }

    if (attr.info.properties?['#tag'] != null) {
      List<dynamic> tags = attr.info.properties?['#tag'];
      for (var element in tags) {
        rowIndicator.add(
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey, width: 1),
            ),
            padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 8),
            child: Text(element, style: const TextStyle(fontSize: 14)),
          ),
        );
      }
    }

    row.add(
      Expanded(
        child: NoOverflowErrorFlex(
          direction: Axis.horizontal,
          mainAxisSize: MainAxisSize.max,
          children: rowIndicator,
        ),
      ),
    );

    if (withGlossaryIndicator) {
      attr.info.cacheIndicatorWidget ??= WidgetGlossaryIndicator(
        attr: attr.info,
      );
      row.addAll(<Widget>[/*Spacer(),*/ attr.info.cacheIndicatorWidget!]);
    }
  }

  Future<List<Result<ProposalInfo>>> searchProposal(NodeAttribut attr) async {
    List<ProposalInfo> existingProposals = [];

    final result = currentCompany.searchProposal(attr);

    for (var r in result) {
      existingProposals.add(r.item);
    }

    List? resultsbdd = await bddStorage.supabase.rpc(
      'search_attributs',
      params: {
        'q': attr.info.name,
        'lang': 'english',
        'company_id': currentCompany.companyId,
      },
    );

    if (resultsbdd != null) {
      for (var element in resultsbdd) {
        Map<String, dynamic> hasProp = {...element['prop'] ?? {}};
        hasProp.removeWhere((key, value) {
          return key.startsWith('\$') ||
              key.startsWith('#') ||
              value == null ||
              (value is String && value.isEmpty);
        });
        if (hasProp.isNotEmpty) {
          String schemaId = element['schema_id'];
          String namespace = element['namespace'];
          String companyId = element['company_id'];

          if (schemaId == 'api') continue; // only api model for now
          // recuperer le model name a partir des 3 infos                  String modelName = 'unknown';
          var listModel = await bddStorage.supabase
              .from('attributs')
              .select('*')
              .eq('schema_id', 'model')
              .eq('category', 'allModel')
              .eq('attr_id', schemaId)
              .eq('namespace', namespace)
              .eq('company_id', companyId);

          if (listModel.isEmpty) continue;
          //get Namespace name
          var aDomain =
              currentCompany.listDomain
                  ?.getNodeByMasterIdPath(listModel.first['namespace'] ?? '')
                  ?.info
                  .name ??
              '';
          var modelName = listModel.first['path'].split('>').last ?? 'unknown';
          var path = element['path'].replaceAll('>', '.');
          if (path.startsWith('root.')) {
            path = path.substring(5);
          }

          var proposalInfo = ProposalInfo(
            name: path.split('.').last,
            path: path,
            properties: hasProp,
            model: modelName,
            domain: aDomain,
          );
          existingProposals.add(proposalInfo);
        }
      }
    }

    var fuse = Fuzzy<ProposalInfo>(
      existingProposals,
      options: currentCompany.getOptionFuse(),
    );
    final searchResult = fuse.search(attr.info.name, 20);

    return searchResult;
  }

  Widget? getColorIndicatorFromScore(double score) {
    if (score < 0.01) {
      return const Icon(Icons.circle, color: Colors.green, size: 12);
    } else if (score < 0.05) {
      return const Icon(Icons.circle, color: Colors.orange, size: 12);
    } else {
      return const Icon(Icons.circle, color: Colors.red, size: 12);
    }
  }
}

class PanModelEditorMain extends StatefulWidget {
  const PanModelEditorMain({
    super.key,
    required this.idModel,
    required this.showCaseInfo,
  });
  final String idModel;
  final ShowCaseInfo showCaseInfo;

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
        showCaseInfo: widget.showCaseInfo,
      ),
    );
  }
}

// ignore: must_be_immutable
class PanModelEditor extends PanYamlTree
    with PanModelEditorHelper, GlassPaneMixin {
  PanModelEditor({
    super.key,
    required super.getSchemaFct,
    required super.showCaseInfo,
  });

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
              const Tab(text: 'Structure'),
              const Tab(text: 'Info'),
              const Tab(text: 'Version'),
              //Tab(text: 'Restore point'),
            ],
            listTabCont: [
              super.getLoader(),
              const SizedBox.shrink(),
              const SizedBox.shrink(),
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
      InfoManagerListModel mm =
          currentCompany.listModel!.infoManager as InfoManagerListModel;

      var color = mm.getColorOfType(
        currentCompany.currentModelSel!.info.type.toLowerCase(),
      );
      row.add(
        getChip(Text(currentCompany.currentModelSel!.info.type), color: color),
      );
      row.add(const SizedBox(width: 5));

      ModelSchemaQuality modelCompletude = schema.getModelQualityInfo();
      schema.qualityInfo = modelCompletude;
      row.add(buildStarsFromPercent(modelCompletude.completude));
      row.add(const SizedBox(width: 10));
      row.add(
        Text('Completude ${modelCompletude.completude.toStringAsFixed(2)}%'),
      );
      row.add(const SizedBox(width: 10));
      row.add(
        Text(
          'Duplicate ${modelCompletude.wordDuplication.toString()} (${modelCompletude.wordDuplicationNumber.toStringAsFixed(2)})',
        ),
      );
      return;
    }

    addAttributWidget(row, attr, schema, context);
  }

  bool toogleOnTap() {
    return false;
  }

  @override
  void doDoubleTapRow(NodeAttribut data, BuildContext context) {
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
        const Tab(text: 'Schema detail'),
        const Tab(text: 'Documentation'),
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
        const Tab(text: 'Create use cases'),
        const Tab(text: 'Enhancement use cases'),
        const Tab(text: 'Delete use cases'),
      ],
      listTabCont: const [
        SizedBox.shrink(),
        SizedBox.shrink(),
        SizedBox.shrink(),
      ],
      heightTab: 30,
    );
  }

  //-----------------------------------------------------------------------------

  @override
  Widget getLeftPan(bool withSep, BuildContext context) {
    return WidgetTab(
      listTab: [
        const Tab(text: 'Structure'),
        const Tab(text: 'Info'),
        const Tab(text: 'Version'),
        //Tab(text: 'Restore point'),
      ],
      listTabCont: [
        super.getLeftPan(withSep, context),
        getInfoForm(currentCompany.currentModelSel!),
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
        if (!model.isReadOnlyModel)
          ElevatedButton.icon(
            onPressed: () async {
              await addVersion(context, model);
            },
            label: const Text('add version'),
            icon: const Icon(Icons.add_box_outlined),
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
    await Future.delayed(const Duration(seconds: 2));
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

  Widget getInfoForm(NodeAttribut info) {
    bool isFile =
        info.info.type.toLowerCase() ==
        'flatfile'; // force le type pour l'edition du form
    currentCompany.currentModel!.isFile = isFile;

    return Padding(
      padding: const EdgeInsets.all(10),
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
            line: 3,
            inArray: false,
          ),
          if (isFile)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'File properties',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          if (isFile)
            CellEditor(
              key: ValueKey('filename#${info.info.masterID}'),
              acces: ModelAccessorAttr(
                node: info,
                schema: currentCompany.listModel!,
                propName: 'filename',
              ),
              line: 1,
              inArray: false,
            ),
          //   encoding: UTF-8
          if (isFile)
            CellEditor(
              key: ValueKey('encoding#${info.info.masterID}'),
              acces: ModelAccessorAttr(
                node: info,
                schema: currentCompany.listModel!,
                propName: 'encoding',
              ),
              line: 1,
              inArray: false,
            ),
          if (isFile)
            CellEditor(
              key: ValueKey('separator#${info.info.masterID}'),
              acces: ModelAccessorAttr(
                node: info,
                schema: currentCompany.listModel!,
                propName: 'separator',
              ),
              line: 1,
              inArray: false,
            ),
          if (isFile)
            CellEditor(
              key: ValueKey('quote#${info.info.masterID}'),
              acces: ModelAccessorAttr(
                node: info,
                schema: currentCompany.listModel!,
                propName: 'quote',
              ),
              line: 1,
              inArray: false,
            ),
          if (isFile)
            CellEditor(
              key: ValueKey('line_ending#${info.info.masterID}'),
              acces: ModelAccessorAttr(
                node: info,
                schema: currentCompany.listModel!,
                propName: 'line_ending',
              ),
              line: 1,
              inArray: false,
            ),
          //line_ending: "\n"
        ],
      ),
    );
  }

  @override
  Widget? getAttributProperties(BuildContext context) {
    return AttributProperties(
      key: showCaseInfo.keys['PropCard'] = keyAttrEditor,
      typeAttr: TypeAttr.detailmodel,
      getModel: () {
        return getSchema();
      },
      onClose: () {
        doShowAttrEditor(null);
      },
    );
  }
}
