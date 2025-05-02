import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:jsonschema/json_tree.dart';
import 'package:localstorage/localstorage.dart';
import 'package:yaml/yaml.dart';

class ModelSchema {
  String listModelYaml = '';
  Map mapListModelYaml = {};

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

  void load() {
    var saveModel = localStorage.getItem(id);
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
    _loadProperties();
  }

  Map<String, dynamic> getProperties() {
    _loadProperties();
    return modelProperties;
  }

  void _loadProperties() {
    if (!isLoadProp) {
      var l = localStorage.getItem('json/$id');
      if (l != null) {
        modelProperties = jsonDecode(l);
      } else {
        modelProperties = {};
      }
      print("set properties model = $id");
      isLoadProp = true;
    }
  }

  void saveProperties() {
    localStorage.setItem('json/$id', jsonEncode(modelProperties));
  }
}
