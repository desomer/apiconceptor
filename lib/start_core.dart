import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/authorization_manager.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/api/pan_api_editor.dart';
import 'package:jsonschema/feature/api/pan_api_env.dart';
import 'package:jsonschema/feature/transform/pan_model_viewer.dart';
import 'package:jsonschema/feature/domain/pan_domain.dart';
import 'package:jsonschema/json_browser/browse_api.dart';
import 'package:jsonschema/json_browser/browse_glossary.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/pages/apps/data_sources_page.dart';
import 'package:jsonschema/pages/router_layout.dart';
import 'package:jsonschema/widget/widget_show_error.dart';
import 'package:jsonschema/widget/widget_zoom_selector.dart';
import 'package:jsonschema/widget/widget_md_doc.dart';

bool withBdd = true;

Future<bool> startCore(String usermail, String password) async {
  const isRunningWithWasm = bool.fromEnvironment('dart.tool.dart2wasm');
  print('isRunningWithWasm $isRunningWithWasm');

  if (!withBdd) {
    startError.add('no bdd');
  } else {
    try {
      var ok = await bddStorage.connect(usermail, password);
      if (!ok) {
        return false;
      }
    } on Exception catch (e) {
      //print("$e");
      startError.add("$e");
      return false;
    }
  }

  UserAuthentication.stateConnection.value = 'Loading environment ...';
  var a = BrowseSingle();
  currentCompany.listEnv = await loadSchema(
    TypeMD.env,
    'env',
    'environment',
    TypeModelBreadcrumb.env,
    infoManager: InfoManagerEnv(),
    category: Category.env,
    browser: a,
  );

  if (a.root.isNotEmpty) {
    var currentEnv = prefs.getString("currentEnv");
    if (currentEnv != null) {
      var cur = a.root.firstWhereOrNull(
        (element) => element.info.masterID == currentEnv,
      );
      if (cur != null) {
        currentCompany.listEnv.setCurrentAttr(cur.info);
      }
    }
  }

  UserAuthentication.stateConnection.value = 'Loading domain ...';
  var b = BrowseSingle();
  currentCompany.listDomain = await loadSchema(
    TypeMD.domain,
    'domain',
    'domain',
    TypeModelBreadcrumb.domain,
    infoManager: InfoManagerDomain(),
    category: Category.domain,
    browser: b,
  );
  if (b.root.isNotEmpty) {
    var currentDomain = prefs.getString("currentDomain");

    if (currentDomain == null) {
      currentCompany.listDomain.setCurrentAttr(b.root.first.info);
      prefs.setString("currentDomain", b.root.first.info.masterID!);
    } else {
      var cur = b.root.firstWhereOrNull(
        (element) => element.info.masterID == currentDomain,
      );
      if (cur == null) {
        currentCompany.listDomain.setCurrentAttr(b.root.first.info);
      } else {
        currentCompany.listDomain.setCurrentAttr(cur.info);
      }
    }
  }

  UserAuthentication.stateConnection.value = 'Loading glossary ...';
  currentCompany.listGlossary = await loadGlossary('glossary', 'Glossary');
  currentCompany.listGlossarySuffixPrefix = await loadGlossary(
    'glossarySufPre',
    'Suffix & Prefix',
  );

  UserAuthentication.stateConnection.value = 'Connected...';
  currentCompany.isInit = true;
  return true;
}

Future<ModelSchema> loadAPI({required String id, String? namespace}) async {
  var currentAPIResquest = ModelSchema(
    category: Category.api,
    infoManager: InfoManagerAPIParam(typeMD: TypeMD.apiparam),
    headerName: "Parameters query, header, cookies, body",
    id: id,
    ref: null, // currentCompany.listModel,
  );

  currentAPIResquest.namespace = namespace;

  await currentAPIResquest.loadYamlAndProperties(
    cache: false,
    withProperties: true,
  );

  return currentAPIResquest;
}

Future<ModelSchema> loadAllAPI({String? namespace}) async {
  var allApi = ModelSchema(
    category: Category.allApi,
    headerName: 'API Route Path',
    id: 'api',
    infoManager: InfoManagerAPI(),
    ref: null,
  );
  allApi.namespace = namespace ?? currentCompany.currentNameSpace;

  if (withBdd) {
    try {
      await allApi.loadYamlAndProperties(cache: false, withProperties: true);
      BrowseAPI().browse(allApi, false);
    } on Exception catch (e) {
      print("$e");
      startError.add("$e");
    }
  }
  return allApi;
}

