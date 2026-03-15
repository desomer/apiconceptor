import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/transform/engine.dart';
import 'package:jsonschema/core/transform/enrichment.dart';
import 'package:jsonschema/feature/data_mapping/pan_dest_selector.dart';
import 'package:jsonschema/feature/model/pan_model_selector.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/pages/content/widget_derived_field.dart';
import 'package:jsonschema/pages/content/widget_mapping_field.dart';
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
    PageInit? pageInit,
  ) {
    return NavigationInfo()
      ..navLeft = [
        BreadNode(
          icon: const Icon(Icons.api_outlined),
          settings: const RouteSettings(name: 'Map Spec.'),
          type: BreadNodeType.widget,
          path: Pages.mapDataDetail.urlpath,
        ),

        BreadNode(
          icon: const Icon(Icons.engineering),
          settings: const RouteSettings(name: 'Yaml'),
          type: BreadNodeType.widget,
          path: Pages.mapDataYaml.urlpath,
        ),
      ];
  }
}

class DetailMappingPage extends StatefulWidget {
  const DetailMappingPage({super.key});

  @override
  State<DetailMappingPage> createState() => _DetailMappingPageState();
}

class MappingEngineConfig {
  List<MappingInfo> listMapping = [];
  List<MappingInfo> listDerivedMapping = [];
  Map<String, dynamic>? saveData;
  ModelSchema? currentSrcModel;
  ModelSchema? currentDestModel;

  Map<String, dynamic>? dataSrc;
  Map<String, dynamic>? dataDest;
  bool isInit = false;

  ModelAccessorAttr getAccessor() {
    ModelSchema model = currentCompany.currentDataMap!;
    var dm = currentCompany.currentDataMapSel;
    var id = "#${dm?.info.masterID}";
    var dmNode = model.getExtendedNode(id);

    var access = ModelAccessorAttr(node: dmNode, schema: model, propName: id);
    return access;
  }  

  void loadEngineConfig(State? state) {
    var d = getAccessor().get();
    if (d != null && isInit == false) {
      saveData = jsonDecode(d);
      loadModels(saveData!).then((value) {
        isInit = true;
        // ignore: invalid_use_of_protected_member
        state?.setState(() {});
      });
    }
  }

  Future<bool> loadModels(Map saveData) async {
    currentSrcModel = await currentCompany.getModelByMasterId(
      saveData['srcMamespace'],
      saveData['src'],
    );
    currentDestModel = await currentCompany.getModelByMasterId(
      saveData['destMamespace'],
      saveData['dest'],
    );

    await BrowseSingle().browseSync(currentSrcModel!, false, 0);
    await BrowseSingle().browseSync(currentDestModel!, false, 0);
    return true;
  }

}


class _DetailMappingPageState extends State<DetailMappingPage> {

  MappingEngineConfig config = MappingEngineConfig(); 

  @override
  Widget build(BuildContext context) {
    if (config.currentDestModel == null) {
      config.currentSrcModel = currentCompany.currentModel;
    } else {
      config.currentDestModel ??= currentCompany.currentModel;
    }

    if (!config.isInit) {
      config.loadEngineConfig(this);
      currentCompany.currentMapEngine = config;
    }

    if (config.saveData != null &&
        config.currentSrcModel != null &&
        config.currentDestModel != null) {
      config.listMapping.clear();
      for (var field in config.saveData!['fields']) {
        NodeAttribut pathSrc =
            config.currentSrcModel!.getNodeByMasterIdPath(field['source'])!;
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

    PanDestSelector srcWidget = PanDestSelector(
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
                    title: 'Seed model',
                    modelWidget: srcWidget,
                  ),
                ),
                Expanded(
                  child:
                      config.currentSrcModel == null
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
                    title: 'Destination model',
                    modelWidget: destWidget,
                  ),
                ),
                Expanded(
                  child:
                      config.currentDestModel == null
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

  void selectModel(BuildContext context, bool isSrc) {
    BuildContext? aCtx;

    PanModelSelector panModelSelector = PanModelSelector(
      type: TypeModelSelector.dataMap,
      onSelectModel: (ModelSchema schema, NodeAttribut attr) async {
        aCtx?.pop();
        var aModel = await currentCompany.getModelByMasterId(
          schema.namespace!,
          attr.info.masterID!,
        );
        if (isSrc) {
          config.currentSrcModel = aModel;
        } else {
          config.currentDestModel = aModel;
        }

        await BrowseSingle().browseSync(aModel!, false, 0);
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
        );
        return currentCompany.listModel!;
      },
    );

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
    for (var field in config.saveData!['fields']) {
      NodeAttribut pathSrc =
          config.currentSrcModel!.getNodeByMasterIdPath(field['source'])!;
      NodeAttribut? pathDest = config.currentDestModel!.getNodeByMasterIdPath(
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
    final out = await engine.transformBatch([config.dataSrc!]);
    config.dataDest?.clear();
    config.dataDest?.addAll(out[0]);
    destWidget.repaint();
    print(out);
  }



  void saveEngineConfig() {
    var object = {
      "src": config.currentSrcModel!.id,
      "srcMamespace": config.currentSrcModel!.namespace,
      "dest": config.currentDestModel!.id,
      "destMamespace": config.currentDestModel!.namespace,
      "fields": config.listMapping.map((e) => e.getJson()).toList(),
    };
    var j = jsonEncode(object);
    config.getAccessor().set(j);
    config.saveData = object;
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
  });

  final PanDestSelector modelWidget;
  final String title;

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
          onPressed: () {
            modelWidget.initSchema();
            modelWidget.repaint();
          },
          child: Text('load fake'),
        ),
        Expanded(child: Center(child: Text(title))),
      ],
    );
  }
}
