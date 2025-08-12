import 'package:animated_tree_view/tree_view/tree_node.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/core/model_schema.dart';

import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/tree_editor/tree_view.dart';
import 'package:jsonschema/widget/tree_editor/widget_json_row.dart';
import 'package:uuid/uuid.dart';
// import 'package:nanoid/async.dart';

String getKeyParamFromYaml(dynamic key) {
  return (key is Map ? '{${key.keys.first}}' : key).toString();
}

class JsonBrowser<T> {
  bool ready = false;
  var uuid = Uuid();

  void onInit(ModelSchema model) {}
  void onReady(ModelSchema model) {}
  void onRowTypeChange(ModelSchema model, NodeAttribut node) {}

  Future<NodeBrower> browseSync(
    ModelSchema model,
    bool unknowedMode,
    int antiloop,
  ) async {
    var ret = browse(model, unknowedMode);
    if (ret.wait != null && antiloop < 20) {
      //await Future.delayed(Duration(milliseconds: 300));
      await ret.wait;
      ret = await browseSync(model, unknowedMode, antiloop + 1);
    }
    return ret;
  }

  NodeBrower browse(ModelSchema model, bool unknowedMode) {
    int time = DateTime.now().millisecondsSinceEpoch;
    NodeBrower browser = NodeBrower()..time = time;
    browser.selectedPath = model.lastBrowser?.selectedPath;
    browser.unknowedMode = unknowedMode;

    var rootNodeAttribut = NodeAttribut(
      parent: null,
      yamlNode: MapEntry(model.headerName, 'root'),
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

    model.nodeByMasterId.clear();

    _recursiveBrowseNode(model, browseAttrInfo, model.mapModelYaml);

    if (model.first && model.mapModelYaml.isEmpty) {
      model.isEmpty = true;
    }

    if (browser.unknowedMode) {
      doSetUnknowNode(model, browser);
    }

    _reorgInfoByName(browser.time, model);
    _initNotUseAttr(browser, model, browser.time);

    model.lastNbNode = browser.nbNode;

    List<Future<ModelSchema>> waitAllRef = [];

    for (var element in browser.asyncRef) {
      waitAllRef.add(
        element.ref!.loadYamlAndProperties(cache: true, withProperties: true),
      );
    }
    if (waitAllRef.isNotEmpty) {
      Future.wait(waitAllRef).then((value) {
        onStrutureChanged();
      });
      browser.wait = Future.wait(waitAllRef);
    }

    //List<Future> waitAllAsync = [];
    // for (var element in browser.asyncMaster) {
    //   element.masterId!.then((value) {
    //     element.nodeAttribut.info.properties?[constMasterID] = value;
    //     element.nodeAttribut.info.masterID = value;
    //     element.nodeAttribut.info.cacheRowWidget = null;
    //   });
    //   waitAllAsync.add(element.masterId!);
    // }
    // if (waitAllAsync.isNotEmpty) {
    //   Future.wait(waitAllAsync).then((value) {
    //     model.first = true; // pour les nouveau noeud ajouter par les $ref
    //     onPropertiesChanged();
    //     if (model.autoSave) {
    //       model.saveProperties();
    //     }
    //   });
    // }

    if (browser.propertiesChanged) {
      onPropertiesChanged();
      if (model.autoSaveProperties) {
        model.saveProperties();
      }
    }

    onInit(model);
    T? r = getRoot(rootNodeAttribut);
    if (r != null) {
      doTree(model, rootNodeAttribut, r);
    }
    onReady(model);

    ready = true;
    return browser;
  }

  void doTree(ModelSchema model, NodeAttribut aNodeAttribut, dynamic r) {
    for (var element in aNodeAttribut.child) {
      dynamic c = getChild(aNodeAttribut, element, r);
      if (c != null) {
        doTree(model, element, c);
      }
    }
  }

  void doSetUnknowNode(ModelSchema model, NodeBrower browser) {
    //List<BrowserAttrInfo> newAttribut = [];

    if (model.first) {
      for (var element in browser.unknownAttribut) {
        _initNode(model, element);
      }
      model.first = browser.asyncRef.isNotEmpty;
    } else if (model.lastNbNode == browser.nbNode) {
      for (var element in browser.unknownAttribut) {
        // recherche AttributInfo par path si renommage
        var info = model.mapInfoByTreePath[element.yamlPathAttr];
        if (info != null && info.lastBrowseDate < browser.time) {
          element.nodeAttribut.info = info;
          //print('renommage de ${info.path} => ${element.aJsonPath}');
          model.addHistory(
            element.nodeAttribut,
            info.masterID ?? info.properties?[constMasterID],
            ChangeOpe.rename,
            info.path,
            element.aJsonPath,
          );
          _initNode(model, element);
          info.cacheRowWidget = null;
          info.cacheHeaderWidget = null;
        } else {
          _doSearchNode(model, element);
          //newAttribut.add(element);
        }
      }
    } else {
      // la structure à changer
      for (var element in browser.unknownAttribut) {
        // recherche AttributInfo par mon si renommage
        _doSearchNode(model, element);
      }
    }
  }

  void _doSearchNode(ModelSchema model, BrowserAttrInfo element) {
    // recherche AttributInfo par mon si renommage
    var listName = model.mapInfoByName[element.nodeAttribut.info.name];
    var info = model.getNearestAttributNotUsed(listName, element, false);
    if (info == null) {
      for (var dep in model.dependency) {
        var listName = dep.mapInfoByName[element.nodeAttribut.info.name];
        info = dep.getNearestAttributNotUsed(listName, element, true);
        if (info != null) {
          break;
        }
      }
    }

    if (info != null) {
      element.nodeAttribut.info = info;
      _initNode(model, element);
      print('reused de ${info.name} => ${element.aJsonPath}');
    } else {
      // print('new ${element.aJsonPath}');
      model.addHistory(
        element.nodeAttribut,
        element.nodeAttribut.info.masterID ?? '',
        ChangeOpe.add,
        element.aJsonPath,
        '',
      );
      //newAttribut.add(element);
    }
    _initNode(model, element);
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

  void _recursiveBrowseNode(
    ModelSchema model,
    BrowserAttrInfo attr,
    Map node, {
    ModelSchema? onRef,
  }) {
    if (attr.level > attr.browser.nbLevelMax) {
      attr.browser.nbLevelMax = attr.level;
    }

    if (attr.level > 10) {
      return;
    }

    var entries = node.entries;
    int i = 0;
    for (var mapChild in entries) {
      var yamlPathAttr = '${attr.yamlPathAttr};$i';
      if (mapChild.key == null || mapChild.value == null) continue;

      String yamlAttrName = getKeyParamFromYaml(mapChild.key);
      var aJsonPath = '${attr.aJsonPath}>$yamlAttrName';

      // recherche AttributInfo via le jonPath
      var info = model.mapInfoByJsonPath[aJsonPath];
      bool unkowned = info == null;

      // recherche le masterID via le jonPath dans le modelProperties
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

      doNode(childNodeAttribut);

      if (mapChild.value is String &&
          mapChild.value.toString().startsWith('\$')) {
        // gestion de $ref
        var refName = (mapChild.value as String).substring(1);
        _doRef(mapChild, browserAttrInfo, model, refName, false);
      }

      if (attr.browser.selectedPath?.contains(aJsonPath) ?? false) {
        if (mapChild.value == 'model') {
          _doRef(mapChild, browserAttrInfo, model, mapChild.key, true);
        }
      } else {
        browserAttrInfo.nodeAttribut.info.firstLoad = false;
      }

      if (mapChild.value is Map) {
        _recursiveBrowseNode(
          model,
          browserAttrInfo,
          mapChild.value,
          onRef: onRef,
        );
      } else if (mapChild.value is List) {
        if ((mapChild.value as List).length == 1) {
          var type = mapChild.value[0];
          if (type is Map) {
            _recursiveBrowseNode(model, browserAttrInfo, type, onRef: onRef);
          } else if (type is String) {
            _recursiveBrowseNode(model, browserAttrInfo, {
              constType: type,
            }, onRef: onRef);
          }
        } else {
          Map oneOf = {};
          // ajoute un
          for (var type in mapChild.value) {
            if (type is Map) {
              oneOf.addAll(type);
            } else if (type is String) {
              oneOf.addAll({constType: type});
            }
          }
          _recursiveBrowseNode(model, browserAttrInfo, {
            constTypeAnyof: oneOf,
          }, onRef: onRef);
        }
      }
      i++;
      attr.browser.nbNode++;
    }
  }

  void _doRef(
    MapEntry<dynamic, dynamic> mapChild,
    BrowserAttrInfo browserAttrInfo,
    ModelSchema model,
    String refName,
    bool selected,
  ) {
    List<AttributInfo>? aModelByName = model.getModelByRefName(refName);

    if (aModelByName != null) {
      browserAttrInfo.nodeAttribut.info.isRef = refName;
      String masterIdRef = aModelByName.first.properties?[constMasterID];
      var modelRef = ModelSchema(
        category: model.category,
        headerName: refName,
        id: masterIdRef,
        infoManager: model.infoManager,
      );
      modelRef.currentVersion =
          bddStorage
              .lastVersionByMaster[masterIdRef]; // recupére la derniere version charger
      var ret = modelRef.getItemSync(-1);
      if (ret == null) {
        if (browserAttrInfo.ref == null ||
            browserAttrInfo.ref?.id != masterIdRef) {
          print("load ref $refName id=$masterIdRef");
          browserAttrInfo.browser.asyncRef.add(browserAttrInfo);
        }
        browserAttrInfo.ref = modelRef;
      } else {
        // cas existe en cache

        modelRef.loadYamlAndPropertiesSyncOrNot(cache: true);
        Map node = {constRefOn: modelRef.mapModelYaml};

        if (selected) {
          print("selected ref $refName id=$masterIdRef");
          if (!browserAttrInfo.nodeAttribut.info.firstLoad) {
            browserAttrInfo.nodeAttribut.addChildAsync = true;
          }
          browserAttrInfo.nodeAttribut.info.firstLoad = true;
          node = modelRef.mapModelYaml;
        }

        browserAttrInfo.aJsonPathRef = 'root';
        _recursiveBrowseNode(model, browserAttrInfo, node, onRef: modelRef);
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

  void _initNode(ModelSchema model, BrowserAttrInfo bi) {
    var nodeAttribut = bi.nodeAttribut;
    var aJsonPath = bi.aJsonPath;
    var info = nodeAttribut.info;
    if (info.oldTreePosition != null && info.treePosition != bi.yamlPathAttr) {
      // print(
      //   "change position ${nodeAttribut.info.oldTreePosition} => ${bi.yamlPathAttr}",
      // );
      bi.browser.propertiesChanged = info.action == 'D';
      model.addHistory(
        nodeAttribut,
        aJsonPath,
        ChangeOpe.move,
        info.oldTreePosition,
        bi.yamlPathAttr,
        master: info.masterID,
      );
    }

    info.treePosition = bi.yamlPathAttr;
    info.name = getKeyParamFromYaml(nodeAttribut.yamlNode.key);

    //     //
    // (nodeAttribut.yamlNode.key is Map
    //         ? (nodeAttribut.yamlNode.key as Map).keys.first
    //         : nodeAttribut.yamlNode.key)
    //     .toString();
    info.lastBrowseDate = bi.browser.time;
    info.isRef = bi.nodeAttribut.info.isRef;
    bi.nodeAttribut.level = bi.level;

    model.mapInfoByTreePath[bi.yamlPathAttr] = info;

    model.mapInfoByName[info.name] ??= [];
    var aMapInfo = model.mapInfoByName[info.name]!;
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
      info.cacheRowWidget = null;
      info.cacheHeaderWidget = null;
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
      bi.masterId = uuid.v7(); // nanoid();
      //bi.browser.asyncMaster.add(bi);
      info.properties![constMasterID] = bi.masterId;
      info.masterID = bi.masterId;
      bi.browser.propertiesChanged = true;
    }

    if (info.masterID != null) {
      model.allAttributInfo[info.masterID!] = info;
      model.nodeByMasterId[info.masterID!] = nodeAttribut;
    }

    var type = model.infoManager.getTypeTitle(
      nodeAttribut,
      info.name,
      nodeAttribut.yamlNode.value,
    );
    if (!model.first && info.type != type) {
      model.addHistory(
        nodeAttribut,
        '${info.path}.type',
        ChangeOpe.change,
        info.type,
        type,
      );
    }
    if (type != info.type) {
      onRowTypeChange(model, nodeAttribut);
    }
    info.type = type;
    if (bi.ref != null && info.type == '\$ref') {
      info.properties![constRefOn] = bi.ref!.headerName;
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
    ModelSchema model,
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
        nodeAttribut,
        nodeAttribut.info.masterID!,
        ChangeOpe.path,
        nodeAttribut.info.path,
        aJsonPath,
      );
    }
  }

  void _reorgInfoByName(int date, ModelSchema model) {
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

  void _initNotUseAttr(NodeBrower browser, ModelSchema model, int date) {
    model.notUseAttributInfo.clear();
    model.useAttributInfo.clear();
    for (var element in model.allAttributInfo.entries) {
      if (element.value.lastBrowseDate < date) {
        if (element.value.oldTreePosition == null &&
            element.value.masterID != null) {
          browser.propertiesChanged = true;
          model.addHistory(
            NodeAttribut(yamlNode: element, info: element.value, parent: null),
            element.value.masterID!,
            ChangeOpe.remove,
            element.value.path,
            '',
          );
        }
        element.value.oldTreePosition ??= element.value.treePosition;
        element.value.treePosition = null;
        model.notUseAttributInfo.add(element.value);
        model.mapInfoByJsonPath.remove(element.value.path);
      } else {
        element.value.oldTreePosition = null;
        model.useAttributInfo.add(element.value);
      }
    }
  }
}

class NodeBrower {
  late int time;
  bool propertiesChanged = false;
  int nbNode = 0;
  bool unknowedMode = true;
  int nbLevelMax = 0;

  List<BrowserAttrInfo> unknownAttribut = [];
  List<BrowserAttrInfo> asyncRef = [];
  List<BrowserAttrInfo> asyncMaster = [];

  Set<String>? selectedPath;
  Future? wait;
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
  int level = 0;
  String? addChildOn;
  String addInAttr = "";

  State? widgetSelectState;

  bool addChildAsync = false;
  Color? bgcolor;

  void repaint() {
    info.repaint();
  }

  void repaintChild() {
    for (var element in child) {
      element.repaint();
      element.repaintChild();
    }
  }
}

class AttributInfo {
  int lastBrowseDate = 0;
  String? masterID;
  String? treePosition;
  String? oldTreePosition;
  String name = '';
  String type = '';
  String path = '';
  String? isRef;
  Map<String, dynamic>? properties;
  Map<EnumErrorType, AttributError>? error;
  String? tooltipError;

  Widget? cacheRowWidget;
  Widget? cacheHeaderWidget;
  Widget? cacheIndicatorWidget;
  State? widgetRowState; // pour repaint
  double? cacheHeight;

  DateTime? timeLastUpdate; // update en base
  DateTime? timeLastChange; // mise a jour des properties

  bool isInitByRef = false;
  bool firstLoad = false;
  String? action;
  int numUpdateForKey = 0;
  bool selected = false;

  void repaint() {
    timeLastChange = DateTime.now();

    if (widgetRowState?.mounted ?? false) {
      if (widgetRowState is WidgetJsonRowState) {
        (widgetRowState as WidgetJsonRowState).widget.cache = null;
      }
      print("reload state $widgetRowState");
      // ignore: invalid_use_of_protected_member
      widgetRowState?.setState(() {});
    }
  }

  AttributInfo clone() {
    return AttributInfo()
      ..lastBrowseDate = lastBrowseDate
      ..masterID = masterID
      ..treePosition = treePosition
      ..oldTreePosition = oldTreePosition
      ..name = name
      ..type = type
      ..path = path
      ..isRef = isRef
      ..properties = properties
      ..error = error
      ..tooltipError = tooltipError
      ..cacheRowWidget = cacheRowWidget
      ..cacheHeaderWidget = cacheHeaderWidget
      ..cacheHeight = cacheHeight
      ..timeLastUpdate = timeLastUpdate
      ..isInitByRef = isInitByRef
      ..firstLoad = firstLoad
      ..action = action
      ..numUpdateForKey = numUpdateForKey;
  }

  String getJsonPath() {
    StringBuffer curPath = StringBuffer("root");
    List<String> pathJson = path.split(">");
    bool nextIsTypeOf = false;
    for (var i = 1; i < pathJson.length; i++) {
      var p = pathJson[i];
      if (p == constRefOn) continue;

      if (p == constTypeAnyof) {
        nextIsTypeOf = true;
        continue;
      } else if (nextIsTypeOf) {
        nextIsTypeOf = false;
        // l'objet est uniquement le type
        continue;
      }
      curPath.write('.$p');
    }
    return curPath.toString();
  }
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
  NodeBrower browser;
  int level = 0;

  bool unkwown = false;
  ModelSchema? ref;
  String? aJsonPathRef;
  String? masterId;
}

enum EnumErrorType { errorRef, errorType }

class AttributError {
  AttributError({required this.type, required this.invalidInfo});
  EnumErrorType type;
  InvalidInfo? invalidInfo;
}

abstract class InfoManager {
  /// permet egalement d'affecter une couleur de fond node.bgcolor
  String getTypeTitle(NodeAttribut node, String name, dynamic type);

  InvalidInfo? isTypeValid(
    NodeAttribut nodeAttribut,
    String name,
    dynamic type,
    String typeTitle,
  );

  Widget getRowHeader(TreeNodeData<NodeAttribut> node);
  void addRowWidget(
    NodeAttribut attr,
    ModelSchema schema,
    List<Widget> row,
    BuildContext context,
  ) {}

  /// permet de personnaliser l'affichage de l'entête d'un attribut (icon + text )
  Widget getAttributHeaderOLD(TreeNode<NodeAttribut> node);

  /// permet de faire des actions sur le noeud
  /// par exemple pour les $ref, on affecte l'url sur le parent
  void onNode(NodeAttribut? parent, NodeAttribut child) {}
}

class InvalidInfo {
  InvalidInfo({required this.color});
  final Color color;
}