Future<void> loadAllAPIGlobal({String? namespace}) async {
  currentCompany.listAPI = await loadAllAPI(namespace: namespace);
}

Future<ModelSchema> loadGlossary(String id, String name) async {
  var schema = ModelSchema(
    category: Category.allGlossary,
    headerName: name,
    id: id,
    infoManager: InfoManagerGlossary(),
    ref: null,
  );
  schema.namespace = "default";
  if (withBdd) {
    try {
      await schema.loadYamlAndProperties(cache: false, withProperties: true);
      BrowseGlossary().browse(schema, false);
    } on Exception catch (e) {
      print("$e");
      startError.add("$e");
    }
  }
  return schema;
}

Future<ModelSchema> loadContent(
  String idDomain,
  String idEnv,
  String name,
  bool cache,
) async {
  var schema = ModelSchema(
    category: Category.variable,
    headerName: name,
    id: 'listContent/$idDomain/$idEnv',
    infoManager: InfoManagerContent(),
    ref: null,
  );

  if (withBdd) {
    try {
      await schema.loadYamlAndProperties(cache: cache, withProperties: true);
    } on Exception catch (e) {
      print("$e");
      startError.add("$e");
    }
  }
  return schema;
}

Future<ModelSchema> loadDataSource(String idDomain, bool cache) async {
  var schema = ModelSchema(
    category: Category.variable,
    headerName: "pages",
    id: 'listPages/$idDomain',
    infoManager: InfoManagerPages(),
    ref: null,
  );
  schema.namespace = "default";

  if (withBdd) {
    try {
      await schema.loadYamlAndProperties(cache: cache, withProperties: true);
    } on Exception catch (e) {
      print("$e");
      startError.add("$e");
    }
  }
  schema.namespace = "default";
  currentCompany.listPage = schema;
  return schema;
}

Future<ModelSchema> loadVarEnv(
  String idDomain,
  String idEnv,
  String name,
  bool cache,
) async {
  var schema = ModelSchema(
    category: Category.variable,
    headerName: name,
    id: 'var/$idDomain/$idEnv',
    infoManager: InfoManagerDomainVariables(),
    ref: null,
  )..namespace = idDomain;

  if (withBdd) {
    try {
      await schema.loadYamlAndProperties(cache: cache, withProperties: true);
    } on Exception catch (e) {
      print("$e");
      startError.add("$e");
    }
  }
  return schema;
}

Future<ModelSchema> loadSchema(
  TypeMD type,
  String id,
  String name,
  TypeModelBreadcrumb typeBread, {
  Category? category,
  InfoManager? infoManager,
  JsonBrowser? browser,
  String? namespace,
}) async {
  if (category == null && type == TypeMD.listmodel) {
    infoManager = InfoManagerListModel(typeMD: type);
  }

  var m = ModelSchema(
    category: category ?? Category.allModel,
    headerName: name,
    id: id,
    infoManager: infoManager ?? InfoManagerModel(typeMD: type),
    ref: null,
  );
  m.namespace ??= namespace;
  m.typeBreabcrumb = typeBread;
  if (withBdd) {
    try {
      await m.loadYamlAndProperties(cache: false, withProperties: true);
      (browser ?? BrowseModel()).browse(m, false);
    } on Exception catch (e) {
      print('$e');
      startError.add("$e");
    }
  }
  return m;
}

const constMasterID = '\$\$__id__';
const constTypeAnyof = '\$\$__anyof__';
const constNameAllof = '\$allof';
const constInline = '\$inline';
//const constTypeOneof = '\$\$__oneOf__';
const constRefOn = '\$\$__ref__';
const constType = '\$\$__type__';

final CompanyModelSchema currentCompany = CompanyModelSchema();

double scale = 0.9;
double rowHeight = 30 * scale;

ValueNotifier<String> notifierErrorYaml = ValueNotifier<String>('');

final ValueNotifier<double> openFactor = ValueNotifier(10);
WidgetZoomSelectorState? stateOpenFactor;
final ValueNotifier<int> zoom = ValueNotifier(100);
int timezoom = 0;

//GlobalKey keyAPIEditor = GlobalKey();

// ignore: must_be_immutable
class ApiArchitecEditor {
  const ApiArchitecEditor();

  //   ApiArchitecEditor({super.key});
  //   bool showLoginDialog = true;

