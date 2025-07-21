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
  request;

  static String valString(TypeModelBreadcrumb? v) {
    if (v == null) return '';
    return ['Business models', 'Components', 'Requests & Responses'][v.index];
  }
}

class ModelSchema {
  ModelSchema({
    required this.category,
    required this.headerName,
    required this.id,
    required this.infoManager,
  });

  final String id;

  final Category category; // pour la sauvegarde et certain traitement
  final String headerName; // pour les export
  bool isLoadProp = false;

  ModelBrower? lastBrowser;
  JsonBrowser? lastJsonBrowser;
  final InfoManager infoManager;

  String modelYaml = '';
  Map mapModelYaml = {};
  Map<String, dynamic> modelProperties = {};

  final List<ModelSchema> dependency = [];

  final List histories = [];

  final Map<String, AttributInfo> mapInfoByTreePath = {};

  final Map<String, AttributInfo> mapInfoByJsonPath = {};
  final Map<String, List<AttributInfo>> mapInfoByName = {};
  final Map<String, AttributInfo> allAttributInfo = {};

  final List<AttributInfo> notUseAttributInfo = [];
  final List<AttributInfo> useAttributInfo = [];
  final Map<String, NodeAttribut> nodeByMasterId = {};

  int lastNbNode = 0;
  bool first = true;
  bool isEmpty = false;
  bool autoSaveProperties = true;

  NodeAttribut? currentAttr;

  Function? onChange; // sur un changement du schema

  List<String> modelPath = [];
  TypeModelBreadcrumb? typeBreabcrumb;

  List<ModelVersion>? versions;
  ModelVersion? currentVersion;

  List<AttributInfo>? getModelByRefName(String refName) {
    List<AttributInfo>? aModelByName;
    if (category == Category.api) {
      aModelByName = currentCompany.listRequest.mapInfoByName[refName];
      aModelByName ??= currentCompany.listComponent.mapInfoByName[refName];
      aModelByName ??= currentCompany.listModel.mapInfoByName[refName];
    } else {
      aModelByName = currentCompany.listComponent.mapInfoByName[refName];
      aModelByName ??= currentCompany.listModel.mapInfoByName[refName];
      aModelByName ??= currentCompany.listRequest.mapInfoByName[refName];
    }
    return aModelByName;
  }

  void clear() {
    isLoadProp = false;

    modelYaml = '';
    mapModelYaml = {};
    modelProperties = {};

    histories.clear();

    mapInfoByTreePath.clear();

    mapInfoByJsonPath.clear();
    mapInfoByName.clear();
    allAttributInfo.clear();

    notUseAttributInfo.clear();
    useAttributInfo.clear();
    lastNbNode = 0;
    first = true;
    isEmpty = false;
  }

  String getVersionId() => currentVersion?.version ?? '1';
  String getVersionText() => currentVersion?.data['versionTxt'] ?? '0.0.1';

