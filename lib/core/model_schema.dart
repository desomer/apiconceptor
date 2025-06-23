import 'package:animated_tree_view/tree_view/tree_node.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/core/bdd/data_event.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/yaml_browser.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/widget_state/state_model.dart';
import 'package:yaml/yaml.dart';

class ModelVersion implements Comparable<ModelVersion> {
  ModelVersion({required this.id, required this.version, required this.data});

  String id;
  String version;
  Map<String, dynamic> data;

  @override
  int compareTo(ModelVersion other) {
    return -(int.parse(version).compareTo(int.parse(other.version)));
  }
}

//--------------------------------------------------------------------------
enum TypeModelBreadcrumb {
  businessmodel,
  component,
  request
  ; 
  
  static String valString(TypeModelBreadcrumb v) {
     return ['Business model', 'Component', 'Request'][v.index];
  }
} 


class ModelSchema {
  ModelSchema({
    required this.type,
    required this.headerName,
    required this.id,
    required this.infoManager,
  });

  final YamlType type;
  final String id;
  final String headerName;
  bool isLoadProp = false;

  String modelYaml = '';
  Map mapModelYaml = {};
  Map<String, dynamic> modelProperties = {};

  final InfoManager infoManager;
  List<ModelSchema> dependency = [];

  List histories = [];

  Map<String, AttributInfo> mapInfoByTreePath = {};

  Map<String, AttributInfo> mapInfoByJsonPath = {};
  Map<String, List<AttributInfo>> mapInfoByName = {};
  Map<String, AttributInfo> allAttributInfo = {};

  List<AttributInfo> notUseAttributInfo = [];
  List<AttributInfo> useAttributInfo = [];
  int lastNbNode = 0;
  bool first = true;
  bool isEmpty = false;
  bool autoSave = true;

  NodeAttribut? currentAttr;
  ModelBrower? lastBrowser;
  JsonBrowser? lastJsonBrowser;

  Function? onChange; // sur un changement du schema

  List<String> modelPath = [];
  TypeModelBreadcrumb? typeBreabcrumb;

  List<ModelVersion>? versions;
  ModelVersion? currentVersion;

  void clear() {
    isLoadProp = false;

    modelYaml = '';
    mapModelYaml = {};
    modelProperties = {};

    histories = [];

    mapInfoByTreePath = {};

    mapInfoByJsonPath = {};
    mapInfoByName = {};
    allAttributInfo = {};

    notUseAttributInfo = [];
    useAttributInfo = [];
    lastNbNode = 0;
    first = true;
    isEmpty = false;
  }

  String getVersionId() => currentVersion?.version ?? '1';
  String getVersionText() => currentVersion?.data['versionTxt'] ?? '0.0.1';

  void initBreadcrumb() {
    var version = currentCompany.currentModel!.getVersionText();
    stateModel.path = [TypeModelBreadcrumb.valString(typeBreabcrumb!), ...modelPath, version, "draft"];
    // ignore: invalid_use_of_protected_member
    stateModel.keyBreadcrumb.currentState?.setState(() {});
  }

  void initEventListener(TextConfig textConfig) {
    bddStorage.doEventListner[id] = OnEvent(
      id: id,
      onPatch: (patch) {
        print('receive on $id event $patch');
        if (patch['typeEvent'] == 'PROP') {
          bddStorage.dispatchChangeProperties(
            this,
            patch,
            textConfig,
            patch['payload']['version'],
          );
        } else if (patch['typeEvent'] == 'YAML') {
          if (getVersionId() == patch['version']) {
            var ret = bddStorage.dispatchChangeYaml(
              id: id,
              patch: patch,
              value: modelYaml,
              version: patch['version'],
            );
            if (ret != null) modelYaml = ret;
            doChangeYaml(textConfig, false, 'event');
          }
        }
      },
    );
  }

  void changeSelected(NodeAttribut attr) {
    var path = attr.info.path;
    if (lastBrowser?.selectedPath == null ||
        !lastBrowser!.selectedPath!.contains(path)) {
      lastBrowser?.selectedPath ??= {};
      lastBrowser?.selectedPath!.add(path);
    } else if (lastBrowser?.selectedPath != null) {
      lastBrowser?.selectedPath!.remove(path);
    }
  }

