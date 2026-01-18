import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/content/pan_browser.dart';
import 'package:jsonschema/feature/content/widget/widget_content_input.dart';
import 'package:jsonschema/feature/transform/pan_response_viewer.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';

class StateManagerUI extends StateManager {
  dynamic jsonUI;
  ConfigBlock? config;
  BrowserPan browser = BrowserPan();
  Map<String, List<ConfigFormContainer>> configLayout = {};
  Map<String, ConfigArrayContainer> configArray = {};

  // container des templates (plus utile... remplacer par le PanInfo)
  final Map<String, StateContainer> stateTemplate = {};

  @override
  void dispose() {
    stateTemplate.clear();
    super.dispose();
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

class StateManager {
  dynamic data;
  dynamic dataEmpty;

  // les container de data
  final Map<String, StateContainer> statesTreeData = {};
  // liste des input controleur actif
  final Map<String, List<WidgetBindJsonState>> listInputByPath = {};
  final Map<String, List<State>> listContainerByPath = {};

  final Map<String, Map<String, State>> listDepsContainerByPath = {};

  // pathData de type /objet/child1/child2 or /array[0]/child1/child2

  void loadDataInContainer(dynamic json, {String pathData = ''}) {
    if (json is Map) {
      _addStateTreeData(pathData, StateContainerObject()..jsonData = json);
      json.forEach((key, value) {
        final currentPath = '$pathData/$key';
        loadDataInContainer(value, pathData: currentPath);
      });
      _doReloadContainer(pathData);
    } else if (json is List) {
      _addStateTreeData(pathData, StateContainerArray()..jsonData = json);
      for (int i = 0; i < json.length; i++) {
        final currentPath = '$pathData[$i]';
        loadDataInContainer(json[i], pathData: currentPath);
      }
      _doReloadContainer(pathData);
    } else {
      // Valeur primitive
      _initInputControleur(pathData, json, 0);
    }
  }

  void _addStateTreeData(String pathData, StateContainer container) {
    //print('==>> addStateTreeData $pathData ${container.hashCode}');
    var p = pathData.split('/');
    StateContainer? last;
    if (p.length == 1) {
      statesTreeData[""] = container;
      return;
    }
    last = statesTreeData[""];
    for (var i = 1; i < p.length - 1; i++) {
      last = last!.stateChild[p[i]];
    }
    last!.stateChild[p[p.length - 1]] = container;
  }

  void _doReloadContainer(String pathData) {
    var containerState = listContainerByPath[pathData];
    for (var state in containerState ?? const []) {
      //print("check reload container ${element.key} for $pathData");
      if (state?.mounted ?? false) {
        // ignore: invalid_use_of_protected_member
        state!.setState(() {});
      }
    }
  }

  void _initInputControleur(String pathData, var json, int antiLoop) {
    if (antiLoop > 3) {
      //print("********** no visible pathData: $pathData $antiLoop");
      return;
    }

    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      try {
        var stateInput = listInputByPath[pathData];
        for (WidgetBindJsonState state in stateInput ?? const []) {
          if (state.mounted) {
            state.setBindJsonValue(json);
            if (antiLoop > 0) {
              // print("load pathData: $pathData $antiLoop > $json");
            }
          } else {
            // print("no visible pathData: $pathData $antiLoop > $json");
            antiLoop++;

            _initInputControleur(pathData, json, antiLoop);
          }
        }
      } catch (e) {
        print("erreur pathData: $pathData => $e");
      }
    });
  }

  void registerInput(String pathData, WidgetBindJsonState ctrl) {
    var list = listInputByPath[pathData];
    if (list == null) {
      list = [];
      listInputByPath[pathData] = list;
    }
    list.add(ctrl);
  }

  void disposeInput(String pathData, WidgetBindJsonState ctrl) {
    var list = listInputByPath[pathData];
    list?.removeWhere((role) => role == ctrl);
    if (list != null && list.isEmpty) {
      listInputByPath.remove(pathData);
    }
  }

  void registerContainer(String pathData, State widgetState) {
    var list = listContainerByPath[pathData];
    if (list == null) {
      list = [];
      listContainerByPath[pathData] = list;
    }
    list.add(widgetState);
    //print("addContainer $pathData");
  }

  void disposeContainer(String pathData, State widgetState) {
    var list = listContainerByPath[pathData];
    list?.removeWhere((role) => role == widgetState);
    if (list != null && list.isEmpty) {
      listContainerByPath.remove(pathData);
    }
  }

  void clearDisplayedData() {
    data = null;
    statesTreeData.clear();

    for (var c in listContainerByPath.entries) {
      for (var element in c.value) {
        if (element.mounted) {
          // ignore: invalid_use_of_protected_member
          element.setState(() {});
        }
      }
    }
    for (var i in listInputByPath.entries) {
      for (var element in i.value) {
        element.setBindJsonValue("");
      }
    }
  }

  void dispose() {
    statesTreeData.clear();
    listInputByPath.clear();
    listContainerByPath.clear();
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

class StateContainerArray extends StateContainer {
  int currentIndex = 0;
}

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
