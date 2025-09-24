import 'package:flutter/widgets.dart';
import 'package:jsonschema/feature/content/widget/widget_content_input.dart';

class StateManager {
  dynamic data;
  dynamic dataEmpty;

  Map<String, List<ConfigContainer>> configLayout = {};

  final Map<String, StateContainer> stateTemplate = {};
  final Map<String, StateContainer> statesTreeData = {};

  final Map<String, WidgetContentInputState> listInput = {};
  final Map<String, State> listContainer = {};

  void addControler(String pathData, WidgetContentInputState ctrl) {
    //print("addControler $pathData");
    listInput[pathData] = ctrl;
  }

  void removeControler(String pathData, WidgetContentInputState ctrl) {
    if (listInput[pathData] == ctrl) {
      print("removeControler $pathData");
      listInput.remove(pathData);
    }
  }

  void addContainer(String pathData, State widgetState) {
    //print("addContainer $pathData");    
    listContainer[pathData] = widgetState;
  }

  void removeContainer(String pathData) {
    listContainer.remove(pathData);
  }

  void clear() {
    data = null;
    statesTreeData.clear();

    for (var element in listContainer.entries) {
      if (element.value.mounted) {
      // ignore: invalid_use_of_protected_member
        element.value.setState(() {});
      }
    }
    for (var element in listInput.entries) {
      // ignore: invalid_use_of_protected_member
      element.value.ctrl.text = '';
    }
  }

  void dispose() {
    stateTemplate.clear();
    statesTreeData.clear();
    listInput.clear();
    listContainer.clear();
  }
}

class StateContainer {
  dynamic jsonTemplate;
  dynamic jsonData;
  String? currentTemplate;

  final Map<String, StateContainer> stateChild = {};

  void setData(dynamic data) {
    jsonData = data;
  }
}

class StateContainerObjectAny extends StateContainer {}

class StateContainerObject extends StateContainer {}

class StateContainerArray extends StateContainer {}

//--------------------------------------------------------------------------
class ConfigContainer {
  final int pos;
  final String name;
  final String layout;

  ConfigContainer({
    required this.pos,
    required this.name,
    required this.layout,
  });
}
