import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/transform/engine.dart';
import 'package:jsonschema/core/transform/enrichment.dart';
import 'package:jsonschema/feature/data_mapping/pan_dest_selector.dart';
import 'package:jsonschema/feature/model/pan_model_selector.dart';
import 'package:jsonschema/core/json_browser/browse_model.dart';
import 'package:jsonschema/pages/content/widget_derived_field.dart';
import 'package:jsonschema/pages/content/widget_mapping_field.dart';
import 'package:jsonschema/pages/model_design/design_model_page.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';
import 'package:jsonschema/widget/widget_md_doc.dart';
import 'package:jsonschema/widget/widget_tab.dart';
import 'package:shortid/shortid.dart';

class MappingInfo {
  NodeAttribut? pathSrc;
  NodeAttribut? pathDest;
  MappingInfo(this.pathSrc, this.pathDest);
  List<Map<String, dynamic>> transforms = [];

  Map getJson() {
    return {
      'id': shortid.generate(),
      "source": pathSrc?.info.getMasterIDPath(),
      "target": pathDest?.info.getMasterIDPath(),
      "transforms": transforms,
    };
  }

  Map getIAJson() {
    return {
      'id': shortid.generate(),
      "source": pathSrc?.info.getJsonPath(withRoot: false),
      "target": pathDest?.info.getJsonPath(withRoot: false),
      "transforms": transforms,
    };
  }
}

class ContentMapDetailPage extends GenericPageStateless {
  const ContentMapDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DetailMappingPage();
  }

  @override
  NavigationInfo initNavigation(
    GoRouterState routerState,
    BuildContext context,
    GlobalKey keyPage,
    PageInit? pageInit,
  ) {
    return NavigationInfo()
      ..navLeft = [
        BreadNode(
          icon: const Icon(Icons.api_outlined),
          settings: const RouteSettings(name: 'Spec.'),
          type: BreadNodeType.widget,
          path: Pages.mapDataDetail.urlpath,
        ),

        BreadNode(
          icon: const Icon(Icons.smart_toy),
          settings: const RouteSettings(name: 'AI agent spec.'),
          type: BreadNodeType.widget,
          path: Pages.mapDataYaml.urlpath,
        ),
      ];
  }
}

// ignore: must_be_immutable
class DetailMappingPage extends StatefulWidget {
  DetailMappingPage({super.key});

  MappingEngineConfig config = MappingEngineConfig();

  @override
  State<DetailMappingPage> createState() => DetailMappingPageState();
}

class MappingEngineConfig {
  List<MappingInfo> listMapping = [];
  List<MappingInfo> listDerivedMapping = [];
  Map<String, dynamic>? saveData;

  ModelSchema? _currentSrcModel;
  ModelSchema? _currentDestModel;

  ModelSchema? get currentSrcModel => _currentSrcModel;
  ModelSchema? get currentDestModel => _currentDestModel;
  set currentSrcModel(ModelSchema? model) => _currentSrcModel = model;
  set currentDestModel(ModelSchema? model) => _currentDestModel = model;

  Map<String, dynamic>? dataSrc;
  Map<String, dynamic>? dataDest;
  bool isInit = false;

  ModelAccessorAttr getAccessorExtended() {
    ModelSchema model = currentCompany.currentDataMap!;
    var dm = currentCompany.currentDataMapSel;
    var id = "#${dm?.info.masterID}";
    var dmNode = model.getExtendedNode(id);

    var access = ModelAccessorAttr(node: dmNode, schema: model, propName: id);
    return access;
  }

  void loadEngineConfig(State? state) {
    var d = getAccessorExtended().get();
    if (d != null && isInit == false) {
      saveData = jsonDecode(d);
      loadModels(saveData!).then((value) {
        isInit = value;
        if (value) {
          // ignore: invalid_use_of_protected_member
          state?.setState(() {});
        }
      });
    }
  }

  Future<bool> loadModels(Map saveData) async {
    _currentSrcModel ??= await currentCompany.getModelByMasterId(
      saveData['srcMamespace'],
      saveData['src'],
    );
    _currentDestModel ??= await currentCompany.getModelByMasterId(
      saveData['destMamespace'],
      saveData['dest'],
    );

    if (_currentSrcModel == null || _currentDestModel == null) {
      return false;
    }

    await BrowseSingle(config: BrowserConfig())
        .browseSync(_currentSrcModel!, false, 0);
    await BrowseSingle(config: BrowserConfig())
        .browseSync(_currentDestModel!, false, 0);

    return true;
  }
}

class DetailMappingPageState extends State<DetailMappingPage> {
  DetailMappingPageState();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // if (config.currentDestModel == null) {
    //   config.currentSrcModel ??= currentCompany.currentModel;
    // } else {
    //   config.currentDestModel ??= currentCompany.currentModel;
    // }

    var config = widget.config;

    if (!config.isInit) {
      config.loadEngineConfig(this);
      currentCompany.currentMapEngine = config;
    }

