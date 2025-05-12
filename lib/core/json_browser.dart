import 'package:animated_tree_view/tree_view/tree_node.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/main.dart';
import 'package:nanoid/async.dart';

class JsonBrowser<T> {
  bool ready = false;

  void onInit(ModelSchemaDetail model) {}
  void onReady(ModelSchemaDetail model) {}

  ModelBrower browse(ModelSchemaDetail model, bool unknowedMode) {
    int time = DateTime.now().millisecondsSinceEpoch;
    ModelBrower browser = ModelBrower()..time = time;

    browser.unknowedMode = unknowedMode;

    var rootNodeAttribut = NodeAttribut(
      parent: null,
      yamlNode: MapEntry(model.name, 'root'),
      info:
          AttributInfo()
            ..name = 'root'
            ..type = 'root',
    );

    var browseAttrInfo = BrowserAttrInfo(
      aJsonPath: 'root',
      yamlPathAttr: 'root',
      browser: browser,
      nodeAttribut: rootNodeAttribut,
      level: 0,
    );

    _browseNode(model, browseAttrInfo, model.mapModelYaml);

    if (browser.unknowedMode) {
      doSetUnknowNode(model, browser);
    }

    _reorgInfoByName(browser.time, model);
    _initNotUseAttr(model, browser.time);

    model.lastNbNode = browser.nbNode;

    List<Future> waitAllRef = [];

    for (var element in browser.asyncRef) {
      waitAllRef.add(element.ref!.loadYamlAndProperties(cache: true));
    }
    if (waitAllRef.isNotEmpty) {
      Future.wait(waitAllRef).then((value) {
        onStrutureChanged();
      });
    }

    List<Future> waitAllAsync = [];
    for (var element in browser.asyncMaster) {
      element.masterId!.then((value) {
        element.nodeAttribut.info.properties?[constMasterID] = value;
        element.nodeAttribut.info.cache = null;
      });
      waitAllAsync.add(element.masterId!);
    }
    if (waitAllAsync.isNotEmpty) {
      Future.wait(waitAllAsync).then((value) {
        model.first = true; // pour les nouveau noeud ajouter par les $ref
        onPropertiesChanged();
        model.saveProperties();
      });
    }

    if (browser.propertiesChanged) {
      onPropertiesChanged();
      model.saveProperties();
    }

    onInit(model);
    T? r = getRoot(rootNodeAttribut);
    if (r != null) {
      doTree(rootNodeAttribut, r);
    }
    onReady(model);

    ready = true;
    return browser;
  }

  void doTree(NodeAttribut aNodeAttribut, dynamic r) {
    for (var element in aNodeAttribut.child) {
      dynamic c = getChild(aNodeAttribut, element, r);
      if (c != null) {
        doTree(element, c);
      }
    }
  }

  void doSetUnknowNode(ModelSchemaDetail model, ModelBrower browser) {
    List<BrowserAttrInfo> newAttribut = [];

    if (model.first) {
      for (var element in browser.unknownAttribut) {
        _initNode(model, element);
      }
      model.first = browser.asyncRef.isNotEmpty;
    } else if (model.lastNbNode == browser.nbNode) {
      for (var element in browser.unknownAttribut) {
        // recherche AttributInfo par path si renommage
        var info = model.mapInfoByTreePath[element.yamlPathAttr];
        if (info != null && info.date < browser.time) {
          element.nodeAttribut.info = info;
          //print('renommage de ${info.path} => ${element.aJsonPath}');
          model.addHistory(
            info.masterID!,
            ChangeOpe.rename,
            info.path,
            element.aJsonPath,
          );
          _initNode(model, element);
          element.nodeAttribut.info.cache = null;
        } else {
          newAttribut.add(element);
        }
      }
    } else {
      // la structure à changer
      for (var element in browser.unknownAttribut) {
        // recherche AttributInfo par mon si renommage
        var listName = model.mapInfoByName[element.nodeAttribut.info.name];
        var info = _getNearestAttributNotUsed(listName, element);
        if (info != null) {
          element.nodeAttribut.info = info;
          _initNode(model, element);
          print('reused de ${info.name} => ${element.aJsonPath}');
        } else {
          // print('new ${element.aJsonPath}');
          model.addHistory(
            element.nodeAttribut.info.masterID ?? '',
            ChangeOpe.add,
            element.aJsonPath,
            '',
          );
          newAttribut.add(element);
        }
        _initNode(model, element);
      }
    }
  }

