import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/widget/json_editor/widget_json_list.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/widget/json_editor/widget_json_row.dart';
import 'package:jsonschema/widget/widget_split.dart';

class JsonBrowserWidget extends JsonBrowser {
  late JsonListEditorState state;
  late TreeNode<NodeAttribut> rootTree;

  double maxSize = 300;

  void reloadAll(NodeAttribut? node) {
    node?.repaint();
    // ignore: invalid_use_of_protected_member
    state.setState(() {});
    // ignore: invalid_use_of_protected_member
    //state.keyTree.currentState?.setState(() {});
    // ignore: invalid_use_of_protected_member
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ignore: invalid_use_of_protected_member
      state.keyJsonList.currentState?.setState(() {});
    });
  }

  @override
  void onPropertiesChanged() {
    state.repaintListView(100, 'onPropertiesChanged');
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
    double sizeType = node.info.type.length * 9 * (zoom.value / 100);
    double size =
        (node.info.name.length * 10 * (zoom.value / 100)) +
        (node.level * 40) +
        sizeType;

    if (maxSize < size) {
      maxSize = size;
    }

    var treeNode = TreeNode(key: node.info.treePosition, data: node);
    if (!parentNode.addChildAsync) {
      (parent as TreeNode).add(treeNode);
    } else {
      parentNode.addChildAsync = false;
      (parent as TreeNode).add(treeNode);

      // gestion du chargemnt différé des enfants

      WidgetsBinding.instance.addPostFrameCallback((_) {
        Node? n = findNode(parentNode.info);
        n as TreeNode;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (n.isExpanded) {
            state.modelInfo.treeController!.collapseNode(n);
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            state.modelInfo.treeController!.expandAllChildren(n);
            // ignore: invalid_use_of_protected_member
            state.keyJsonList.currentState?.setState(() {});
          });
        });

        //n?.add(treeNode);
        //state.setState(() {});
        // print("later");
        // if (parent.isExpanded) {
        //   state.modelInfo.treeController!.toggleExpansion(parent);
        // }
      });
    }
    return treeNode;
  }

  TreeNode<NodeAttribut>? findNode(AttributInfo info) {
    var tree2 = state.modelInfo.treeController?.tree as TreeNode<NodeAttribut>?;
    Map<String, Node>? a = tree2!.children as Map<String, Node>?;
    var n = _find(a, info);
    return n;
  }

  TreeNode<NodeAttribut>? _find(Map<String, Node>? child, AttributInfo info) {
    if (child == null) return null;
    for (var element in child.entries) {
      var v = element.value as TreeNode<NodeAttribut>;
      if (v.data!.info == info) {
        return v;
      }
      var ret = _find(v.children, info);
      if (ret != null) return ret;
    }
    return null;
  }

  @override
  void onRowTypeChange(ModelSchema model, NodeAttribut node) {
    super.onRowTypeChange(model, node);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // var attr = state.keyJsonList.currentState?.getNodeAttribut(node);
      // attr?.repaint();
      if (node.info.cacheRowWidget is WidgetJsonRow) {
        (node.info.cacheRowWidget as WidgetJsonRow).cache = null;
        (node.info.cacheRowWidget as WidgetJsonRow).node.repaint();
      }
    });
    node.info.cacheHeaderWidget = null;
  }
}

//******************************************************************************/
class JsonListEditor extends StatefulWidget {
  const JsonListEditor({super.key, required this.config});
  final JsonTreeConfig config;

  @override
  State<JsonListEditor> createState() => JsonListEditorState();
}