  //   @override
  //   Widget build(BuildContext context) {
  //     return MaterialApp(
  //       localizationsDelegates: [
  //         FleatherLocalizations.delegate,
  //         GlobalMaterialLocalizations.delegate,
  //         GlobalCupertinoLocalizations.delegate,
  //         GlobalWidgetsLocalizations.delegate,
  //       ],
  //       debugShowCheckedModeBanner: false,
  //       theme: ThemeData(
  //         useMaterial3: true,
  //         colorSchemeSeed: const Color.fromRGBO(86, 80, 14, 171),
  //       ),
  //       darkTheme: ThemeData(
  //         useMaterial3: true,
  //         brightness: Brightness.dark,
  //         colorSchemeSeed: Colors.blueGrey,
  //       ),
  //       themeMode: ThemeMode.dark,

  //       home: ValueListenableBuilder(
  //         valueListenable: zoom,
  //         builder: (context, value, child) {
  //           scale = (zoom.value - 5) / 100.0;
  //           rowHeight = 30 * scale;

  //           if (showLoginDialog) {
  //             showLoginDialog = false;
  //             Future.delayed(Duration(milliseconds: 200)).then((value) {
  //               // ignore: use_build_context_synchronously
  //               _dialogBuilder(context);
  //             });
  //           }

  //           return MediaQuery(
  //             data: MediaQuery.of(context).copyWith(
  //               textScaler: TextScaler.linear(scale + 0.05),
  //               supportsShowingSystemContextMenu: true,
  //             ),
  //             child: Scaffold(
  //               bottomNavigationBar: Row(
  //                 children: [
  //                   WidgetShowError(),
  //                   SizedBox(width: 10),
  //                   InkWell(child: Icon(Icons.undo)),
  //                   SizedBox(width: 5),
  //                   InkWell(child: Icon(Icons.redo)),
  //                   SizedBox(width: 5),
  //                   SizedBox(height: 20, child: WidgetGlobalZoom()),
  //                   Spacer(),
  //                   Text('API Architect by Desomer G. V0.2.14'),
  //                 ],
  //               ),
  //               body: SafeArea(
  //                 child: WidgetRail(
  //                   listTab: [
  //                     NavigationRailDestination(
  //                       icon: Icon(Icons.design_services),
  //                       label: Text('Service'),
  //                     ),
  //                     NavigationRailDestination(
  //                       icon: Icon(Icons.data_object),
  //                       label: Text('Model'),
  //                     ),
  //                     NavigationRailDestination(
  //                       icon: Icon(Icons.api),
  //                       label: Text('API'),
  //                     ),
  //                     NavigationRailDestination(
  //                       icon: Icon(Icons.electric_bolt),
  //                       label: Text('Event'),
  //                     ),
  //                     NavigationRailDestination(
  //                       icon: Icon(Icons.view_kanban_outlined),
  //                       label: Text('Scrum'),
  //                     ),
  //                     NavigationRailDestination(
  //                       icon: Icon(Icons.code),
  //                       label: Text('Code'),
  //                     ),
  //                     NavigationRailDestination(
  //                       icon: Icon(Icons.document_scanner_outlined),
  //                       label: Text('Gen. Doc'),
  //                     ),
  //                     NavigationRailDestination(
  //                       icon: Icon(Icons.construction),
  //                       label: Text('Json tools'),
  //                     ),
  //                     NavigationRailDestination(
  //                       icon: Icon(Icons.check),
  //                       label: Badge.count(
  //                         count: 3,
  //                         child: Text('Validate\nRequest'),
  //                       ),
  //                     ),
  //                   ],
  //                   listTabCont: [
  //                     // child: NeumorphismBtn() // Stack(children: [Positioned(top: 100, left: 100, child: NeumorphismBtn())]),
  //                     getServiceTab(context),
  //                     Column(
  //                       children: [
  //                         getBreadcrumbModel(),
  //                         Expanded(child: _getModelTab()),
  //                       ],
  //                     ),
  //                     Column(
  //                       children: [
  //                         getBreadcrumbAPI(),
  //                         Expanded(child: _getApiTab()),
  //                       ],
  //                     ),
  //                     getEventTab(),
  //                     Container(),
  //                     getCodeTab(),
  //                     Container(),
  //                     //PanJsonBeautifier(),
  //                     Container(),
  //                   ],
  //                   heightTab: 20,
  //                 ),
  //               ),
  //             ),
  //           );
  //         },
  //       ),
  //     );
  //   }