  void onPropertiesChanged() {}
  void onStrutureChanged() {}

  T? getRoot(NodeAttribut node) {
    return null;
  }

  dynamic getChild(NodeAttribut parentNode, NodeAttribut node, dynamic parent) {
    return null;
  }

  void doNode(NodeAttribut nodeAttribut) {}

  void _browseNode(
    ModelSchemaDetail model,
    BrowserAttrInfo attr,
    Map node, {
    ModelSchemaDetail? onRef,
  }) {
    if (attr.level > attr.browser.nbLevelMax) {
      attr.browser.nbLevelMax = attr.level;
    }

    var entries = node.entries;
    int i = 0;
    for (var mapChild in entries) {
      var yamlPathAttr = '${attr.yamlPathAttr};$i';
      if (mapChild.key == null || mapChild.value == null) continue;

      String yamlAttrName = mapChild.key;
      var aJsonPath = '${attr.aJsonPath}>$yamlAttrName';
      var info = model.mapInfoByJsonPath[aJsonPath];
      bool unkowned = info == null;

      var masterID = model.modelProperties[aJsonPath]?[constMasterID];

      var childNodeAttribut = NodeAttribut(
        parent: attr.nodeAttribut,
        yamlNode: mapChild,
        info:
            info ??
            (AttributInfo()
              ..masterID = masterID
              ..name = yamlAttrName
              ..treePosition = yamlPathAttr),
      );

      var browserAttrInfo = BrowserAttrInfo(
        aJsonPath: aJsonPath,
        browser: attr.browser,
        nodeAttribut: childNodeAttribut,
        yamlPathAttr: yamlPathAttr,
        level: attr.level + 1,
      );
      browserAttrInfo.ref = onRef;
      if (attr.aJsonPathRef != null) {
        if (yamlAttrName != constRefOn) {
          browserAttrInfo.aJsonPathRef = '${attr.aJsonPathRef}>$yamlAttrName';
        } else {
          browserAttrInfo.aJsonPathRef = attr.aJsonPathRef;
        }
      }

      if (!attr.browser.unknowedMode) {
        unkowned = false;
      }
      browserAttrInfo.unkwown = unkowned;

      if (unkowned) {
        attr.browser.unknownAttribut.add(browserAttrInfo);
      } else {
        _initNode(model, browserAttrInfo);
      }

      attr.nodeAttribut.child.add(childNodeAttribut);

      //dynamic child = getChild(childNodeAttribut, parent);
      doNode(childNodeAttribut);

      if (mapChild.value is String &&
          mapChild.value.toString().startsWith('\$')) {
        // gestion de $refd
        _doRef(mapChild, browserAttrInfo, model);
      }

      if (mapChild.value is Map) {
        _browseNode(model, browserAttrInfo, mapChild.value, onRef: onRef);
      } else if (mapChild.value is List) {
        Map oneOf = {};
        for (var type in mapChild.value) {
          if (type is Map) {
            oneOf.addAll(type);
          }
        }
        _browseNode(model, browserAttrInfo, {
          constTypeAnyof: oneOf,
        }, onRef: onRef);
      }
      i++;
      attr.browser.nbNode++;
    }
  }

  void _doRef(
    MapEntry<dynamic, dynamic> mapChild,
    BrowserAttrInfo browserAttrInfo,
    ModelSchemaDetail model,
  ) {
    print("load ref ${browserAttrInfo.nodeAttribut.info.name}");
    var refName = (mapChild.value as String).substring(1);
    var listModel = currentCompany.listModel!.mapInfoByName[refName];
    if (listModel != null) {
      browserAttrInfo.nodeAttribut.info.isRef = refName;
      String masterIdRef = listModel.first.properties?[constMasterID];
      var modelRef = ModelSchemaDetail(
        type: model.type,
        name: refName,
        id: masterIdRef,
        infoManager: model.infoManager,
      );
      var ret = modelRef.getItemSync(-1);
      if (ret == null) {
        if (browserAttrInfo.ref == null) {
          browserAttrInfo.browser.asyncRef.add(browserAttrInfo);
        }
        browserAttrInfo.ref = modelRef;
      } else {
        // cas existe en cache
        modelRef.loadYamlAndPropertiesSyncOrNot(cache: true);
        browserAttrInfo.aJsonPathRef = 'root';
        _browseNode(model, browserAttrInfo, {
          constRefOn: modelRef.mapModelYaml,
        }, onRef: modelRef);
        browserAttrInfo.nodeAttribut.info.error?.remove(EnumErrorType.errorRef);
      }
    } else {
      browserAttrInfo.nodeAttribut.info.error ??= {};
      browserAttrInfo.nodeAttribut.info.error![EnumErrorType
          .errorRef] = AttributError(
        type: EnumErrorType.errorRef,
        invalidInfo: InvalidInfo(color: Colors.red),
      );
    }
  }