class JsonListEditorState extends State<JsonListEditor>
    with SingleTickerProviderStateMixin {
  late AutoScrollController _scrollController;

  TreeListLink modelInfo = TreeListLink();
  var keyJsonList = GlobalKey<JsonListState>();
  GlobalKey keyTree = GlobalKey();

  @override
  initState() {
    _scrollController = AutoScrollController();
    modelInfo.scrollController = ScrollController();
    _scrollController.addListener(() {
      if (modelInfo.scrollController!.offset != _scrollController.offset) {
        modelInfo.scrollController!.jumpTo(_scrollController.offset);
      }
    });
    modelInfo.scrollController!.addListener(() {
      if (modelInfo.scrollController!.offset != _scrollController.offset) {
        _scrollController.jumpTo(modelInfo.scrollController!.offset);
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    modelInfo.scrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    stateOpenFactor?.setList(this);

    ModelSchema? model = (widget.config.getModel() as ModelSchema?);
    if (model == null) return Text('Select model first');

    widget.config.textConfig?.treeJsonState = this;

    var jsonBrowserWidget = JsonBrowserWidget()..state = this;

    ModelBrower browser = jsonBrowserWidget.browse(model, true);
    model.lastBrowser = browser;
    model.lastJsonBrowser = jsonBrowserWidget;
    repaintListView(0, 'build');

    return getWidget(model, browser, jsonBrowserWidget);
  }

  Widget getWidget(
    ModelSchema model,
    ModelBrower browser,
    JsonBrowserWidget jsonBrowserWidget,
  ) {
    print(
      "tree nb name = ${model.mapInfoByName.length} nb path = ${model.mapInfoByJsonPath.length}  all info = ${model.allAttributInfo.length}",
    );

    print(browser.nbLevelMax);

    modelInfo.config = widget.config;
    return SplitView(
      primaryWidth: jsonBrowserWidget.maxSize,
      children: [
        getTree(model, jsonBrowserWidget.rootTree),
        Align(
          alignment: Alignment.topCenter,
          child: JsonList(key: keyJsonList, modelInfo: modelInfo),
        ),
      ],
    );
    // return Row(
    //   children: [
    //     SizedBox(
    //       width:
    //           jsonBrowserWidget
    //               .maxSize, //widget.config.widthTree + (browser.nbLevelMax * 20),
    //       child: getTree(model, jsonBrowserWidget.rootTree),
    //     ),
    //     Expanded(
    //       child: Align(
    //         alignment: Alignment.topCenter,
    //         child: JsonList(key: keyJsonList, modelInfo: modelInfo),
    //       ),
    //     ),
    //   ],
    // );
  }

  Widget getTree(ModelSchema aModel, TreeNode<NodeAttribut> tree) {
    return TreeView.simple(
      expansionBehavior: ExpansionBehavior.none,
      key: keyTree,
      // animation: AlwaysStoppedAnimation(1),
      tree: tree,
      showRootNode: true,
      scrollController: _scrollController,
      expansionIndicatorBuilder:
          (context, node) => ChevronIndicator.rightDown(
            tree: node,
            color: Colors.blue[700],
            padding: const EdgeInsets.fromLTRB(5, 0, 10, 0),
          ),
      indentation: const Indentation(style: IndentStyle.roundJoint),
      onItemTap: (item) {
        setState(() {});
      },
      onTreeReady: (controller) {
        modelInfo.treeController = controller;
        repaintListView(0, 'onTreeReady');
        // chargement aprés le scroll du TAB
        Future.delayed(Duration(milliseconds: 500)).then((value) {
          var nbLevelFromTop = doToogleNode(
            0,
            controller.tree,
            0,
            max: openFactor.value.toInt(),
          );
          repaintListView(nbLevelFromTop, 'doToogleNode onTreeReady');
        });
      },
      builder: (context, node) {
        if (node.data!.info.cacheHeaderWidget == null ||
            node.data!.info.cacheHeight != rowHeight) {
          node.data!.info.cacheHeaderWidget = getRow(node, aModel);
        }
        return node.data!.info.cacheHeaderWidget!;
      },
    );
  }

  Widget getRow(TreeNode<NodeAttribut> node, ModelSchema aModel) {
    node.data!.info.cacheHeight = rowHeight;
    var canDoubleTap = (!node.isLeaf || widget.config.onDoubleTap != null);

    return InkWell(
      key: ObjectKey(node.data),
      onTap: () {
        if (widget.config.onTap != null) {
          var ret = widget.config.onTap!(node.data);
          if (ret == true) {
            repaintListView(0, 'onTap');
          }
        }
      },

      onDoubleTap:
          canDoubleTap
              ? () {
                if (widget.config.onDoubleTap != null) {
                  widget.config.onDoubleTap!(node.data);
                }
                var delay = doToogleNode(
                  0,
                  node,
                  0,
                  max: openFactor.value.toInt(),
                );
                repaintListView(delay, 'doToogleNode onDoubleTap');
              }
              : null,
      child: Container(
        color: node.data?.bgcolor,
        height: rowHeight,
        child: Row(
          children: [
            aModel.infoManager.getAttributHeader(node),
            Spacer(),
            getWidgetType(node.data!),
            SizedBox(width: 40),
          ],
        ),
      ),
    );
  }

  void repaintListView(int delay, String cause) {
    print('repaint list $cause delay $delay');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(Duration(milliseconds: 100 + delay)).then((_) {
        keyJsonList.currentState?.setState(() {});
      });
    });
  }

  int doZoomNode(
    bool open,
    int levelFormTop,
    TreeNode<NodeAttribut> node,
    int level, {
    int max = -1,
  }) {
    if (open && max >= 0 && level >= max) return levelFormTop;

    int delay = levelFormTop;
    if (node.children.isNotEmpty) {
      for (var element in node.childrenAsList) {
        if (element.children.isNotEmpty) {
          levelFormTop++;
          levelFormTop = doZoomNode(
            open,
            levelFormTop,
            (element as TreeNode<NodeAttribut>),
            level + 1,
            max: max,
          );
        }
      }
    }
    if (!open && level < max) return levelFormTop;

    Future.delayed(Duration(milliseconds: delay * 5)).then((_) {
      if (mounted && open) modelInfo.treeController!.expandNode(node);
      if (mounted && !open) modelInfo.treeController!.collapseNode(node);
    });
    return levelFormTop;
  }

  int doToogleNode(
    int levelFormTop,
    TreeNode<NodeAttribut> node,
    int level, {
    int max = -1,
  }) {
    if (max >= 0 && level >= max) return levelFormTop;

    int delay = levelFormTop;
    if (!node.isExpanded && node.children.isNotEmpty) {
      for (var element in node.childrenAsList) {
        if (!(element as TreeNode).isExpanded && element.children.isNotEmpty) {
          levelFormTop++;
          levelFormTop = doToogleNode(
            levelFormTop,
            (element as TreeNode<NodeAttribut>),
            level + 1,
            max: max,
          );
        }
      }
    }
    Future.delayed(Duration(milliseconds: delay * 5)).then((_) {
      if (mounted) modelInfo.treeController!.toggleExpansion(node);
    });
    return levelFormTop;
  }

  Widget getWidgetType(NodeAttribut attr) {
    bool hasError = attr.info.error?[EnumErrorType.errorRef] != null;
    hasError = hasError || attr.info.error?[EnumErrorType.errorType] != null;
    String msg = hasError ? 'string\nnumber\nboolean\n\$type' : '';

    return Tooltip(
      message: msg,
      child: getChip(Text(attr.info.type), hasError ? Colors.redAccent : null),
    );
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
  JsonTreeConfig({
    required this.textConfig,
    required this.getModel,
    required this.onTap,
    this.onDoubleTap,
  });
  Function getModel;
  late Function getJson;
  late Function getRow;
  // int widthTree = 350;
  Function? onTap;
  Function? onDoubleTap;
  TextConfig? textConfig;
}
//-------------------------------------------------------------------------------------------

class TreeListLink {
  ScrollController? scrollController;
  TreeViewController? treeController;
  late JsonTreeConfig config;
}