  // Widget getBreadcrumbModel() {
  //   return SizedBox(
  //     height: 40,
  //     child: Align(
  //       alignment: Alignment.centerLeft,
  //       child: Row(
  //         children: [
  //           BreadCrumbNavigator(
  //             key: stateModel.keyBreadcrumb,
  //             getList: () {
  //               return stateModel.path;
  //             },
  //           ),
  //           Spacer(),
  //           Text('Open factor '),
  //           WidgetZoomSelector(zoom: openFactor),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // Widget _getApiTab() {
  //   var panAPISelector = PanAPISelector();

  //   return WidgetTab(
  //     key: stateApi.keyTab,
  //     tabDisable: stateApi.tabDisable,
  //     onInitController: (TabController tab) {
  //       stateApi.tabApi = tab;
  //       tab.addListener(() {
  //         if (tab.index == 0) {
  //           repaintManager.doRepaint(ChangeTag.showListApi);
  //         }
  //         if (tab.index == 1) {
  //           repaintManager.doRepaint(ChangeTag.apichange);
  //         }
  //       });
  //     },
  //     listTab: [
  //       Tab(text: 'API Browser'),
  //       Tab(text: 'API Detail'),
  //       getTabSeparator(Tab(text: 'Servers & Env.')),
  //       Tab(text: 'Validation workflow'),
  //       Tab(text: 'Trashcan'),
  //     ],
  //     listTabCont: [
  //       Column(
  //         children: [
  //           PanApiActionHub(selector: panAPISelector),
  //           Expanded(child: panAPISelector),
  //         ],
  //       ),
  //       KeepAliveWidget(child: PanApiEditor(key: keyAPIEditor)),
  //       PanApiEnv(),
  //       Container(),
  //       PanAPITrashcan(
  //         getModelFct: () async {
  //           var trash = ModelSchema(
  //             category: Category.allApi,
  //             headerName: 'All servers',
  //             id: 'api',
  //             infoManager: InfoManagerTrashAPI(),
  //           );
  //           trash.autoSaveProperties = false;

  //           await bddStorage.getTrashSupabase(trash, trash.id, 'trash');

  //           StringBuffer yamlTrash = StringBuffer();
  //           yamlTrash.writeln('trash:');
  //           for (var trashElem in trash.mapInfoByTreePath.entries) {
  //             yamlTrash.writeln(
  //               ' ${trashElem.value.masterID} : ${trashElem.value.path}',
  //             );
  //           }
  //           trash.mapInfoByTreePath.clear();
  //           // Swagger2Schema().import();
  //           // print(yamlTrash.toString());
  //           trash.mapModelYaml = loadYaml(yamlTrash.toString(), recover: true);

  //           return trash;
  //         },
  //       ),
  //     ],
  //     heightTab: 40,
  //   );
  // }

  // Widget getTabSeparator(Widget tab) {
  //   return Stack(
  //     fit: StackFit.loose,
  //     children: [
  //       Positioned(
  //         right: 0,
  //         top: 10,
  //         child: Container(
  //           height: 20,
  //           width: 1,
  //           decoration: BoxDecoration(
  //             border: Border(
  //               right: BorderSide(
  //                 color: Colors.white38,
  //                 width: 1,
  //                 style: BorderStyle.solid,
  //               ),
  //             ),
  //           ),
  //         ),
  //       ),
  //       Container(
  //         height: 40,
  //         padding: EdgeInsets.fromLTRB(0, 0, 40, 0),
  //         child: tab,
  //       ),
  //     ],
  //   );
  // }

  // Widget getEventTab() {
  //   return WidgetTab(
  //     listTab: [Tab(text: 'Avro'), Tab(text: 'Protobuf')],
  //     listTabCont: [Container(), Container()],
  //     heightTab: 40,
  //   );
  // }

  // Widget getCodeTab() {
  //   return WidgetTab(
  //     listTab: [Tab(text: 'DTO'), Tab(text: 'SQL'), Tab(text: 'Mongo')],
  //     listTabCont: [PanCodeGenerator(), Container(), Container()],
  //     heightTab: 40,
  //   );
  // }

  // Widget getServiceTab(BuildContext context) {
  //   return WidgetTab(
  //     listTab: [Tab(text: 'Graph'), Tab(text: 'Statistic')],
  //     listTabCont: [
  //       PanModelGraph(),
  //       Column(children: [Expanded(child: PanServiceInfo())]),
  //     ],
  //     heightTab: 40,
  //   );
  // }

  // Future<void> _dialogBuilder(BuildContext context) {
  //   return showDialog<void>(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         contentPadding: EdgeInsets.all(5),
  //         content: SizedBox(
  //           width: 500,
  //           height: 600,
  //           child: LoginScreen(email: 'toto@titit.com'),
  //         ),
  //       );
  //     },
  //   );
  // }

