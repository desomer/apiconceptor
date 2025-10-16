import 'package:flutter/widgets.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/content/widget/widget_content_input.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';

class StateManager {
  dynamic data;
  dynamic dataEmpty;

  Map<String, List<ConfigFormContainer>> configLayout = {};
  Map<String, ConfigArrayContainer> configArray = {};

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

  Map storeConfigLayout(ModelSchema model) {
    var res = {};
    for (var element in configLayout.entries) {
      res['${element.key}@form_v1'] =
          (element.value).map((e) {
            return {
              'pos': e.pos,
              'name': e.name,
              'layout': e.layout,
              'height': e.height,
            };
          }).toList();
    }
    for (var element in configArray.entries) {
      res['${element.key}@array_v1'] = {
        'listOfForm': element.value.listOfForm,
        'listOfRow': element.value.listOfRow,
        'nbRowPerPage': element.value.nbRowPerPage,
        'detailInDialog': element.value.detailInDialog,
        'detailInNested': element.value.detailInNested,
        'detailInBottom': element.value.detailInBottom,
      };
    }

    var accessor = _getUiConfigLayoutAccessor(model);
    accessor.set(res);

    return res;
  }

  ModelAccessorAttr _getUiConfigLayoutAccessor(ModelSchema model) {
    var n = model.getExtendedNode('#uiConfigLayout');
    var access = ModelAccessorAttr(
      node: n,
      schema: model,
      propName: '#uiConfigLayout',
    );
    return access;
  }

  void loadJSonConfigLayout(ModelSchema model) {
    var accessor = _getUiConfigLayoutAccessor(model);
    Map? json = accessor.get();

    if (json != null) {
      configLayout.clear();
      for (var element in json.entries) {
        var key = element.key.toString();
        int i = key.indexOf('@');
        if (i >= 0) {
          key = key.substring(0, i);
        }
        if (element.key.toString().endsWith('@array_v1')) {
          var cfg = ConfigArrayContainer(name: key);
          var val = element.value;
          if (val is Map) {
            cfg.listOfForm = val['listOfForm'] ?? true;
            cfg.listOfRow = val['listOfRow'] ?? false;
            cfg.nbRowPerPage = val['nbRowPerPage'] ?? -1;
            cfg.detailInDialog = val['detailInDialog'] ?? false;
            cfg.detailInNested = val['detailInNested'] ?? false;
            cfg.detailInBottom = val['detailInBottom'] ?? false;
          }
          configArray[key] = cfg;
        } else {
          List<ConfigFormContainer> lst = [];
          for (var item in element.value) {
            lst.add(
              ConfigFormContainer(
                height: item['height'] ?? -1,
                pos: item['pos'],
                name: item['name'],
                layout: item['layout'],
              ),
            );
          }
          configLayout[key] = lst;
        }
      }
    }
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
  final String name;

  ConfigContainer({required this.name});
}

class ConfigArrayContainer extends ConfigContainer {
  bool listOfForm = true;
  bool listOfRow = false;
  int nbRowPerPage = -1;
  bool detailInDialog = false;
  bool detailInNested = false;
  bool detailInBottom = false;

  ConfigArrayContainer({required super.name});
}

class ConfigFormContainer extends ConfigContainer {
  final int pos;
  final String layout;
  final int height;

  ConfigFormContainer({
    required this.height,
    required this.pos,
    required this.layout,
    required super.name,
  });
}
