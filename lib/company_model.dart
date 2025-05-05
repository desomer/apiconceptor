import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:jsonschema/bdd/data_acces.dart';
import 'package:jsonschema/export/json_browser.dart';
import 'package:yaml/yaml.dart';

class ModelSchema {
  ModelSchemaDetail? listModel;
  ModelSchemaDetail? currentModel;
}

class ModelSchemaDetail {
  ModelSchemaDetail({required this.name, required this.id});

  final String id;
  final String name;
  bool isLoadProp = false;
  String modelYaml = '';
  Map mapModelYaml = {};

  Map<String, dynamic> modelProperties = {};

  Map<String, AttributInfo> mapInfoByJsonPath = {};
  Map<String, AttributInfo> mapInfoByTreePath = {};
  Map<String, List<AttributInfo>> mapInfoByName = {};
  Map<int, AttributInfo> allAttributInfo = {};

  List<AttributInfo> notUseAttributInfo = [];
  int lastNbNode = 0;
  bool first = true;

  AttributInfo? currentAttr;

  dynamic getItemSync(int delay) {
    return localStorage.getItemSync(id, delay);
  }

  loadYamlAndProperties({required bool cache}) async {
    dynamic saveModel = localStorage.getItem(id, cache ? -1 : 0);
    if (saveModel is Future) {
      saveModel = await saveModel;
    } else if (mapModelYaml.isNotEmpty) {
      return;
    }

    if (saveModel != null) {
      modelYaml = saveModel;
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
    dynamic saveModel = localStorage.getItem(id, cache ? -1 : 0);
    if (saveModel is Future) {
      return loadYamlAndProperties(cache: cache);
    }

    if (saveModel != null) {
      modelYaml = saveModel;
      try {
        mapModelYaml = loadYaml(modelYaml, recover: true);
      } catch (e) {
        print(e);
      }
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
      var l = await localStorage.getItem('json/$id', 0);
      if (l != null) {
        modelProperties = jsonDecode(l);
      } else {
        modelProperties = {};
      }
      print("load properties model = $id");
      isLoadProp = true;
    }
  }

  void saveProperties() {
    var jsonEncode2 = jsonEncode(modelProperties);
    print(jsonEncode2);
    localStorage.setItem('json/$id', jsonEncode2);
  }
}