    if (config.saveData != null &&
        widget.config._currentSrcModel != null &&
        widget.config._currentDestModel != null) {
      config.listMapping.clear();
      for (var field in config.saveData!['fields']) {
        NodeAttribut? pathSrc = config.currentSrcModel!.getNodeByMasterIdPath(
          field['source'],
        );
        NodeAttribut? pathDest = config.currentDestModel!.getNodeByMasterIdPath(
          field['target'],
        );
        List? field2 = field['transforms'];
        config.listMapping.add(
          MappingInfo(pathSrc, pathDest)
            ..transforms =
                field2?.cast<Map<String, dynamic>>() ??
                <Map<String, dynamic>>[],
        );
      }
    }

    final GlobalKey<WidgetMappingState> keyMapping = GlobalKey();
    final GlobalKey<WidgetDerivedFieldState> keyDerivedMapping = GlobalKey();

    final GlobalKey<WidgetMappingState> keySrc = GlobalKey();
    final GlobalKey<WidgetMappingState> keyDest = GlobalKey();

    PanDestSelector srcWidget = PanDestSelector(
      key: keySrc,
      getSchemaFct: () {
        return config.currentSrcModel;
      },
      onMapping: (json) {
        config.dataSrc = json;
      },
      onSelected: (NodeAttribut attr) {
        config.listMapping.add(MappingInfo(attr, null));
        keyMapping.currentState?.valueListenable.value++;
        saveEngineConfig();
      },
    );

    PanDestSelector destWidget = PanDestSelector(
      key: keyDest,
      onMapping: (json) {
        config.dataDest = json;
      },
      getSchemaFct: () {
        return config.currentDestModel;
      },
      onSelected: (NodeAttribut attr) {
        if (tabController.index == 0) {
          if (config.listMapping.isEmpty) {
            return;
          }
          config.listMapping.last.pathDest = attr;
          saveEngineConfig();
          keyMapping.currentState?.valueListenable.value++;
        } else if (tabController.index == 1) {
          config.listDerivedMapping.add(MappingInfo(null, attr));
          saveEngineConfig();
          keyDerivedMapping.currentState?.valueListenable.value++;
        }
      },
    );

