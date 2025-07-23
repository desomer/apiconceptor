import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/repaint_manager.dart';
import 'package:jsonschema/feature/api/pan_api_action_hub.dart';
import 'package:jsonschema/feature/api/pan_api_trashcan.dart';
import 'package:jsonschema/feature/code/pan_code_generator.dart';
import 'package:jsonschema/feature/model/pan_model_trashcan.dart';
import 'package:jsonschema/feature/glossary/pan_glossary.dart';
import 'package:jsonschema/feature/graph/pan_service_info.dart';
import 'package:jsonschema/feature/graph/pan_spring_graph.dart';
import 'package:jsonschema/json_browser/browse_api.dart';
import 'package:jsonschema/json_browser/browse_glossary.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/feature/model/pan_model_action_hub.dart';
import 'package:jsonschema/feature/api/pan_api_editor.dart';
import 'package:jsonschema/feature/model/pan_model_main.dart';
import 'package:jsonschema/widget/login/login_screen.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';
import 'package:jsonschema/widget/widget_global_zoom.dart';
import 'package:jsonschema/widget/widget_keep_alive.dart';
import 'package:jsonschema/feature/model/pan_model_json_validator.dart';
import 'package:jsonschema/feature/model/pan_model_editor.dart';
import 'package:jsonschema/widget/widget_rail.dart';
import 'package:jsonschema/widget/widget_show_error.dart';
import 'package:jsonschema/widget/widget_tab.dart';
import 'package:jsonschema/widget/widget_zoom_selector.dart';
import 'package:jsonschema/widget_state/state_api.dart';
import 'package:jsonschema/widget_state/state_model.dart';
import 'package:jsonschema/widget_state/widget_md_doc.dart';
import 'package:yaml/yaml.dart';

import 'feature/api/pan_api_selector.dart';

bool withBdd = true;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const isRunningWithWasm = bool.fromEnvironment('dart.tool.dart2wasm');
  print('isRunningWithWasm $isRunningWithWasm');

  if (!withBdd) {
    startError.add('no bdd');
  } else {
    try {
      await bddStorage.init();
    } on Exception catch (e) {
      print("$e");
      startError.add("$e");
    }
  }

  currentCompany.listModel = await loadSchema(
    TypeMD.listmodel,
    'model',
    'Business models',
    TypeModelBreadcrumb.businessmodel,
  );
  currentCompany.listComponent = await loadSchema(
    TypeMD.listmodel,
    'component',
    'Business components',
    TypeModelBreadcrumb.component,
  );

  currentCompany.listRequest = await loadSchema(
    TypeMD.listmodel,
    'request',
    'Requests & responses',
    TypeModelBreadcrumb.request,
  );

  currentCompany.listModel.dependency.addAll([
    currentCompany.listComponent,
    currentCompany.listRequest,
  ]);
  currentCompany.listComponent.dependency.addAll([
    currentCompany.listModel,
    currentCompany.listRequest,
  ]);
  currentCompany.listRequest.dependency.addAll([
    currentCompany.listModel,
    currentCompany.listComponent,
  ]);

  currentCompany.listAPI = ModelSchema(
    category: Category.allApi,
    headerName: 'All servers',
    id: 'api',
    infoManager: InfoManagerAPI(),
  );

  if (withBdd) {
    try {
      await currentCompany.listAPI.loadYamlAndProperties(
        cache: false,
        withProperties: true,
      );
      BrowseAPI().browse(currentCompany.listAPI, false);
    } on Exception catch (e) {
      print("$e");
      startError.add("$e");
    }
  }

  currentCompany.listGlossary = await loadGlossary('glossary', 'Glossary');
  currentCompany.listGlossarySuffixPrefix = await loadGlossary(
    'glossarySufPre',
    'Suffix & Prefix',
  );

  runApp(ApiArchitecEditor());
}

