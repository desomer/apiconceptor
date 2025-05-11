import 'package:flutter/material.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/json_browser/browse_api.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/pan_api_editor.dart';
import 'package:jsonschema/widget/hexagon/hexagon_widget.dart';
import 'package:jsonschema/widget/widget_keep_alive.dart';
import 'package:jsonschema/pan_json_validator.dart';
import 'package:jsonschema/pan_model_editor.dart';
import 'package:jsonschema/pan_model_selector.dart';
import 'package:jsonschema/widget/widget_rail.dart';
import 'package:jsonschema/widget/widget_tab.dart';

import 'pan_api_selector.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const isRunningWithWasm = bool.fromEnvironment('dart.tool.dart2wasm');
  print('isRunningWithWasm $isRunningWithWasm');

  await bddStorage.init();

  currentCompany.listModel = ModelSchemaDetail(
    name: 'Business model',
    id: 'model',
    infoManager: InfoManagerModel(),
  );
  await currentCompany.listModel!.loadYamlAndProperties(cache: false);
  BrowseModel().browse(currentCompany.listModel!, false);

  currentCompany.listAPI = ModelSchemaDetail(
    name: 'API',
    id: 'api',
    infoManager: InfoManagerAPI(),
  );
  await currentCompany.listAPI!.loadYamlAndProperties(cache: false);
  BrowseAPI().browse(currentCompany.listAPI!, false);

  runApp(CodeEditor());
}

const constMasterID = '\$\$__id__';
const constTypeAnyof = '\$\$__anyof__';
const constRefOn = '\$\$__ref__';

GlobalKey keyListModel = GlobalKey();
GlobalKey keyListModelInfo = GlobalKey();
GlobalKey keyModelEditor = GlobalKey();
GlobalKey keyModelInfo = GlobalKey();
late TabController tabModel;
late TabController tabAPI;

GlobalKey keyListAPI = GlobalKey();
GlobalKey keyListAPIInfo = GlobalKey();

final ModelSchema currentCompany = ModelSchema();

const double rowHeight = 30;

ValueNotifier<String> notifierErrorYaml = ValueNotifier<String>('');
ValueNotifier<String> notifierModelErrorYaml = ValueNotifier<String>('');

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
          children: [Spacer(), Text('API Architect by Desomer G. V0.0.2')],
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
              getModelTab(),
              getApiTab(),
              Container(),
              Container(),
              getCodeTab(),
            ],
            heightTab: 20,
          ),
        ),
      ),
    );
  }

  Widget getApiTab() {
    return WidgetTab(
      onInitController: (TabController tab) {
        tabAPI = tab;
      },
      listTab: [
        Tab(text: 'Browse API'),
        Tab(text: 'Edit route API'),
        Tab(text: 'API Servers'),
      ],
      listTabCont: [PanAPISelector(), PanApiEditor(), Container()],
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
    return Container(
      child: Stack(
        children: [
          Positioned(
            top: 100,
            left: 100,
            child: HexagonWidget.pointy(
              width: 200,
              color: Colors.lightBlue,
              elevation: 8,
              child: Text('Business Domain'),
            ),
          ),

          Positioned(
            top: 70,
            left: 70,
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
            top: 290,
            left: 220,
            child: Card(
              elevation: 8,
              color: Colors.blue,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Infrastructure'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget getModelTab() {
    return WidgetTab(
      onInitController: (TabController tab) {
        tabModel = tab;
      },
      listTab: [
        Tab(text: 'Models Browser'),
        Tab(text: 'Model Editor'),
        Tab(text: 'Json schema'),
        Tab(text: 'Glossary'),
        Tab(text: 'Naming rules'),
      ],
      listTabCont: [
        KeepAliveWidget(child: WidgetModelSelector()),
        WidgetModelEditor(),
        WidgetJsonValidator(),
        Container(),
        Container(),
      ],
      heightTab: 40,
    );
  }
}
