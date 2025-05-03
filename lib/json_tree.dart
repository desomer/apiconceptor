import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/export/json_browser.dart';
import 'package:jsonschema/json_list.dart';
import 'package:jsonschema/main.dart';

class JsonBrowserWidget extends JsonBrowser {
  late JsonEditorState state;
  late TreeNode<NodeAttribut> rootTree;

  @override
  void onPropertiesChanged() {
    state.repaintListView(100);
  }

  @override
  void onStrutureChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ignore: invalid_use_of_protected_member
      state.setState(() {});
    });
  }

  @override
  dynamic getRoot(NodeAttribut node) {
    rootTree = TreeNode<NodeAttribut>.root(data: node);
    return rootTree;
  }

  @override
  dynamic getChild(NodeAttribut parentNode, NodeAttribut node, dynamic parent) {
    var treeNode = TreeNode(key: node.info.treePosition, data: node);
    (parent as TreeNode).add(treeNode);
    return treeNode;
  }
}


class JsonEditor extends StatefulWidget {
  const JsonEditor({super.key, required this.config});
  final JsonTreeConfig config;

  @override
  State<JsonEditor> createState() => JsonEditorState();
}

class JsonEditorState extends State<JsonEditor>
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
    ModelSchemaDetail? model = (widget.config.getModel() as ModelSchemaDetail?);
    if (model == null) return Text('Select model first');

    var jsonBrowserWidget = JsonBrowserWidget()..state = this;
    jsonBrowserWidget.browse(model, true);
    return getWidget(model, jsonBrowserWidget);
  }

  Row getWidget(ModelSchemaDetail model, JsonBrowserWidget browser) {
    print(
      "nb name = ${model.mapInfoByName.length} nb path = ${model.mapInfoByJsonPath.length}  all info = ${model.allAttributInfo.length}",
    );

    modelInfo.config = widget.config;
    return Row(
      children: [
        SizedBox(width: 400, child: getTree(browser.rootTree)),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: JsonList(key: keyJsonList, modelInfo: modelInfo),
          ),
        ),
      ],
    );
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
        // node.data!.info.type = getTypeStr(
        //   node.data!.info.name,
        //   node.data!.yamlNode.value,
        // );

        return InkWell(
          key: ObjectKey(node),
          onTap: () {},
          onDoubleTap: () {
            var delay = doToogleNode(0, node);
            repaintListView(delay);
          },
          child: SizedBox(
            height: rowHeight,
            child: Row(
              children: [
                getAttributHeader(node),
                Spacer(),
                getWidgetType(node.data!),
                SizedBox(width: 40),
              ],
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
    var isOneOf = node.data!.info.type == '\$anyOf';
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
      name = '\$anyOf';
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

  int doToogleNode(int levelFormTop, TreeNode<NodeAttribut> node) {
    //if (levelFormTop > 1) return levelFormTop;

    int delay = levelFormTop;
    if (!node.isExpanded && node.children.isNotEmpty) {
      for (var element in node.childrenAsList) {
        if (!(element as TreeNode).isExpanded && element.children.isNotEmpty) {
          levelFormTop++;
          levelFormTop = doToogleNode(
            levelFormTop,
            (element as TreeNode<NodeAttribut>),
          );
        }
      }
    }
    Future.delayed(Duration(milliseconds: delay * 5)).then((_) {
      modelInfo.treeController!.toggleExpansion(node);
    });
    return levelFormTop;
  }

  Widget getWidgetType(NodeAttribut attr) {
    bool hasError = attr.info.error?[EnumErrorType.errorRef] != null;
    hasError = hasError || attr.info.error?[EnumErrorType.errorType] != null;
    return getChip(Text(attr.info.type), hasError ? Colors.redAccent : null);
  }

  Widget getChip(Widget content, Color? color) {
    return Chip(
      color: WidgetStatePropertyAll(color),
      padding: EdgeInsets.all(0),
      label: content,
    );
  }

}

class JsonTreeConfig {
  JsonTreeConfig({required this.getModel});
  Function getModel;
  late Function getJson;
  late Function getRow;
}
//-------------------------------------------------------------------------------------------

class ModelInfo {
  ScrollController? scrollController;
  TreeViewController? treeController;
  late JsonTreeConfig config;
}