  void initBreadcrumb() {
    var version = currentCompany.currentModel!.getVersionText();
    stateModel.path = [
      TypeModelBreadcrumb.valString(typeBreabcrumb!),
      ...modelPath,
      version,
      "draft",
    ];
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
            doChangeAndRepaintYaml(textConfig, false, 'event');
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

  String getHistory({required bool toMarkdown}) {
    StringBuffer ret = StringBuffer();
    if (toMarkdown) {
      ret.writeln('## Change log\n version 0.0.1\n');
    }
    int i = 0;
    List removeHisto = [];
    for (var h in histories) {
      var ope = h['ope'];
      dynamic from = h['from'];
      if (ope == ChangeOpe.change.name) {
        if (from == null || from.toString() == '') {
          if (toMarkdown) {
            ret.writeln(
              '* ${h['path']}   **SET**  ${h['to']}        *BY ${h['by']} **AT** ${h['date']}*',
            );
          }
        } else {
          bool add = true;
          if (i > 0) {
            var last = histories[i - 1];
            if (last['path'] == h['path'] &&
                last['ope'] == h['ope'] &&
                last['from'] == h['to']) {
              // revient à la meme valeur
              add = false;
            }
          }
          if (i < histories.length - 1) {
            var next = histories[i + 1];
            if (next['path'] == h['path'] &&
                next['ope'] == h['ope'] &&
                next['to'] == h['from']) {
              // revient à la meme valeur
              add = false;
            }
          }

          if (add && from != h['to']) {
            if (toMarkdown) {
              ret.writeln(
                '* ${h['path']}   **FROM**  $from  **TO**  ${h['to']}       *BY ${h['by']} **AT** ${h['date']}*',
              );
            }
          } else {
            removeHisto.add(h);
          }
        }
      } else if (ope == ChangeOpe.clear.name) {
        if (toMarkdown) {
          ret.writeln(
            '* ${h['path']}   **CLEAR**  $from        *BY ${h['by']} **AT** ${h['date']}*',
          );
        }
      } else if (ope == ChangeOpe.path.name || ope == ChangeOpe.rename.name) {
        if (from != h['to']) {
          if (toMarkdown) {
            ret.writeln(
              '* **${ope.toString().toUpperCase()} FROM**  $from  **TO**  ${h['to']}       *BY ${h['by']} **AT** ${h['date']}*',
            );
          }
        } else {
          removeHisto.add(h);
        }
      } else if (ope == ChangeOpe.move.name) {
        if (from != h['to']) {
          if (toMarkdown) {
            ret.writeln(
              '* ${h['path']}  **${ope.toString().toUpperCase()} FROM**  $from  **TO**  ${h['to']}        *BY ${h['by']} **AT** ${h['date']}*',
            );
          }
        } else {
          removeHisto.add(h);
        }
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
          if (toMarkdown) {
            ret.writeln(
              '* **${ope.toString().toUpperCase()}  ${h['from']}**     *BY ${h['by']} **AT** ${h['date']}*',
            );
          }
        } else {
          removeHisto.add(h);
        }
      }
      i++;
    }
    if (removeHisto.isNotEmpty) {
      for (var element in removeHisto) {
        histories.remove(element);
      }
      return getHistory(toMarkdown: toMarkdown);
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

  /// charge les informations 
  ///  [cache] avec cache mémoire 
  ///  [withProperties] pour les graph
  Future<void> loadYamlAndProperties({
    required bool cache,
    required bool withProperties,
  }) async {
    if (currentVersion == null && category == Category.model) {
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
    if (withProperties) {
      await _loadProperties(cache: cache);
    }
  }

  dynamic loadYamlAndPropertiesSyncOrNot({required bool cache}) {
    dynamic saveModel = bddStorage.getItem(
      model: this,
      id: id,
      version: currentVersion,
      delay: cache ? -1 : 0,
    );
    if (saveModel is Future) {
      return loadYamlAndProperties(cache: cache, withProperties: true);
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
    await _loadProperties(cache: true);
    return modelProperties;
  }

  Future _loadProperties({required bool cache}) async {
    if (cache == false) {
      isLoadProp = false;
    }
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

  void doChangeAndRepaintYaml(TextConfig? config, bool save, String action) {
    var parser = ParseYamlManager();
    bool parseOk = parser.doParseYaml(modelYaml, config);

    if (parseOk) {
      mapModelYaml = parser.mapYaml!;
      if (save) {
        bddStorage.saveYAML(model: this, type: 'YAML', value: modelYaml);
      }

      if (action == 'event' || action == 'import') {
        if (config?.textYamlState?.mounted ?? false) {
          // ignore: invalid_use_of_protected_member
          config?.textYamlState!.setState(() {});
        }
        if (config?.treeJsonState?.mounted ?? false) {
          // ignore: invalid_use_of_protected_member
          config?.treeJsonState?.setState(() {});
        }
      } else {
        if (config?.treeJsonState?.mounted ?? false) {
          // ignore: invalid_use_of_protected_member
          config?.treeJsonState?.setState(() {});
        }
      }
    }
  }

  AttributInfo? getNearestAttributNotUsed(
    List<AttributInfo>? list,
    BrowserAttrInfo bi,
    bool isDependency,
  ) {
    if (list == null) return null;

    if (isDependency) {
      List<AttributInfo>? nllist = [...list];
      for (var element in nllist) {
        var idx = notUseAttributInfo.indexOf(element);
        if (idx == -1) {
          list.remove(element);
        }
      }
      if (list.isEmpty) return null;
    }

    int maxNear = 0;
    AttributInfo? sel;
    if (list.length == 1) {
      if (list.first.lastBrowseDate < bi.browser.time) {
        if (isDependency) notUseAttributInfo.remove(list.first);
        return list.first;
      } else {
        return null;
      }
    }

    for (var n in list) {
      if (n.lastBrowseDate == bi.browser.time) continue; // déja affecter
      String pathA = bi.aJsonPath;
      String pathB = n.path;
      if (pathA == pathB) {
        return n;
      }
      int nb = pathA.length;
      if (pathB.length < nb) {
        nb = pathB.length;
      }
      int nbNear = 0;
      for (var i = 0; i < nb; i++) {
        if (pathA[i] != pathB[i]) break;
        nbNear++;
      }
      if (nbNear > maxNear) {
        maxNear = nbNear;
        sel = n;
      }
    }
    if (isDependency && sel != null) notUseAttributInfo.remove(sel);
    return sel;
  }
}
