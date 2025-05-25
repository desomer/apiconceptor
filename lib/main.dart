import 'package:flutter/material.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/json_browser/browse_api.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/pan_api_editor.dart';
import 'package:jsonschema/pan_model_main.dart';
import 'package:jsonschema/widget/hexagon/hexagon_widget.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';
import 'package:jsonschema/widget/widget_keep_alive.dart';
import 'package:jsonschema/pan_json_validator.dart';
import 'package:jsonschema/pan_model_editor.dart';
import 'package:jsonschema/widget/widget_rail.dart';
import 'package:jsonschema/widget/widget_tab.dart';
import 'package:jsonschema/widget/widget_zoom_selector.dart';
import 'package:jsonschema/widget_state/state_api.dart';
import 'package:jsonschema/widget_state/state_model.dart';
import 'package:jsonschema/widget_state/widget_md_doc.dart';

import 'pan_api_selector.dart';

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
  currentCompany.listModel.dependency = [currentCompany.listComponent];
  currentCompany.listComponent.dependency = [currentCompany.listModel];

  currentCompany.listRequest = await loadSchema(
    TypeMD.listmodel,
    'request',
    'Request',
  );

  currentCompany.listAPI = ModelSchemaDetail(
    type: YamlType.allApi,
    name: 'All servers',
    id: 'api',
    infoManager: InfoManagerAPI(),
  );
  await currentCompany.listAPI.loadYamlAndProperties(cache: false);
  BrowseAPI().browse(currentCompany.listAPI, false);

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

const double rowHeight = 30;

ValueNotifier<String> notifierErrorYaml = ValueNotifier<String>('');

final ValueNotifier<double> zoom = ValueNotifier(0);

// ignore: must_be_immutable
class CodeEditor extends StatelessWidget {
  const CodeEditor({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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

      home: Scaffold(
        bottomNavigationBar: Row(
          children: [
            SizedBox(width: 10),
            InkWell(child: Icon(Icons.undo)),
            SizedBox(width: 5),
            InkWell(child: Icon(Icons.redo)),
            Spacer(),
            Text('API Architect by Desomer G. V0.0.4'),
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
            ],
            listTabCont: [
              // child: NeumorphismBtn() // Stack(children: [Positioned(top: 100, left: 100, child: NeumorphismBtn())]),
              getServiceTab(),
              Column(
                children: [
                  getBreadcrumbModel(),
                  Expanded(child: getModelTab()),
                ],
              ),
              Column(
                children: [getBreadcrumbAPI(), Expanded(child: getApiTab())],
              ),
              getEventTab(),
              Container(),
              getCodeTab(),
            ],
            heightTab: 20,
          ),
        ),
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
                //currentCompany.currentModel.name;
                return stateModel
                    .path; // ["Business Model", "Model", "0.0.1", "draft"];
              },
            ),
            Spacer(),
            WidgetZoomSelector(zoom: zoom),
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
            WidgetZoomSelector(zoom: zoom),
          ],
        ),
      ),
    );
  }

  Widget getApiTab() {
    return WidgetTab(
      key: stateApi.keyTab,
      tabDisable: stateApi.tabDisable,
      onInitController: (TabController tab) {
        stateApi.tabApi = tab;
      },
      listTab: [
        Tab(text: 'Browse API'),
        Tab(text: 'API Detail'),
        Tab(text: 'API Servers'),
        Tab(text: 'Validation workflow'),
      ],
      listTabCont: [PanAPISelector(), PanApiEditor(), Container(), Container()],
      heightTab: 40,
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
          top: 50,
          left: 50,
          child: Card(
            elevation: 8,
            color: Colors.grey,
            child: Padding(padding: EdgeInsets.all(20), child: Text('API')),
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
            child: Padding(padding: EdgeInsets.all(20), child: Text('EVENTS')),
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
            child: Padding(padding: EdgeInsets.all(20), child: Text('EVENTS')),
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
              child: Text('ENTITIES', style: TextStyle(color: Colors.black)),
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

  Widget getModelTab() {
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
        KeepAliveWidget(child: WidgetModelMain()),
        WidgetModelEditor(),
        WidgetJsonValidator(),
        Container(),
        Container(),
        Container(),
      ],
      heightTab: 40,
    );
  }
}