  // Widget _getModelTab() {
  //   return WidgetTab(
  //     key: stateModel.keyTab,
  //     onInitController: (TabController tab) {
  //       stateModel.tabModel = tab;
  //       tab.addListener(() {
  //         if (tab.index == 0) {
  //           stateModel.setTab();
  //         }
  //       });
  //     },
  //     tabDisable: stateModel.tabDisable,
  //     listTab: [
  //       Tab(text: 'Models Browser'),
  //       Tab(text: 'Model Editor'),
  //       getTabSeparator(Tab(text: 'Json schema')),
  //       Tab(text: 'Glossary'),
  //       Tab(text: 'Naming rules'),
  //       getTabSeparator(Tab(text: 'Validation workflow')),
  //       Tab(text: 'Trashcan'),
  //     ],
  //     listTabCont: [
  //       Column(
  //         children: [
  //           PanModelActionHub(),
  //           Expanded(child: KeepAliveWidget(child: WidgetModelMain())),
  //         ],
  //       ),
  //       KeepAliveWidget(
  //         child: WidgetModelEditor(key: stateModel.keyModelEditor),
  //       ),
  //       WidgetJsonValidator(),
  //       getGlossaryTab(),
  //       getNamingTab(),
  //       Container(),
  //       PanModelTrashcan(
  //         getModelFct: () async {
  //           var trash = ModelSchema(
  //             category: Category.allModel,
  //             headerName: 'All models',
  //             id: 'model',
  //             infoManager: InfoManagerTrashAPI(),
  //           );
  //           trash.autoSaveProperties = false;

  //           await bddStorage.getTrashSupabase(trash, 'model', 'trash model');

  //           StringBuffer yamlTrash = StringBuffer();
  //           yamlTrash.writeln('trash model:');
  //           for (var trashElem in trash.mapInfoByTreePath.entries) {
  //             yamlTrash.writeln(
  //               ' ${trashElem.value.masterID} : ${trashElem.value.path}',
  //             );
  //           }
  //           trash.mapInfoByTreePath.clear();

  //           await bddStorage.getTrashSupabase(
  //             trash,
  //             'component',
  //             'trash component',
  //           );

  //           yamlTrash.writeln('trash component:');
  //           for (var trashElem in trash.mapInfoByTreePath.entries) {
  //             yamlTrash.writeln(
  //               ' ${trashElem.value.masterID} : ${trashElem.value.path}',
  //             );
  //           }
  //           trash.mapInfoByTreePath.clear();

  //           await bddStorage.getTrashSupabase(
  //             trash,
  //             'request',
  //             'trash request',
  //           );

  //           yamlTrash.writeln('trash request:');
  //           for (var trashElem in trash.mapInfoByTreePath.entries) {
  //             yamlTrash.writeln(
  //               ' ${trashElem.value.masterID} : ${trashElem.value.path}',
  //             );
  //           }
  //           trash.mapInfoByTreePath.clear();

  //           trash.mapModelYaml = loadYaml(yamlTrash.toString(), recover: true);

  //           return trash;
  //         },
  //       ),
  //     ],
  //     heightTab: 40,
  //   );
  // }

  // Widget getGlossaryTab() {
  //   return WidgetTab(
  //     onInitController: (TabController tab) {},
  //     listTab: [
  //       Tab(text: 'Notion naming'),
  //       Tab(text: 'Available suffix & prefix'),
  //     ],
  //     listTabCont: [
  //       WidgetGlossary(
  //         schemaGlossary: currentCompany.listGlossary,
  //         typeModel: 'Notion Glossary',
  //       ),
  //       WidgetGlossary(
  //         schemaGlossary: currentCompany.listGlossarySuffixPrefix,
  //         typeModel: 'Suffix & prefix',
  //       ),
  //     ],
  //     heightTab: 40,
  //   );
  // }

  // Widget getNamingTab() {
  //   return WidgetTab(
  //     onInitController: (TabController tab) {},
  //     listTab: [
  //       Tab(text: 'Model'),
  //       Tab(text: 'API'),
  //       Tab(text: 'Event'),
  //       Tab(text: 'DB SQL'),
  //       Tab(text: 'DB Document'),
  //     ],
  //     listTabCont: [
  //       Container(),
  //       Container(),
  //       Container(),
  //       Container(),
  //       Container(),
  //     ],
  //     heightTab: 40,
  //   );
  // }

  // @override
  // Widget build(BuildContext context) {
  //   // TODO: implement build
  //   throw UnimplementedError();
  // }
}