  void _initNode(ModelSchemaDetail model, BrowserAttrInfo bi) {
    var nodeAttribut = bi.nodeAttribut;
    var aJsonPath = bi.aJsonPath;
    var info = nodeAttribut.info;
    if (info.oldTreePosition != null && info.treePosition != bi.yamlPathAttr) {
      // print(
      //   "change position ${nodeAttribut.info.oldTreePosition} => ${bi.yamlPathAttr}",
      // );
      model.addHistory(
        aJsonPath,
        ChangeOpe.move,
        info.oldTreePosition,
        bi.yamlPathAttr,
        master: info.masterID,
      );
    }
    info.treePosition = bi.yamlPathAttr;
    info.name = bi.nodeAttribut.yamlNode.key;
    info.date = bi.browser.time;
    info.isRef = bi.nodeAttribut.info.isRef;

    model.mapInfoByTreePath[bi.yamlPathAttr] = info;

    model.mapInfoByName[nodeAttribut.yamlNode.key] ??= [];
    var aMapInfo = model.mapInfoByName[nodeAttribut.yamlNode.key]!;
    if (!aMapInfo.contains(info)) {
      aMapInfo.add(info);
    }

    var masterID = model.modelProperties[aJsonPath]?[constMasterID];
    masterID ??= info.properties?[constMasterID];
    info.masterID = masterID;
    if (info.path != '' && info.path != aJsonPath) {
      //print("path change ${nodeAttribut.info.path} => $aJsonPath");
      _doPathChangeHistory(nodeAttribut, aJsonPath, model);
      model.modelProperties[aJsonPath] = info.properties;
      model.modelProperties.remove(info.path);
      model.mapInfoByJsonPath.remove(info.path);
      info.cache = null;
      bi.browser.propertiesChanged = true;
    }
    model.mapInfoByJsonPath[aJsonPath] = info;

    info.path = aJsonPath;

    if (bi.ref != null && bi.aJsonPathRef != null) {
      if (!info.isInitByRef) {
        var prop = bi.ref!.modelProperties[bi.aJsonPathRef];
        if (prop != null) {
          print("get prop on ref");
          info.properties = prop;
          info.isInitByRef = true;
        }
      }
    }

    // affecte les properties si 1° fois
    info.properties ??= model.modelProperties[aJsonPath] ?? {};
    if (info.properties![constMasterID] == null) {
      bi.masterId = nanoid();
      bi.browser.asyncMaster.add(bi);
      info.properties![constMasterID] = '???';
    }

    model.allAttributInfo[info.hashCode] = info;

    var type = model.infoManager.getTypeTitle(
      info.name,
      nodeAttribut.yamlNode.value,
    );
    if (!model.first && info.type != type) {
      model.addHistory('${info.path}.type', ChangeOpe.change, info.type, type);
    }
    info.type = type;
    if (bi.ref != null && info.type == '\$ref') {
      info.properties![constRefOn] = bi.ref!.name;
    }

    var typeValid = model.infoManager.isTypeValid(
      nodeAttribut,
      info.name,
      nodeAttribut.yamlNode.value,
      info.type,
    );
    if (typeValid == null) {
      info.error?.remove(EnumErrorType.errorType);
    } else {
      info.error ??= {};
      info.error![EnumErrorType.errorType] = AttributError(
        type: EnumErrorType.errorType,
        invalidInfo: typeValid,
      );
    }
    model.infoManager.onNode(nodeAttribut.parent, nodeAttribut);
  }