  void addHistory(
    NodeAttribut node,
    String path,
    ChangeOpe ope,
    dynamic propChangeValue,
    dynamic value, {
    String? master,
  }) {
    node.info.action = 'U';

    if (histories.isNotEmpty) {
      var last = histories.last;
      if (last?['ope'] == ope.name && last?['path'] == path) {
        propChangeValue = last?['from'];
        histories.removeLast();
      }
      // if (ope==ChangeOpe.clear && last?['ope'] == ChangeOpe.set.name && last?['path'] == path) {
      //   propChangeValue = last?['from'];
      //   histories.removeLast();
      // }
    }

    var histo = {
      'node': node,
      'ope': ope.name,
      'path': path,
      'from': _getMdValue(propChangeValue),
      'to': _getMdValue(value),
      'date': DateTime.now().toIso8601String(),
      'by': 'my',
      if (master != null) 'master': master,
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onChange?.call(histo);
    });
    histories.add(histo);
  }

  dynamic _getMdValue(dynamic v) {
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
      } else if (ope == ChangeOpe.clear.name) {
        ret.writeln(
          '* ${h['path']}   **CLEAR**  $from        *BY ${h['by']} **AT** ${h['date']}*',
        );
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
    return bddStorage.getItemSync(
      id: id,
      delay: delay,
      version: currentVersion,
    );
  }

  void reorgPropertiesPath(List<TreeNode<NodeAttribut>> all) {
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

  void loadSubSchema(dynamic path, ModelSchema source) {
    try {
      mapModelYaml = source.mapModelYaml[path];
    } catch (e) {
      print(e);
    }
    modelProperties = {};
    String pa = 'root>$path>';
    for (var element in source.modelProperties.entries) {
      if (element.key.startsWith(pa)) {
        var p = element.key.substring(pa.length);
        modelProperties['root>$p'] = element.value;
      }
    }
    isLoadProp = true;
  }

  Future<void> loadYamlAndProperties({required bool cache}) async {
    if (type == YamlType.model) {
      var versions = await bddStorage.getAllVersion(this);
      if (versions.isEmpty) {
        ModelVersion version = ModelVersion(
          id: id,
          version: '1',
          data: {
            'state': 'D',
            'by': currentCompany.userId,
            'versionTxt': '0.0.1',
          },
        );
        versions.add(version);
        currentVersion = version;
        bddStorage.addVersion(this, version);
      } else {
        currentVersion ??= versions.first;
      }
    }

    dynamic savedYamlModel = bddStorage.getItem(
      model: this,
      id: id,
      version: currentVersion,
      delay: cache ? -1 : 0,
    );
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
    dynamic saveModel = bddStorage.getItem(
      model: this,
      id: id,
      version: currentVersion,
      delay: cache ? -1 : 0,
    );
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
    if (!isLoadProp && withBdd) {
      var l = await bddStorage.getItem(
        model: this,
        version: currentVersion,
        id: 'json/$id',
        delay: 0,
      );
      if (l == null) {
        modelProperties = {};
      }

      print("load properties model = $id");
      isLoadProp = true;
    }
  }

  dynamic _loadPropertiesSync() {
    if (!isLoadProp) {
      var l = bddStorage.getItem(
        model: this,
        version: currentVersion,
        id: 'json/$id',
        delay: -1,
      );
      if (l is! Future) {
        if (l == null) {
          modelProperties = {};
        } else {
          modelProperties = l;
        }
        print("load properties model = $id");
        isLoadProp = true;
      }
    }
  }

  void saveProperties() {
    if (withBdd) {
      bddStorage.prepareSaveModel(this);
    }
  }

  void doChangeYaml(TextConfig? config, bool save, String action) {
    var parser = ParseYamlManager();
    bool parseOk = parser.doParseYaml(modelYaml, config);

    if (parseOk) {
      mapModelYaml = parser.mapYaml!;
      if (save) {
        bddStorage.saveYAML(model: this, type: 'YAML', value: modelYaml);
      }

      if (action == 'event' || action == 'import') {
        if (config?.textYamlState.mounted ?? false) {
          // ignore: invalid_use_of_protected_member
          config?.textYamlState.setState(() {});
        }
        if (config?.treeJsonState.mounted ?? false) {
          // ignore: invalid_use_of_protected_member
          config?.treeJsonState.setState(() {});
        }
      } else {
        if (config?.treeJsonState.mounted ?? false) {
          // ignore: invalid_use_of_protected_member
          config?.treeJsonState.setState(() {});
        }
      }
    }
  }
}