    return getMainEdit(
      keyMapping: keyMapping,
      keyDerivedMapping: keyDerivedMapping,
      listMapping: config.listMapping,
      listDerivedMapping: config.listDerivedMapping,
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 5,
        children: [
          Flexible(
            child: Column(
              children: [
                Container(
                  color: Colors.blue,
                  height: 30,
                  child: WidgetHeader(
                    key: ObjectKey(config.currentSrcModel ?? "empty"),
                    title: 'Seed model',
                    modelWidget: srcWidget,
                    onChange: () {
                      setState(() {
                        doCleanAll(keyDerivedMapping, keyMapping);
                        config.currentSrcModel = null;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: config.currentSrcModel == null
                      ? Center(
                          child: ElevatedButton(
                            onPressed: () => selectModel(context, true),
                            child: Text('select source model'),
                          ),
                        )
                      : srcWidget,
                ),
              ],
            ),
          ),
          IconButton.filled(
            onPressed: () async {
              await executeMapping(destWidget);
            },
            icon: Icon(Icons.play_arrow),
          ),
          Flexible(
            child: Column(
              children: [
                Container(
                  color: Colors.blue,
                  height: 30,
                  child: WidgetHeader(
                    key: ObjectKey(config.currentDestModel ?? "empty"),
                    title: 'Destination model',
                    modelWidget: destWidget,
                    onChange: () {
                      setState(() {
                        doCleanAll(keyDerivedMapping, keyMapping);
                        config.currentDestModel = null;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: config.currentDestModel == null
                      ? Center(
                          child: ElevatedButton(
                            onPressed: () => selectModel(context, false),
                            child: Text('select destination model'),
                          ),
                        )
                      : destWidget,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void doCleanAll(
    GlobalKey<WidgetDerivedFieldState> keyDerivedMapping,
    GlobalKey<WidgetMappingState> keyMapping,
  ) {
    var config = widget.config;
    config.listMapping.clear();
    config.listDerivedMapping.clear();
    keyDerivedMapping.currentState?.valueListenable.value++;
    keyMapping.currentState?.valueListenable.value++;
    config.saveData = null;
  }

  void selectModel(BuildContext context, bool isSrc) {
    BuildContext? aCtx;

    PanModelSelector panModelSelector = PanModelSelector(
      type: TypeModelSelector.dataMap,
      showCaseInfo: ShowCaseInfo(),
      isEditable: false,
      onSelectModel: (ModelSchema schema, NodeAttribut attr) async {
        aCtx?.pop();
        var aModel = await currentCompany.getModelByMasterId(
          schema.namespace!,
          attr.info.masterID!,
        );
        
        if (isSrc) {
          widget.config.currentSrcModel = aModel;
        } else {
          widget.config.currentDestModel = aModel;
        }

        await BrowseSingle(config: BrowserConfig())
            .browseSync(aModel!, false, 0);
        setState(() {});
      },
      getSchemaFct: () async {
        await Future.delayed(Duration(milliseconds: gotoDelay));
        currentCompany.listModel = await loadSchema(
          TypeMD.listmodel,
          'model',
          'Business models',
          TypeModelBreadcrumb.businessmodel,
          namespace: currentCompany.currentNameSpace,
          config: BrowserConfig(),
        );
        currentCompany.listModel!.isReadOnlyModel = true;
        return currentCompany.listModel!;
      },
    );

    panModelSelector.actionRowOnTapDetail = true;

    double width = MediaQuery.of(context).size.width * 0.8;
    double height = MediaQuery.of(context).size.height * 0.8;

    showDialog(
      context: context,
      builder: (ctx) {
        aCtx = ctx;
        return AlertDialog(
          title: Text('Select source model'),
          content: SizedBox(
            width: width,
            height: height,
            child: panModelSelector,
          ),
        );
      },
    );
  }

  Future<void> executeMapping(PanDestSelector destWidget) async {
    Map<String, dynamic> engineConfig = {'fields': []};
    for (var field in widget.config.saveData!['fields']) {
      NodeAttribut pathSrc = widget.config.currentSrcModel!.getNodeByMasterIdPath(
        field['source'],
      )!;
      NodeAttribut? pathDest = widget.config.currentDestModel!.getNodeByMasterIdPath(
        field['target'],
      );
      engineConfig['fields'].add({
        'source': pathSrc.info.getJsonPath(withRoot: false),
        'target': pathDest?.info.getJsonPath(withRoot: false),
        'transforms': field['transforms'] ?? <Map<String, dynamic>>[],
      });
    }

    final registry = EnrichmentRegistry();
    final enrichmentEngine = EnrichmentEngine(registry);
    final engine = TransformEngine(engineConfig, enrichmentEngine);
    final out = await engine.transformBatch([widget.config.dataSrc!]);
    widget.config.dataDest?.clear();
    widget.config.dataDest?.addAll(out[0]);
    destWidget.repaint();
    print(out);
  }

  void saveEngineConfig() {
    var object = {
      "src": widget.config.currentSrcModel!.id,
      "srcMamespace": widget.config.currentSrcModel!.namespace,
      "dest": widget.config.currentDestModel!.id,
      "destMamespace": widget.config.currentDestModel!.namespace,
      "fields": widget.config.listMapping.map((e) => e.getJson()).toList(),
    };
    var j = jsonEncode(object);
    widget.config.getAccessorExtended().set(j);
    widget.config.saveData = object;
  }

  late TabController tabController;

  Widget getMainEdit(
    Widget selector, {
    required List<MappingInfo> listMapping,
    required List<MappingInfo> listDerivedMapping,
    required GlobalKey<WidgetMappingState> keyMapping,
    required GlobalKey<WidgetDerivedFieldState> keyDerivedMapping,
  }) {
    return Column(
      children: [
        // Row(
        //   mainAxisAlignment: MainAxisAlignment.start,
        //   children: [
        //     ElevatedButton(
        //       onPressed: saveEngineConfig,
        //       child: Text('Save mapping'),
        //     ),
        //   ],
        // ),
        SizedBox(
          height: 200,
          child: WidgetTab(
            onInitController: (TabController controller) {
              tabController = controller;
            },
            listTab: [
              Tab(text: 'Fields Mapping'),
              Tab(text: 'Derived fields'),
              Tab(text: 'Filtering & Data Cleaning'),
              Tab(text: 'Enrichments'),
            ],
            listTabCont: [
              WidgetMapping(
                key: keyMapping,
                listMapping: listMapping,
                onChange: () {
                  saveEngineConfig();
                },
              ),
              WidgetDerivedField(
                key: keyDerivedMapping,
                listMapping: listDerivedMapping,
                onChange: () {
                  saveEngineConfig();
                },
              ),
              Container(),
              Container(),
            ],
            heightTab: 30,
          ),
        ),
        Expanded(child: selector),
      ],
    );
  }
}

class WidgetHeader extends StatelessWidget {
  const WidgetHeader({
    super.key,
    required this.modelWidget,
    required this.title,
    required this.onChange,
  });

  final PanDestSelector modelWidget;
  final String title;
  final Function onChange;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 10),
        FilledButton(
          style: ButtonStyle(
            padding: WidgetStateProperty.all(
              EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            ),
            minimumSize: WidgetStateProperty.all(Size.zero),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          onPressed: modelWidget.getSchemaFct() == null
              ? null
              : () {
                  modelWidget.initSchema();
                  modelWidget.repaint();
                },
          child: Text('load fake'),
        ),
        Expanded(child: Center(child: Text(title))),
        FilledButton.icon(
          style: ButtonStyle(
            padding: WidgetStateProperty.all(
              EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            ),
            minimumSize: WidgetStateProperty.all(Size.zero),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          onPressed: () {
            onChange();
          },
          icon: Icon(Icons.delete),
          label: Text('change'),
        ),
        SizedBox(width: 10),
      ],
    );
  }
}
