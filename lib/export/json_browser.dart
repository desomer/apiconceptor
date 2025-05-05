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

  void doTree(NodeAttribut rootNodeAttribut, dynamic r) {
    for (var element in rootNodeAttribut.child) {
      dynamic c = getChild(rootNodeAttribut, element, r);
      if (c != null) {
        doTree(element, c);
      }
    }
  }

  void doSetUnknowNode(ModelSchemaDetail model, ModelBrower browser) {
    List<BrowserAttrInfo> newAttribut = [];

    if (model.first) {
      model.first = browser.asyncRef.isNotEmpty;
      for (var element in browser.unknownAttribut) {
        _initNode(model, element);
      }
    } else if (model.lastNbNode == browser.nbNode) {
      for (var element in browser.unknownAttribut) {
        // recherche AttributInfo par path si renommage
        var info = model.mapInfoByTreePath[element.yamlPathAttr];
        if (info != null && info.date < browser.time) {
          element.nodeAttribut.info = info;
          _initNode(model, element);
          element.nodeAttribut.info.cache = null;
          print('renommage de ${info.path} => ${element.aJsonPath}');
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
          print('new ${element.aJsonPath}');
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

  void _browseNode(ModelSchemaDetail model, BrowserAttrInfo attr, Map node) {
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
        yamlNode: mapChild,
        info:
            info ?? AttributInfo()
              ..masterID = masterID
              ..name = yamlAttrName
              ..treePosition = yamlPathAttr,
      );

      var attrInfo = BrowserAttrInfo(
        aJsonPath: aJsonPath,
        browser: attr.browser,
        nodeAttribut: childNodeAttribut,
        yamlPathAttr: yamlPathAttr,
        level: attr.level + 1,
      );

      if (!attr.browser.unknowedMode) {
        unkowned = false;
      }
      attrInfo.unkwown = unkowned;

      if (unkowned) {
        attr.browser.unknownAttribut.add(attrInfo);
      } else {
        _initNode(model, attrInfo);
      }

      attr.nodeAttribut.child.add(childNodeAttribut);

      //dynamic child = getChild(childNodeAttribut, parent);
      doNode(childNodeAttribut);

      if (mapChild.value is String &&
          mapChild.value.toString().startsWith('\$')) {
        // gestion de $refd
        _doRef(mapChild, attrInfo, model);
      }

      if (mapChild.value is Map) {
        _browseNode(model, attrInfo, mapChild.value);
      } else if (mapChild.value is List) {
        Map oneOf = {};
        for (var type in mapChild.value) {
          if (type is Map) {
            oneOf.addAll(type);
          }
        }
        _browseNode(model, attrInfo, {constTypeAnyof: oneOf});
      }
      i++;
      attr.browser.nbNode++;
    }
  }

  void _doRef(
    MapEntry<dynamic, dynamic> mapChild,
    BrowserAttrInfo attrInfo,
    ModelSchemaDetail model,
  ) {
    print("load ref ${attrInfo.nodeAttribut.info.name}");
    var refName = (mapChild.value as String).substring(1);
    var listModel = currentCompany.listModel!.mapInfoByName[refName];
    if (listModel != null) {
      attrInfo.nodeAttribut.info.isRef = refName;
      String masterIdRef = listModel.first.properties?[constMasterID];
      var modelRef = ModelSchemaDetail(name: '', id: masterIdRef);
      attrInfo.ref = modelRef;
      var ret = modelRef.getItemSync(-1);
      if (ret == null) {
        attrInfo.browser.asyncRef.add(attrInfo);
      } else {
        modelRef.loadYamlAndPropertiesSyncOrNot(cache: true);
        _browseNode(model, attrInfo, {constRefOn: modelRef.mapModelYaml});
        attrInfo.nodeAttribut.info.error?.remove(EnumErrorType.errorRef);
      }
    } else {
      attrInfo.nodeAttribut.info.error ??= {};
      attrInfo.nodeAttribut.info.error![EnumErrorType.errorRef] = AttributError(
        type: EnumErrorType.errorRef,
      );
    }
  }

  void _initNode(ModelSchemaDetail model, BrowserAttrInfo bi) {
    var nodeAttribut = bi.nodeAttribut;
    var aJsonPath = bi.aJsonPath;
    nodeAttribut.info.treePosition = bi.yamlPathAttr;
    nodeAttribut.info.name = bi.nodeAttribut.yamlNode.key;
    nodeAttribut.info.date = bi.browser.time;
    nodeAttribut.info.isRef = bi.nodeAttribut.info.isRef;

    model.mapInfoByTreePath[bi.yamlPathAttr] = nodeAttribut.info;

    model.mapInfoByName[nodeAttribut.yamlNode.key] ??= [];
    var aMapInfo = model.mapInfoByName[nodeAttribut.yamlNode.key]!;
    if (!aMapInfo.contains(nodeAttribut.info)) {
      aMapInfo.add(nodeAttribut.info);
    }

    if (nodeAttribut.info.path != '' && nodeAttribut.info.path != aJsonPath) {
      print("path change ${nodeAttribut.info.path} => $aJsonPath");
      model.modelProperties[aJsonPath] = nodeAttribut.info.properties;
      model.modelProperties.remove(nodeAttribut.info.path);
      model.mapInfoByJsonPath.remove(nodeAttribut.info.path);
      nodeAttribut.info.cache = null;
      bi.browser.propertiesChanged = true;
    }
    var masterID = model.modelProperties[aJsonPath]?[constMasterID];
    nodeAttribut.info.masterID = masterID;
    model.mapInfoByJsonPath[aJsonPath] = nodeAttribut.info;

    nodeAttribut.info.path = aJsonPath;
    // affecte les properties si 1° fois
    nodeAttribut.info.properties ??= model.modelProperties[aJsonPath] ?? {};
    if (nodeAttribut.info.properties![constMasterID] == null) {
      bi.masterId = nanoid();
      bi.browser.asyncMaster.add(bi);
      nodeAttribut.info.properties![constMasterID] = '???';
    }

    model.allAttributInfo[nodeAttribut.info.hashCode] = nodeAttribut.info;
    nodeAttribut.info.type = getTypeTitle(
      nodeAttribut.info.name,
      nodeAttribut.yamlNode.value,
    );
    if (isTypeValid(
      nodeAttribut,
      nodeAttribut.info.name,
      nodeAttribut.yamlNode.value,
      nodeAttribut.info.type,
    )) {
      nodeAttribut.info.error?.remove(EnumErrorType.errorType);
    } else {
      nodeAttribut.info.error ??= {};
      nodeAttribut.info.error![EnumErrorType.errorType] = AttributError(
        type: EnumErrorType.errorType,
      );
    }
  }

  String getTypeTitle(String name, dynamic type) {
    String? typeStr;
    if (type is Map) {
      if (name.startsWith(constRefOn)) {
        typeStr = '\$ref';
      } else if (name.startsWith(constTypeAnyof)) {
        typeStr = '\$anyOf';
      } else if (name.endsWith('[]')) {
        typeStr = 'Array';
      } else {
        typeStr = 'Object';
      }
    } else if (type is List) {
      if (name.endsWith('[]')) {
        typeStr = 'Array';
      } else {
        typeStr = 'Object';
      }
    } else if (type is int) {
      typeStr = 'number';
    } else if (type is double) {
      typeStr = 'number';
    } else if (type is String) {
      if (type.startsWith('\$')) {
        typeStr = 'Object';
      }
    }
    typeStr ??= '$type';
    return typeStr;
  }

  bool isTypeValid(
    NodeAttribut nodeAttribut,
    String name,
    dynamic type,
    String typeTitle,
  ) {
    var type = typeTitle.toLowerCase();
    return [
      'model',
      'string',
      'number',
      'object',
      'array',
      '\$ref',
      '\$anyof',
    ].contains(type);
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
    for (var element in model.allAttributInfo.entries) {
      if (element.value.date < date) {
        model.notUseAttributInfo.add(element.value);
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
  NodeAttribut({required this.yamlNode, required this.info});
  MapEntry<dynamic, dynamic> yamlNode;
  AttributInfo info;
  List<NodeAttribut> child = [];
  String? addChildOn;
  String addInAttr = "";
}

class AttributInfo {
  int date = 0;
  String? masterID;
  String? treePosition;
  String name = '';
  String type = '';
  String path = '';
  String? isRef;
  Map<String, dynamic>? properties;
  Map<EnumErrorType, AttributError>? error;
  Widget? cache;
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
  Future<String>? masterId;
}

enum EnumErrorType { errorRef, errorType }

class AttributError {
  AttributError({required this.type});
  EnumErrorType type;
}
