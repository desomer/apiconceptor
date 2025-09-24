import 'dart:async';

import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/widget/tree_editor/widget_json_list.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/tree_editor/widget_json_row.dart';
import 'package:jsonschema/widget/widget_split.dart';

class JsonBrowserWidget extends JsonBrowser {
  late JsonListEditorState state;
  late TreeNode<NodeAttribut> rootTree;

  List<String>? pathFilter;

  double maxSize = 300;

  void gotoPath(ModelSchema model, String path) {
    AttributInfo? node;
    for (var element in model.useAttributInfo) {
      var p = element.path.replaceAll('>$constTypeAnyof', '');
      if (p == path) {
        node = element;
        break;
      }
    }

    if (node != null) {
      var n = findNode(node);
      if (n != null) {
        state.modelInfo.treeController?.scrollToItem(n);
      }
    }
  }

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
  dynamic getChild(ModelSchema model, NodeAttribut parentNode, NodeAttribut node, dynamic parent) {
    if (pathFilter != null) {
      var find = false;
      for (var element in pathFilter!) {
        if (element.startsWith(node.info.path)) {
          find = true;
          break;
        }
      }
      if (!find) return null;
    }

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
  var keyJsonList = GlobalKey<JsonListState>(debugLabel: 'keyJsonList');
  GlobalKey keyTree = GlobalKey(debugLabel: 'keyTree');

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

  String queryFilter = '';
  List<String>? pathFilter;
  Timer? _debounce;

  @override
  Widget build(BuildContext context) {
    stateOpenFactor?.setList(this);

    ModelSchema? model = (widget.config.getModel() as ModelSchema?);
    if (model == null) return Text('Select model first');

    widget.config.textConfig?.treeJsonState = this;

    var jsonBrowserWidget =
        JsonBrowserWidget()
          ..state = this
          ..pathFilter = pathFilter;

    NodeBrower browser = jsonBrowserWidget.browse(model, true);
    model.lastBrowser = browser;
    model.lastJsonBrowser = jsonBrowserWidget;
    repaintListView(0, 'build');

    return Column(
      children: [
        Row(children: [getFilter(model)]),
        Expanded(child: getWidget(model, browser, jsonBrowserWidget)),
      ],
    );
  }

  void _onSearchChanged(ModelSchema model, String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        queryFilter = query;
        if (query == '') {
          pathFilter = null;
        } else {
          pathFilter = [];
          List<String> filters = query.split(' ');
          for (var element in model.useAttributInfo) {
            for (var f in filters) {
              f = f.trim();
              if (f != '') {
                if (element.name.toLowerCase().contains(f.toLowerCase())) {
                  pathFilter!.add(element.path);
                } else if (element.properties != null) {
                  for (var propValue in element.properties!.values.toList()) {
                    if (propValue.toString().toLowerCase().contains(
                      f.toLowerCase(),
                    )) {
                      pathFilter!.add(element.path);
                      break;
                    }
                  }
                }
              }
            }
          }
          keyTree = GlobalKey(
            debugLabel: 'keyTree',
          ); // change le widget en change la key
        }
      });
    });
  }

  Widget getFilter(ModelSchema model) {
    return SizedBox(
      width: 300,
      height: 30,
      child: TextField(
        onChanged: (value) {
          _onSearchChanged(model, value);
        },
        decoration: InputDecoration(
          contentPadding: EdgeInsets.all(0),
          hintText: 'Filtrer',
          prefixIcon: Icon(Icons.search),
        ),
      ),
    );
  }

  Widget getWidget(
    ModelSchema model,
    NodeBrower browser,
    JsonBrowserWidget jsonBrowserWidget,
  ) {
    print(
      "tree nb name = ${model.mapInfoByName.length} nb path = ${model.mapInfoByJsonPath.length}  all info = ${model.allAttributInfo.length}",
    );

    //print(browser.nbLevelMax);

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
        toogleAllNode(controller);
      },
      builder: (context, node) {
        if (node.data!.info.cacheHeaderWidget == null ||
            node.data!.info.cacheHeight != rowHeight) {
          node.data!.info.cacheHeaderWidget = getRow(node, aModel, context);
        }
        return node.data!.info.cacheHeaderWidget!;
      },
    );
  }

  void toogleAllNode(
    TreeViewController<NodeAttribut, TreeNode<NodeAttribut>> controller,
  ) {
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
  }

  void openAllNode() {
    repaintListView(0, 'onTreeReady');
    // chargement aprés le scroll du TAB
    Future.delayed(Duration(milliseconds: 500)).then((value) {
      ModelSchema? model = (widget.config.getModel() as ModelSchema?);
      var jb = model!.lastJsonBrowser as JsonBrowserWidget;

      var nbLevelFromTop = doOpenNode(
        0,
        jb.rootTree,
        0,
        max: openFactor.value.toInt(),
      );
      repaintListView(nbLevelFromTop, 'doToogleNode onTreeReady');
    });
  }

  Widget getRow(
    TreeNode<NodeAttribut> node,
    ModelSchema aModel,
    BuildContext context,
  ) {
    node.data!.info.cacheHeight = rowHeight;
    var canDoubleTap = (!node.isLeaf || widget.config.onDoubleTap != null);

    return InkWell(
      key: ObjectKey(node.data),
      onTap: () {
        if (widget.config.onTap != null && node.data != null) {
          var ret = widget.config.onTap!(node.data!, context);
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
            aModel.infoManager.getAttributHeaderOLD(node),
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

  int doOpenNode(
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
          levelFormTop = doOpenNode(
            levelFormTop,
            (element as TreeNode<NodeAttribut>),
            level + 1,
            max: max,
          );
        }
      }
    }
    Future.delayed(Duration(milliseconds: delay * 500)).then((_) {
      if (mounted) modelInfo.treeController!.expandNode(node);
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

typedef OnTap = bool Function(NodeAttribut attr, BuildContext context);
typedef GetRow =
    void Function(NodeAttribut attr, ModelSchema schema, BuildContext context);

class JsonTreeConfig {
  JsonTreeConfig({
    required this.textConfig,
    required this.getModel,
    required this.onTap,
    this.onDoubleTap,
  });
  Function getModel;
  late Function getJson;
  late GetRow getRow;
  // int widthTree = 350;
  OnTap? onTap;
  Function? onDoubleTap;
  CodeEditorConfig? textConfig;
}

//-------------------------------------------------------------------------------------------

class TreeListLink {
  ScrollController? scrollController;
  TreeViewController? treeController;
  late JsonTreeConfig config;
}
