import 'package:flutter/material.dart';
import 'package:jsonschema/bdd/data_acces.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/keepAlive.dart';
import 'package:jsonschema/widget_json_validator.dart';
import 'package:jsonschema/widget_model_editor.dart';
import 'package:jsonschema/widget_model_selector.dart';
import 'package:jsonschema/widget_rail.dart';
import 'package:jsonschema/widget_tab.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const isRunningWithWasm = bool.fromEnvironment('dart.tool.dart2wasm');
  print('isRunningWithWasm $isRunningWithWasm');

  await localStorage.init();

  currentCompany.listModel = ModelSchemaDetail(
    name: 'Business model',
    id: 'model',
  );

  await currentCompany.listModel!.loadYamlAndProperties(cache: false);

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

final ModelSchema currentCompany = ModelSchema();

const double rowHeight = 35;

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
        body: SafeArea(
          child: WidgetRail(
            listTab: [
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
                icon: Icon(Icons.code),
                label: Text('Code'),
              ),              
            ],
            listTabCont: [getModelTab(), Container(), Container(), Container()],
            heightTab: 20,
          ),
        ),
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
      ],
      listTabCont: [
        KeepAliveWidget(child: WidgetModelSelector()),
        WidgetModelEditor(),
        WidgetJsonValidator(),
        Container(),
      ],
      heightTab: 40,
    );
  }
}
