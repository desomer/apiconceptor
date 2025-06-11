import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/feature/api/pan_api_action_hub.dart';
import 'package:jsonschema/import/swagger2schema.dart';
import 'package:jsonschema/json_browser/browse_api.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/feature/model/pan_model_action_hub.dart';
import 'package:jsonschema/feature/api/pan_api_editor.dart';
import 'package:jsonschema/feature/model/pan_model_main.dart';
import 'package:jsonschema/widget/hexagon/hexagon_widget.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';
import 'package:jsonschema/widget/widget_global_zoom.dart';
import 'package:jsonschema/widget/widget_keep_alive.dart';
import 'package:jsonschema/feature/model/pan_model_json_validator.dart';
import 'package:jsonschema/feature/model/pan_model_editor.dart';
import 'package:jsonschema/widget/widget_rail.dart';
import 'package:jsonschema/widget/widget_tab.dart';
import 'package:jsonschema/widget/widget_zoom_selector.dart';
import 'package:jsonschema/widget_state/state_api.dart';
import 'package:jsonschema/widget_state/state_model.dart';
import 'package:jsonschema/widget_state/widget_md_doc.dart';

import 'feature/api/pan_api_selector.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const isRunningWithWasm = bool.fromEnvironment('dart.tool.dart2wasm');
  print('isRunningWithWasm $isRunningWithWasm');

  await bddStorage.init();

  currentCompany.listModel = await loadSchema(
    TypeMD.listmodel,
    'model',
    'Business model',
  );
  currentCompany.listComponent = await loadSchema(
    TypeMD.listmodel,
    'component',
    'Business component',
  );

  currentCompany.listRequest = await loadSchema(
    TypeMD.listmodel,
    'request',
    'Request',
  );

  currentCompany.listModel.dependency = [
    currentCompany.listComponent,
    currentCompany.listRequest,
  ];
  currentCompany.listComponent.dependency = [
    currentCompany.listModel,
    currentCompany.listRequest,
  ];
  currentCompany.listRequest.dependency = [
    currentCompany.listModel,
    currentCompany.listComponent,
  ];

  currentCompany.listAPI = ModelSchemaDetail(
    type: YamlType.allApi,
    name: 'All servers',
    id: 'api',
    infoManager: InfoManagerAPI(),
  );
  await currentCompany.listAPI.loadYamlAndProperties(cache: false);
  BrowseAPI().browse(currentCompany.listAPI, false);

  Swagger2Schema().import();

  runApp(CodeEditor());
}

Future<ModelSchemaDetail> loadSchema(
  TypeMD type,
  String id,
  String name,
) async {
  var m = ModelSchemaDetail(
    type: YamlType.allModel,
    name: name,
    id: id,
    infoManager: InfoManagerModel(typeMD: type),
  );
  await m.loadYamlAndProperties(cache: false);
  BrowseModel().browse(m, false);
  return m;
}

const constMasterID = '\$\$__id__';
const constTypeAnyof = '\$\$__anyof__';
const constRefOn = '\$\$__ref__';

final CompanyModelSchema currentCompany = CompanyModelSchema();

double scale = 0.9;
double rowHeight = 30 * scale;

ValueNotifier<String> notifierErrorYaml = ValueNotifier<String>('');

final ValueNotifier<double> openFactor = ValueNotifier(10);
WidgetZoomSelectorState? stateOpenFactor;
final ValueNotifier<int> zoom = ValueNotifier(100);

