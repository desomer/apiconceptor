import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/json_list.dart';
import 'package:jsonschema/main.dart';
import 'package:nanoid/async.dart';

class JsonEditor extends StatefulWidget {
  const JsonEditor({super.key, required this.config});
  final JsonTreeConfig config;

  @override
  State<JsonEditor> createState() => _JsonEditorState();
}

class _JsonEditorState extends State<JsonEditor>
    with SingleTickerProviderStateMixin {
  late AutoScrollController _scrollController;
  ModelInfo modelInfo = ModelInfo();
  GlobalKey keyJsonList = GlobalKey();

  @override
  initState() {
    _scrollController = AutoScrollController();
    modelInfo.scrollController = ScrollController();
    _scrollController.addListener(() {
      modelInfo.scrollController!.jumpTo(_scrollController.offset);
    });
    modelInfo.scrollController!.addListener(() {
      _scrollController.jumpTo(modelInfo.scrollController!.offset);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ModelSchemaDetail model = (widget.config.getModel() as ModelSchemaDetail);

    var rootTree = TreeNode<NodeAttribut>.root(
      data: NodeAttribut(
        yamlNode: MapEntry(model.name, 'root'),
        info: AttributInfo(),
      ),
    );

    int time = DateTime.now().millisecondsSinceEpoch;
    ModelBrower browser = ModelBrower()..time = time;
    _browseNode(
      model,
      'root',
      'root',
      rootTree,
      widget.config.getJson(),
      browser,
    );

    List<BrowserInfo> newAttribut = [];
    if (model.first) {
      model.first = false;
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
          print('renommage de ${info.path} => ${element.aJsonPath}');
        } else {
          newAttribut.add(element);
        }
      }
    } else {
      // la structure à changer
      for (var element in browser.unknownAttribut) {
        // recherche AttributInfo par mon si renommage
        var listName = model.mapInfoByName[element.element.key];
        var info = _getNearestAttributNotUsed(listName, element);
        if (info != null) {
          element.nodeAttribut.info = info;
          _initNode(model, element);
          print('reused de ${info.name} => ${element.aJsonPath}');
        } else {
          print('new ${element.aJsonPath}');
        }
        _initNode(model, element);
      }
    }

    model.lastNbNode = browser.nbNode;

    _reorgInfoByName(time, model);

    if (browser.pathJsonChanged) {
      currentCompany.currentModel!.saveProperties();
    }

    model.notUseAttributInfo.clear();
    for (var element in model.allAttributInfo.entries) {
      if (element.value.date < time) {
        model.notUseAttributInfo.add(element.value);
      }
    }

    print(
      "nb name = ${model.mapInfoByName.length} nb path = ${model.mapInfoByJsonPath.length}  all info = ${model.allAttributInfo.length}",
    );

    modelInfo.config = widget.config;
    return Row(
      children: [
        SizedBox(width: 400, child: getTree(rootTree)),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: JsonList(key: keyJsonList, modelInfo: modelInfo),
          ),
        ),
      ],
    );
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

  void _browseNode(
    ModelSchemaDetail model,
    String nodePath,
    String jsonPath,
    TreeNode parent,
    Map node,
    ModelBrower browser,
  ) {
    var entries = node.entries;
    int i = 0;
    for (var element in entries) {
      var yamlPathAttr = '$nodePath;$i';
      if (element.key == null || element.value == null) continue;
      String yamlAttrName = element.key;
      var aJsonPath = '$jsonPath>$yamlAttrName';
      var info = model.mapInfoByJsonPath[aJsonPath];
      bool unkowned = info == null;

      var nodeAttribut = NodeAttribut(
        yamlNode: element,
        info: info ?? AttributInfo(),
      );
      var binfo = BrowserInfo(
        aJsonPath: aJsonPath,
        browser: browser,
        element: element,
        nodeAttribut: nodeAttribut,
        yamlPathAttr: yamlPathAttr,
      );
      binfo.unkwown = unkowned;
      var treeNode = TreeNode(key: yamlPathAttr, data: nodeAttribut);

      if (unkowned) {
        browser.unknownAttribut.add(binfo);
      } else {
        _initNode(model, binfo);
      }
      parent.add(treeNode);

      if (element.value is String && element.value.startsWith('\$')) {
        // gestion de $refd
        print("load ref $yamlAttrName");
        var refName = (element.value as String).substring(1);
        var listModel = currentCompany.listModel!.mapInfoByName[refName];
        if (listModel != null) {
          String masterIdRef = listModel.first.properties?[constMasterID];
          var modelRef = ModelSchemaDetail(name: '', id: masterIdRef)..load();

          var mapRef = modelRef.mapModelYaml;
          _browseNode(model, yamlPathAttr, aJsonPath, treeNode, {
            constRefOn: mapRef,
          }, browser);
          nodeAttribut.info.error?.remove(EnumErrorType.errorRef);
        } else {
          nodeAttribut.info.error ??= {};
          nodeAttribut.info.error![EnumErrorType.errorRef] = AttributError(
            type: EnumErrorType.errorRef,
          );
        }
      }

      if (element.value is Map) {
        _browseNode(
          model,
          yamlPathAttr,
          aJsonPath,
          treeNode,
          element.value,
          browser,
        );
      } else if (element.value is List) {
        Map oneOf = {};
        for (var type in element.value) {
          if (type is Map) {
            oneOf.addAll(type);
          }
        }
        _browseNode(model, yamlPathAttr, aJsonPath, treeNode, {
          constTypeOneof: oneOf,
        }, browser);
      }
      i++;
      browser.nbNode++;
    }
  }

  void _initNode(ModelSchemaDetail model, BrowserInfo bi) {
    var nodeAttribut = bi.nodeAttribut;
    var aJsonPath = bi.aJsonPath;
    nodeAttribut.info.treePosition = bi.yamlPathAttr;
    nodeAttribut.info.name = bi.element.key;
    nodeAttribut.info.date = bi.browser.time;

    model.mapInfoByTreePath[bi.yamlPathAttr] = nodeAttribut.info;

    model.mapInfoByName[nodeAttribut.yamlNode.key] ??= [];
    var aMapInfo = model.mapInfoByName[nodeAttribut.yamlNode.key]!;
    if (!aMapInfo.contains(nodeAttribut.info)) {
      aMapInfo.add(nodeAttribut.info);
    }

    var properties = model.getProperties();

    if (nodeAttribut.info.path != '' && nodeAttribut.info.path != aJsonPath) {
      print("path change ${nodeAttribut.info.path} => $aJsonPath");
      properties[aJsonPath] = nodeAttribut.info.properties;
      properties.remove(nodeAttribut.info.path);
      model.mapInfoByJsonPath.remove(nodeAttribut.info.path);
      bi.browser.pathJsonChanged = true;
    }
    model.mapInfoByJsonPath[aJsonPath] = nodeAttribut.info;

    nodeAttribut.info.path = aJsonPath;
    // affecte les properties si 1° fois
    nodeAttribut.info.properties ??= properties[aJsonPath] ?? {};
    if (nodeAttribut.info.properties![constMasterID] == null) {
      var id = nanoid().then((value) {
        nodeAttribut.info.properties?[constMasterID] = value;
      });
      nodeAttribut.info.properties![constMasterID] = id;
    }

    model.allAttributInfo[nodeAttribut.info.hashCode] = nodeAttribut.info;
  }

  AttributInfo? _getNearestAttributNotUsed(
    List<AttributInfo>? list,
    BrowserInfo bi,
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

  GlobalKey keyTree = GlobalKey();

  Widget getTree(TreeNode<NodeAttribut> tree) {
    return TreeView.simple(
      key: keyTree,
      // animation: AlwaysStoppedAnimation(1),
      tree: tree,
      showRootNode: true,
      scrollController: _scrollController,
      expansionIndicatorBuilder:
          (context, node) => ChevronIndicator.rightDown(
            tree: node,
            color: Colors.blue[700],
            padding: const EdgeInsets.all(8),
          ),
      indentation: const Indentation(style: IndentStyle.roundJoint),
      onItemTap: (item) {
        setState(() {});
      },
      onTreeReady: (controller) {
        modelInfo.treeController = controller;
        repaintListView(0);
        Future.delayed(Duration(milliseconds: 500)).then((value) {
          var delay = doToogleNode(0, controller.tree);
          repaintListView(delay);
        });
      },
      builder: (context, node) {
        node.data!.info.type = getTypeStr(
          node.data!.info.name,
          node.data!.yamlNode.value,
        );

        return InkWell(
          key: ObjectKey(node),
          onTap: () {},
          onDoubleTap: () {
            var delay = doToogleNode(0, node);
            repaintListView(delay);
          },
          child: SizedBox(
            height: rowHeight,
            child: Card(
              margin: EdgeInsets.all(1),
              child: Row(
                children: [getAttributHeader(node), getWidgetType(node.data!)],
              ),
            ),
          ),
        );
      },
    );
  }

  void repaintListView(int delay) {
    Future.delayed(Duration(milliseconds: 100)).then((_) {
      keyJsonList.currentState?.setState(() {});
    });
  }

  Widget getAttributHeader(TreeNode<NodeAttribut> node) {
    Widget icon = Container();
    var isRoot = node.isRoot;
    var isObject = node.data!.info.type == 'Object';
    var isOneOf = node.data!.info.type == 'One of';
    var isRef = node.data!.info.type == '\$ref';
    var isArray = node.data!.info.type == 'Array';
    String name = node.data?.yamlNode.key;

    if (isRoot && name == 'Business model') {
      icon = Icon(Icons.business);
    } else if (isRoot) {
      icon = Icon(Icons.lan_outlined);
    } else if (isObject) {
      icon = Icon(Icons.data_object);
    } else if (isRef) {
      icon = Icon(Icons.link);
      name = '\$ref';
    } else if (isOneOf) {
      name = 'One of';
      icon = Icon(Icons.looks_one_rounded);
    } else if (isArray) {
      icon = Icon(Icons.data_array);
    }

    return SizedBox(
      width: 200,
      child: Padding(
        padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
        child: Row(
          children: [
            Padding(padding: EdgeInsets.fromLTRB(0, 0, 5, 0), child: icon),
            Text(
              name,
              style: isObject ? TextStyle(fontWeight: FontWeight.bold) : null,
            ),
          ],
        ),
      ),
    );
  }

  int doToogleNode(int level, TreeNode<NodeAttribut> node) {
    int delay = level;
    if (!node.isExpanded && node.children.isNotEmpty) {
      for (var element in node.childrenAsList) {
        if (!(element as TreeNode).isExpanded && element.children.isNotEmpty) {
          level++;
          level = doToogleNode(level, (element as TreeNode<NodeAttribut>));
        }
      }
    }
    Future.delayed(Duration(milliseconds: delay * 5)).then((_) {
      modelInfo.treeController!.toggleExpansion(node);
    });
    return level;
  }

  Widget getWidgetType(NodeAttribut attr) {
    bool hasError = attr.info.error?[EnumErrorType.errorRef] != null;
    return getChip(Text(attr.info.type), hasError ? Colors.redAccent : null);
  }

  Widget getChip(Widget content, Color? color) {
    return Chip(
      color: WidgetStatePropertyAll(color),
      padding: EdgeInsets.all(0),
      label: content,
    );
  }

  String getTypeStr(String name, dynamic type) {
    String? typeStr;
    if (type is Map) {
      if (name.startsWith(constRefOn)) {
        typeStr = '\$ref';
      } else if (name.startsWith(constTypeOneof)) {
        typeStr = 'One of';
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
      typeStr = 'Int';
    } else if (type is String) {
      if (type.startsWith('\$')) {
        typeStr = 'Object';
      }
    }
    typeStr ??= '$type';
    return typeStr;
  }
}

class JsonTreeConfig {
  JsonTreeConfig({required this.getModel});
  Function getModel;
  late Function getJson;
  late Function getRow;
}
//-------------------------------------------------------------------------------------------

class BrowserInfo {
  BrowserInfo({
    required this.yamlPathAttr,
    required this.nodeAttribut,
    required this.element,
    required this.aJsonPath,
    required this.browser,
  });
  String yamlPathAttr;
  NodeAttribut nodeAttribut;
  MapEntry<dynamic, dynamic> element;
  String aJsonPath;
  ModelBrower browser;
  bool unkwown = false;
}

class NodeAttribut {
  NodeAttribut({required this.yamlNode, required this.info});
  MapEntry<dynamic, dynamic> yamlNode;
  AttributInfo info;
  Widget? cache;
}

class AttributInfo {
  int date = 0;
  String? treePosition;
  String name = '';
  String type = '';
  String path = '';
  Map<String, dynamic>? properties;
  Map<EnumErrorType, AttributError>? error;
}

enum EnumErrorType { errorRef }

class AttributError {
  AttributError({required this.type});
  EnumErrorType type;
}

class ModelInfo {
  ScrollController? scrollController;
  TreeViewController? treeController;
  late JsonTreeConfig config;
}

class ModelBrower {
  late int time;
  bool pathJsonChanged = false;
  int nbNode = 0;
  List<BrowserInfo> unknownAttribut = [];
}
