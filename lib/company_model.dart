import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:animated_tree_view/tree_view/tree_node.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:yaml/yaml.dart';

class ModelSchema {
  ModelSchemaDetail? listModel;
  ModelSchemaDetail? currentModel;

  ModelSchemaDetail? listAPI;
}

enum ChangeOpe { change, rename, path, move, add, remove }

class ModelSchemaDetail {
  ModelSchemaDetail({
    required this.name,
    required this.id,
    required this.infoManager,
  });

  final String id;
  final String name;
  bool isLoadProp = false;
  String modelYaml = '';
  Map mapModelYaml = {};
  final InfoManager infoManager;

  Map<String, dynamic> modelProperties = {};
  List histories = [];

  Map<String, AttributInfo> mapInfoByJsonPath = {};
  Map<String, AttributInfo> mapInfoByTreePath = {};
  Map<String, List<AttributInfo>> mapInfoByName = {};
  Map<int, AttributInfo> allAttributInfo = {};

  List<AttributInfo> notUseAttributInfo = [];
  List<AttributInfo> useAttributInfo = [];
  int lastNbNode = 0;
  bool first = true;

  AttributInfo? currentAttr;

  void addHistory(
    String path,
    ChangeOpe ope,
    dynamic propChangeValue,
    dynamic value, {
    String? master,
  }) {
    if (histories.isNotEmpty) {
      var last = histories.last;
      if (last?['ope'] == ope.name && last?['path'] == path) {
        propChangeValue = last?['from'];
        histories.removeLast();
      }
    }

    histories.add({
      'ope': ope.name,
      'path': path,
      'from': _getMdValue(propChangeValue),
      'to': _getMdValue(value),
      'date': DateTime.now().toIso8601String(),
      'by': 'my',
      if (master != null) 'master': master,
    });
  }

  _getMdValue(dynamic v) {
    if (v.toString().contains('\n')) {
      return v.toString().replaceAll('\n', ';');
    }
    return v;
  }

  String getHistoryMarkdown() {
    StringBuffer ret = StringBuffer();
    ret.writeln('## Change log\n version 0.0.1\n');
    int i = 0;
    for (var h in histories) {
      var ope = h['ope'];
      dynamic from = h['from'];
      if (ope == ChangeOpe.change.name) {
        if (from == null || from.toString() == '') {
          ret.writeln(
            '* ${h['path']}   **SET**  ${h['to']}        *BY ${h['by']} **AT** ${h['date']}*',
          );
        } else {
          ret.writeln(
            '* ${h['path']}   **FROM**  $from  **TO**  ${h['to']}       *BY ${h['by']} **AT** ${h['date']}*',
          );
        }
      } else if (ope == ChangeOpe.path.name || ope == ChangeOpe.rename.name) {
        // String masterID = h['path'].toString();
        ret.writeln(
          '* **${ope.toString().toUpperCase()} FROM**  $from  **TO**  ${h['to']}       *BY ${h['by']} **AT** ${h['date']}*',
        );
      } else if (ope == ChangeOpe.move.name) {
        ret.writeln(
          '* ${h['path']}  **${ope.toString().toUpperCase()} FROM**  $from  **TO**  ${h['to']}        *BY ${h['by']} **AT** ${h['date']}*',
        );
      } else {
        // add et remove
        bool add = true;
        String masterID = h['path'].toString();
        if (ope == ChangeOpe.remove.name) {
          // recherche d'un move
          for (var j = i; j < histories.length; j++) {
            var o = histories[j];
            var opeOlder = o['ope'];
            if (opeOlder == ChangeOpe.move.name) {
              String oldmasterID = o['master'].toString();
              if (masterID == oldmasterID) {
                add = false;
                break;
              }
            }
          }
        }
        if (add) {
          ret.writeln(
            '* **${ope.toString().toUpperCase()}  ${h['from']}**     *BY ${h['by']} **AT** ${h['date']}*',
          );
        }
      }
      i++;
    }
    return ret.toString();
  }

  dynamic getItemSync(int delay) {
    return bddStorage.getItemSync(id, delay);
  }

  void reorgProperties(List<TreeNode<NodeAttribut>> all) {
    if (!first) {
      print("************* reorg & purge properties ****************");
      modelProperties.clear();
      for (var element in all) {
        if (element.data!.info.isInitByRef == false) {
          modelProperties[element.data!.info.path] =
              element.data!.info.properties;
        } else {
          //print("is attr on ref ${element.data!.info.path}");
        }
      }
    }
  }

  loadYamlAndProperties({required bool cache}) async {
    dynamic savedYamlModel = bddStorage.getItem(id, cache ? -1 : 0);
    if (savedYamlModel is Future) {
      savedYamlModel = await savedYamlModel;
    } else if (mapModelYaml.isNotEmpty) {
      return;
    }

    if (savedYamlModel != null) {
      modelYaml = savedYamlModel;
      try {
        mapModelYaml = loadYaml(modelYaml, recover: true);
        print("load yaml model = $id");
      } catch (e) {
        print(e);
      }
    } else {
      modelYaml = '';
      mapModelYaml = {};
    }

    await _loadProperties();
  }

  dynamic loadYamlAndPropertiesSyncOrNot({required bool cache}) {
    dynamic saveModel = bddStorage.getItem(id, cache ? -1 : 0);
    if (saveModel is Future) {
      return loadYamlAndProperties(cache: cache);
    } else {}

    if (saveModel != null) {
      modelYaml = saveModel;
      try {
        mapModelYaml = loadYaml(modelYaml, recover: true);
      } catch (e) {
        print(e);
      }
      _loadPropertiesSync();
    } else {
      modelYaml = '';
      mapModelYaml = {};
    }
    return saveModel;
  }

  Future<Map<String, dynamic>> getProperties() async {
    await _loadProperties();
    return modelProperties;
  }

  Future _loadProperties() async {
    if (!isLoadProp) {
      var l = await bddStorage.getItem('json/$id', 0);
      if (l != null) {
        modelProperties = jsonDecode(l);
      } else {
        modelProperties = {};
      }

      print("load properties model = $id");
      isLoadProp = true;
    }
  }

  dynamic _loadPropertiesSync() {
    if (!isLoadProp) {
      var l = bddStorage.getItem('json/$id', -1);
      if (l is! Future) {
        if (l != null) {
          modelProperties = jsonDecode(l);
        } else {
          modelProperties = {};
        }
        print("load properties model = $id");
        isLoadProp = true;
      }
    }
  }

  void saveProperties() {
    var jsonEncode2 = jsonEncode(modelProperties);
    print(jsonEncode2);
    bddStorage.setItem('json/$id', jsonEncode2);
  }
}
