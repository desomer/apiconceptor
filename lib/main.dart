import 'package:flutter/material.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/keepAlive.dart';
import 'package:jsonschema/widget_model_editor.dart';
import 'package:jsonschema/widget_model_selector.dart';
import 'package:jsonschema/widget_rail.dart';
import 'package:jsonschema/widget_tab.dart';
import 'package:localstorage/localstorage.dart';
import 'package:yaml/yaml.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initLocalStorage();
  currentCompany.listModel = ModelSchemaDetail(name: 'Business model', id: 'model');

  var listModel = localStorage.getItem('model');
  if (listModel != null) {
    currentCompany.listModelYaml = listModel;
    try {
      currentCompany.mapListModelYaml = loadYaml(
        currentCompany.listModelYaml,
        recover: true,
      );
    } catch (e) {}
  }

  runApp(CodeEditor());
}

const constMasterID = '\$\$__id__';
const constTypeOneof = '\$\$__oneof__';
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
            ],
            listTabCont: [getModelTab(), Container(), Container()],
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
        Tab(text: 'Glossary'),
      ],
      listTabCont: [
        KeepAliveWidget(child: WidgetModelSelector()),
        WidgetModelEditor(),
        Container(),
      ],
      heightTab: 40,
    );
  }







}