  void _doPathChangeHistory(
    NodeAttribut nodeAttribut,
    String aJsonPath,
    ModelSchemaDetail model,
  ) {
    var op = nodeAttribut.info.path.split('>');
    var np = aJsonPath.split('>');
    StringBuffer a = StringBuffer();
    for (var i = 0; i < op.length - 1; i++) {
      a.write('>${op[i]}');
    }
    StringBuffer b = StringBuffer();
    for (var i = 0; i < np.length - 1; i++) {
      b.write('>${np[i]}');
    }
    if (a.toString() != b.toString()) {
      model.addHistory(
        nodeAttribut.info.masterID!,
        ChangeOpe.path,
        nodeAttribut.info.path,
        aJsonPath,
      );
    }
  }

  AttributInfo? _getNearestAttributNotUsed(
    List<AttributInfo>? list,
    BrowserAttrInfo bi,
  ) {
    if (list == null) return null;

    int maxNear = 0;
    AttributInfo? sel;
    if (list.length == 1) {
      if (list.first.date < bi.browser.time) {
        return list.first;
      } else {
        return null;
      }
    }

    for (var n in list) {
      if (n.date == bi.browser.time) continue; // déja affecter
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
    return sel;
  }

  void _reorgInfoByName(int date, ModelSchemaDetail model) {
    var toRemoveKey = <String>[];

    for (var element in model.mapInfoByName.entries) {
      for (var attrDesc in element.value) {
        if (element.key != attrDesc.name) {
          toRemoveKey.add(element.key);
        }
      }
    }

    for (var element in toRemoveKey) {
      model.mapInfoByName.remove(element);
    }
  }

  void _initNotUseAttr(ModelSchemaDetail model, int date) {
    model.notUseAttributInfo.clear();
    model.useAttributInfo.clear();
    for (var element in model.allAttributInfo.entries) {
      if (element.value.date < date) {
        if (element.value.oldTreePosition == null &&
            element.value.masterID != null) {
          model.addHistory(
            element.value.masterID!,
            ChangeOpe.remove,
            element.value.path,
            '',
          );
        }
        element.value.oldTreePosition ??= element.value.treePosition;
        element.value.treePosition = null;
        model.notUseAttributInfo.add(element.value);
      } else {
        element.value.oldTreePosition = null;
        model.useAttributInfo.add(element.value);
      }
    }
  }
}

class ModelBrower {
  late int time;
  bool propertiesChanged = false;
  int nbNode = 0;
  bool unknowedMode = true;
  int nbLevelMax = 0;

  List<BrowserAttrInfo> unknownAttribut = [];
  List<BrowserAttrInfo> asyncRef = [];
  List<BrowserAttrInfo> asyncMaster = [];
}

class NodeAttribut {
  NodeAttribut({
    required this.yamlNode,
    required this.info,
    required this.parent,
  });
  MapEntry<dynamic, dynamic> yamlNode;
  AttributInfo info;
  NodeAttribut? parent;
  List<NodeAttribut> child = [];
  String? addChildOn;
  String addInAttr = "";
  State? widgetState;
}

class AttributInfo {
  int date = 0;
  String? masterID;
  String? treePosition;
  String? oldTreePosition;
  String name = '';
  String type = '';
  String path = '';
  String? isRef;
  Map<String, dynamic>? properties;
  Map<EnumErrorType, AttributError>? error;
  Widget? cache;
  bool isInitByRef = false;
}

class BrowserAttrInfo {
  BrowserAttrInfo({
    required this.yamlPathAttr,
    required this.nodeAttribut,
    required this.aJsonPath,
    required this.browser,
    required this.level,
  });
  String yamlPathAttr;
  NodeAttribut nodeAttribut;
  String aJsonPath;
  ModelBrower browser;
  int level = 0;

  bool unkwown = false;
  ModelSchemaDetail? ref;
  String? aJsonPathRef;
  Future<String>? masterId;
}

enum EnumErrorType { errorRef, errorType }

class AttributError {
  AttributError({required this.type, required this.invalidInfo});
  EnumErrorType type;
  InvalidInfo? invalidInfo;
}

abstract class InfoManager {
  String getTypeTitle(String name, dynamic type);

  InvalidInfo? isTypeValid(
    NodeAttribut nodeAttribut,
    String name,
    dynamic type,
    String typeTitle,
  );

  Widget getAttributHeader(TreeNode<NodeAttribut> node);
  void onNode(NodeAttribut? parent, NodeAttribut child) {}
}

class InvalidInfo {
  InvalidInfo({required this.color});
  final Color color;
}