// ignore: must_be_immutable
class CodeEditor extends StatelessWidget {
  const CodeEditor({super.key});

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

          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale + 0.05),
              supportsShowingSystemContextMenu: true,
            ),
            child: Scaffold(
              bottomNavigationBar: Row(
                children: [
                  SizedBox(width: 10),
                  InkWell(child: Icon(Icons.undo)),
                  SizedBox(width: 5),
                  InkWell(child: Icon(Icons.redo)),
                  SizedBox(width: 5),
                  SizedBox(height: 20, child: WidgetGlobalZoom()),
                  Spacer(),
                  Text('API Architect by Desomer G. V0.1.0'),
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
                      icon: Icon(Icons.check),
                      label: Badge.count(
                        count: 3,
                        child: Text('Validate\nRequest'),
                      ),
                    ),
                  ],
                  listTabCont: [
                    // child: NeumorphismBtn() // Stack(children: [Positioned(top: 100, left: 100, child: NeumorphismBtn())]),
                    getServiceTab(),
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
      },
      listTab: [
        Tab(text: 'Browse API'),
        Tab(text: 'API Detail'),
        getTabSeparator(Tab(text: 'Servers & Env.')),
        Tab(text: 'Validation workflow'),
      ],
      listTabCont: [
        Column(
          children: [
            PanApiActionHub(selector: panAPISelector),
            Expanded(child: panAPISelector),
          ],
        ),
        PanApiEditor(),
        Container(),
        Container(),
      ],
      heightTab: 40,
    );
  }

  Widget getTabSeparator(Widget tab) {
    return Container(
      height: 40,
      padding: EdgeInsets.fromLTRB(0, 0, 40, 0),
      // decoration: BoxDecoration(
      //   border: Border(
      //     right: BorderSide(
      //       color: Colors.white38,
      //       width: 1,
      //       style: BorderStyle.solid,
      //     ),
      //   ),
      // ),
      child: tab,
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
      listTabCont: [Container(), Container(), Container()],
      heightTab: 40,
    );
  }

  Widget getServiceTab() {
    return Stack(
      children: [
        Positioned(
          top: 100,
          left: 150,
          child: HexagonWidget.pointy(
            width: 200,
            color: Colors.lightBlue,
            elevation: 8,
            child: Text('Business Domain'),
          ),
        ),

        Positioned(
          top: 100,
          left: 100,
          child: Card(
            elevation: 8,
            color: Colors.blue,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Application'),
            ),
          ),
        ),

        Positioned(
          top: 60,
          left: 40,
          child: Card(
            elevation: 8,
            color: Colors.grey,
            child: Padding(
              padding: EdgeInsets.all(15),
              child: Text('Input API'),
            ),
          ),
        ),

        Positioned(
          top: 55,
          left: 150,
          child: Card(
            elevation: 8,
            color: Colors.yellow,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('DTO', style: TextStyle(color: Colors.black)),
            ),
          ),
        ),

        Positioned(
          top: 150,
          left: 30,
          child: Card(
            elevation: 8,
            color: Colors.grey,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Input events'),
            ),
          ),
        ),

        Positioned(
          top: 130,
          left: 320,
          child: Card(
            elevation: 8,
            color: Colors.orange,
            child: Padding(padding: EdgeInsets.all(20), child: Text('MODELS')),
          ),
        ),

        Positioned(
          top: 100,
          left: 380,
          child: Card(
            elevation: 8,
            color: Colors.grey,
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Text('Life cycle'),
            ),
          ),
        ),

        Positioned(
          top: 180,
          left: 350,
          child: Card(
            elevation: 8,
            color: Colors.grey,
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Text('Mapping rule'),
            ),
          ),
        ),

        Positioned(
          top: 290,
          left: 260,
          child: Card(
            elevation: 8,
            color: Colors.blue,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Infrastructure'),
            ),
          ),
        ),

        Positioned(
          top: 340,
          left: 350,
          child: Card(
            elevation: 8,
            color: Colors.grey,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Output events'),
            ),
          ),
        ),

        Positioned(
          top: 270,
          left: 370,
          child: Card(
            elevation: 8,
            color: Colors.grey,
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Text('Output API'),
            ),
          ),
        ),

        Positioned(
          top: 340,
          left: 200,
          child: Card(
            elevation: 8,
            color: Colors.yellow,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'ORM ENTITIES',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ),
        ),
        Positioned(
          top: 400,
          left: 200,
          child: Card(
            elevation: 8,
            color: Colors.grey,
            child: Padding(padding: EdgeInsets.all(20), child: Text('BDD')),
          ),
        ),
      ],
    );
  }

  Widget _getModelTab() {
    return WidgetTab(
      key: stateModel.keyTab,
      onInitController: (TabController tab) {
        stateModel.tabModel = tab;
      },
      tabDisable: stateModel.tabDisable,
      listTab: [
        Tab(text: 'Browse Models'),
        Tab(text: 'Model Editor'),
        Tab(text: 'Json schema'),
        Tab(text: 'Glossary'),
        Tab(text: 'Naming rules'),
        Tab(text: 'Validation workflow'),
      ],
      listTabCont: [
        Column(
          children: [
            PanModelActionHub(),
            Expanded(child: KeepAliveWidget(child: WidgetModelMain())),
          ],
        ),
        WidgetModelEditor(),
        WidgetJsonValidator(),
        getGlossaryTab(),
        getNamingTab(),
        Container(),
      ],
      heightTab: 40,
    );
  }

  Widget getGlossaryTab() {
    return WidgetTab(
      onInitController: (TabController tab) {},
      listTab: [
        Tab(text: 'Notion naming'),
        Tab(text: 'Available suffix'),
        Tab(text: 'Available Prefix'),
      ],
      listTabCont: [Container(), Container(), Container()],
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