Future<ModelSchema> loadGlossary(String id, String name) async {
  var schema = ModelSchema(
    category: Category.allGlossary,
    headerName: name,
    id: id,
    infoManager: InfoManagerGlossary(),
  );

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

Future<ModelSchema> loadSchema(
  TypeMD type,
  String id,
  String name,
  TypeModelBreadcrumb typeBread,
) async {
  var m = ModelSchema(
    category: Category.allModel,
    headerName: name,
    id: id,
    infoManager: InfoManagerModel(typeMD: type),
  );
  m.typeBreabcrumb = typeBread;
  if (withBdd) {
    try {
      await m.loadYamlAndProperties(cache: false, withProperties: true);
      BrowseModel().browse(m, false);
    } on Exception catch (e) {
      print('$e');
      startError.add("$e");
    }
  }
  return m;
}

const constMasterID = '\$\$__id__';
const constTypeAnyof = '\$\$__anyof__';
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

GlobalKey keyAPIEditor = GlobalKey();

// ignore: must_be_immutable
class ApiArchitecEditor extends StatelessWidget {
  ApiArchitecEditor({super.key});
  bool showLoginDialog = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: [
        FleatherLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color.fromRGBO(86, 80, 14, 171),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blueGrey,
      ),
      themeMode: ThemeMode.dark,

      home: ValueListenableBuilder(
        valueListenable: zoom,
        builder: (context, value, child) {
          scale = (zoom.value - 5) / 100.0;
          rowHeight = 30 * scale;

          if (showLoginDialog) {
            showLoginDialog = false;
            Future.delayed(Duration(milliseconds: 200)).then((value) {
              // ignore: use_build_context_synchronously
              _dialogBuilder(context);
            });
          }

          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale + 0.05),
              supportsShowingSystemContextMenu: true,
            ),
            child: Scaffold(
              bottomNavigationBar: Row(
                children: [
                  WidgetShowError(),
                  SizedBox(width: 10),
                  InkWell(child: Icon(Icons.undo)),
                  SizedBox(width: 5),
                  InkWell(child: Icon(Icons.redo)),
                  SizedBox(width: 5),
                  SizedBox(height: 20, child: WidgetGlobalZoom()),
                  Spacer(),
                  Text('API Architect by Desomer G. V0.2.2'),
                ],
              ),
              body: SafeArea(
                child: WidgetRail(
                  listTab: [
                    NavigationRailDestination(
                      icon: Icon(Icons.design_services),
                      label: Text('Service'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.data_object),
                      label: Text('Model'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.api),
                      label: Text('API'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.electric_bolt),
                      label: Text('Event'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.view_kanban_outlined),
                      label: Text('Scrum'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.code),
                      label: Text('Code'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.document_scanner_outlined),
                      label: Text('Gen. Doc'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.construction),
                      label: Text('Json tools'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.check),
                      label: Badge.count(
                        count: 3,
                        child: Text('Validate\nRequest'),
                      ),
                    ),
                  ],
                  listTabCont: [
                    // child: NeumorphismBtn() // Stack(children: [Positioned(top: 100, left: 100, child: NeumorphismBtn())]),
                    getServiceTab(context),
                    Column(
                      children: [
                        getBreadcrumbModel(),
                        Expanded(child: _getModelTab()),
                      ],
                    ),
                    Column(
                      children: [
                        getBreadcrumbAPI(),
                        Expanded(child: _getApiTab()),
                      ],
                    ),
                    getEventTab(),
                    Container(),
                    getCodeTab(),
                    Container(),
                    //PanJsonBeautifier(),
                    Container(),
                  ],
                  heightTab: 20,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget getBreadcrumbModel() {
    return SizedBox(
      height: 40,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            BreadCrumbNavigator(
              key: stateModel.keyBreadcrumb,
              getList: () {
                return stateModel.path;
              },
            ),
            Spacer(),
            Text('Open factor '),
            WidgetZoomSelector(zoom: openFactor),
          ],
        ),
      ),
    );
  }

  Widget getBreadcrumbAPI() {
    return SizedBox(
      height: 40,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            BreadCrumbNavigator(
              key: stateApi.keyBreadcrumb,
              getList: () {
                return stateApi.path;
              },
            ),
            Spacer(),
            Text('Open factor '),
            WidgetZoomSelector(zoom: openFactor),
          ],
        ),
      ),
    );
  }

  Widget _getApiTab() {
    var panAPISelector = PanAPISelector();

    return WidgetTab(
      key: stateApi.keyTab,
      tabDisable: stateApi.tabDisable,
      onInitController: (TabController tab) {
        stateApi.tabApi = tab;
        tab.addListener(() {
          if (tab.index == 0) {
            repaintManager.doRepaint(ChangeTag.showListApi);
          }
          if (tab.index == 1) {
            repaintManager.doRepaint(ChangeTag.apichange);
          }
        });
      },
      listTab: [
        Tab(text: 'Browse API'),
        Tab(text: 'API Detail'),
        getTabSeparator(Tab(text: 'Servers & Env.')),
        Tab(text: 'Validation workflow'),
        Tab(text: 'Trashcan'),
      ],
      listTabCont: [
        Column(
          children: [
            PanApiActionHub(selector: panAPISelector),
            Expanded(child: panAPISelector),
          ],
        ),
        KeepAliveWidget(child: PanApiEditor(key: keyAPIEditor)),
        Container(),
        Container(),
        PanAPITrashcan(
          getModelFct: () async {
            var trash = ModelSchema(
              category: Category.allApi,
              headerName: 'All servers',
              id: 'api',
              infoManager: InfoManagerTrashAPI(),
            );
            trash.autoSaveProperties = false;

            await bddStorage.getTrashSupabase(trash, trash.id, 'trash');

            StringBuffer yamlTrash = StringBuffer();
            yamlTrash.writeln('trash:');
            for (var trashElem in trash.mapInfoByTreePath.entries) {
              yamlTrash.writeln(
                ' ${trashElem.value.masterID} : ${trashElem.value.path}',
              );
            }
            trash.mapInfoByTreePath.clear();
            // Swagger2Schema().import();
            // print(yamlTrash.toString());
            trash.mapModelYaml = loadYaml(yamlTrash.toString(), recover: true);

            return trash;
          },
        ),
      ],
      heightTab: 40,
    );
  }

  Widget getTabSeparator(Widget tab) {
    return Stack(
      fit: StackFit.loose,
      children: [
        Positioned(
          right: 0,
          top: 10,
          child: Container(
            height: 20,
            width: 1,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: Colors.white38,
                  width: 1,
                  style: BorderStyle.solid,
                ),
              ),
            ),
          ),
        ),
        Container(
          height: 40,
          padding: EdgeInsets.fromLTRB(0, 0, 40, 0),
          child: tab,
        ),
      ],
    );
  }

  Widget getEventTab() {
    return WidgetTab(
      listTab: [Tab(text: 'Avro'), Tab(text: 'Protobuf')],
      listTabCont: [Container(), Container()],
      heightTab: 40,
    );
  }

  Widget getCodeTab() {
    return WidgetTab(
      listTab: [Tab(text: 'DTO'), Tab(text: 'SQL'), Tab(text: 'Mongo')],
      listTabCont: [PanCodeGenerator(), Container(), Container()],
      heightTab: 40,
    );
  }

  Widget getServiceTab(BuildContext context) {
    return WidgetTab(
      listTab: [Tab(text: 'Graph'), Tab(text: 'Statistic')],
      listTabCont: [
        PanModelGraph(),
        Column(children: [Expanded(child: PanServiceInfo())]),
      ],
      heightTab: 40,
    );
  }

  Future<void> _dialogBuilder(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding: EdgeInsets.all(5),
          content: SizedBox(
            width: 500,
            height: 600,
            child: LoginScreen(email: 'toto@titit.com'),
          ),
        );
      },
    );
  }

  Widget _getModelTab() {
    return WidgetTab(
      key: stateModel.keyTab,
      onInitController: (TabController tab) {
        stateModel.tabModel = tab;
        tab.addListener(() {
          if (tab.index == 0) {
            stateModel.setTab();
          }
        });
      },
      tabDisable: stateModel.tabDisable,
      listTab: [
        Tab(text: 'Browse Models'),
        Tab(text: 'Model Editor'),
        getTabSeparator(Tab(text: 'Json schema')),
        Tab(text: 'Glossary'),
        Tab(text: 'Naming rules'),
        getTabSeparator(Tab(text: 'Validation workflow')),
        Tab(text: 'Trashcan'),
      ],
      listTabCont: [
        Column(
          children: [
            PanModelActionHub(),
            Expanded(child: KeepAliveWidget(child: WidgetModelMain())),
          ],
        ),
        KeepAliveWidget(
          child: WidgetModelEditor(key: stateModel.keyModelEditor),
        ),
        WidgetJsonValidator(),
        getGlossaryTab(),
        getNamingTab(),
        Container(),
        PanModelTrashcan(
          getModelFct: () async {
            var trash = ModelSchema(
              category: Category.allModel,
              headerName: 'All models',
              id: 'model',
              infoManager: InfoManagerTrashAPI(),
            );
            trash.autoSaveProperties = false;

            await bddStorage.getTrashSupabase(trash, 'model', 'trash model');

            StringBuffer yamlTrash = StringBuffer();
            yamlTrash.writeln('trash model:');
            for (var trashElem in trash.mapInfoByTreePath.entries) {
              yamlTrash.writeln(
                ' ${trashElem.value.masterID} : ${trashElem.value.path}',
              );
            }
            trash.mapInfoByTreePath.clear();

            await bddStorage.getTrashSupabase(
              trash,
              'component',
              'trash component',
            );

            yamlTrash.writeln('trash component:');
            for (var trashElem in trash.mapInfoByTreePath.entries) {
              yamlTrash.writeln(
                ' ${trashElem.value.masterID} : ${trashElem.value.path}',
              );
            }
            trash.mapInfoByTreePath.clear();

            await bddStorage.getTrashSupabase(
              trash,
              'request',
              'trash request',
            );

            yamlTrash.writeln('trash request:');
            for (var trashElem in trash.mapInfoByTreePath.entries) {
              yamlTrash.writeln(
                ' ${trashElem.value.masterID} : ${trashElem.value.path}',
              );
            }
            trash.mapInfoByTreePath.clear();

            trash.mapModelYaml = loadYaml(yamlTrash.toString(), recover: true);

            return trash;
          },
        ),
      ],
      heightTab: 40,
    );
  }

  Widget getGlossaryTab() {
    return WidgetTab(
      onInitController: (TabController tab) {},
      listTab: [
        Tab(text: 'Notion naming'),
        Tab(text: 'Available suffix & prefix'),
      ],
      listTabCont: [
        WidgetGlossary(
          schemaGlossary: currentCompany.listGlossary,
          typeModel: 'Notion Glossary',
        ),
        WidgetGlossary(
          schemaGlossary: currentCompany.listGlossarySuffixPrefix,
          typeModel: 'Suffix & prefix',
        ),
      ],
      heightTab: 40,
    );
  }

  Widget getNamingTab() {
    return WidgetTab(
      onInitController: (TabController tab) {},
      listTab: [
        Tab(text: 'Model'),
        Tab(text: 'API'),
        Tab(text: 'Event'),
        Tab(text: 'DB SQL'),
        Tab(text: 'DB Document'),
      ],
      listTabCont: [
        Container(),
        Container(),
        Container(),
        Container(),
        Container(),
      ],
      heightTab: 40,
    );
  }
}
