import 'package:animated_tree_view/node/node.dart';
import 'package:animated_tree_view/tree_view/tree_node.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/widget/json_editor/widget_json_row.dart';
import 'package:jsonschema/widget/json_editor/widget_json_tree.dart';

class JsonList extends StatefulWidget {
  const JsonList({super.key, required this.modelInfo});
  final TreeListLink modelInfo;
  @override
  State<JsonList> createState() => JsonListState();
}

class JsonListState extends State<JsonList> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  late ListModel<NodeAttribut> _list;

  @override
  void initState() {
    _list = ListModel<NodeAttribut>(
      listKey: _listKey,
      initialItems: <NodeAttribut>[],
      removedItemBuilder: _buildRemovedItem,
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var modelSchemaDetail =
        (widget.modelInfo.config.getModel() as ModelSchemaDetail);
    Future prop = modelSchemaDetail.getProperties();

    return FutureBuilder(
      future: prop,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Text('loading');
        return _getSyncWidget(modelSchemaDetail);
      },
    );
  }

  NodeAttribut? getNodeAttribut(NodeAttribut attr) {
    var result = _list._items;
    for (var i = 0; i < result.length; i++) {
      AttributInfo? a;
      if (result[i] is TreeNode<NodeAttribut>) {
        a = (result[i] as TreeNode<NodeAttribut>).data!.info;
      } else {
        a = (result[i]).info;
      }
      if (a == attr.info) {
        return result[i];
      }
    }
    return null;
  }

  int findInfoOnTree(List<dynamic> result, NodeAttribut? attr) {
    if (attr == null) return -1;
    for (var i = 0; i < result.length; i++) {
      AttributInfo? a;
      if (result[i] is TreeNode<NodeAttribut>) {
        a = (result[i] as TreeNode<NodeAttribut>).data!.info;
      } else {
        a = (result[i] as NodeAttribut).info;
      }
      if (a == attr.info) {
        return i;
      }
    }
    return -1;
  }

  Widget _getSyncWidget(ModelSchemaDetail modelSchemaDetail) {
    _generateModel(modelSchemaDetail);

    return SingleChildScrollView(
      // scroll vertical
      controller: widget.modelInfo.scrollController,
      child: getHorizontal(getList),
    );
  }

  Widget getList(double width) {
    return AnimatedList(
      key: _listKey,
      primary: false,
      shrinkWrap: true,
      initialItemCount: _list.length,
      itemBuilder: (context, index, Animation<double> animation) {
        var dataAttr = _list[index];
        var valueKey = ValueKey(dataAttr.info.masterID);

        if (dataAttr.info.cacheRowWidget != null) {
          return SizeTransition(
            key: valueKey,
            fixedCrossAxisSizeFactor: 1,
            sizeFactor: animation,
            child: Container(
              color: dataAttr.bgcolor,
              width: width - 10,
              height: rowHeight,
              child: dataAttr.info.cacheRowWidget!,
            ),
          );
        }
        return SizeTransition(
          key: valueKey,
          sizeFactor: animation,
          child: Container(
            color: dataAttr.bgcolor,
            width: width - 10,
            height: rowHeight,
            child: _getJsonRowCached(
              dataAttr,
              widget.modelInfo.config.getModel(),
            ),
          ),
        );
      },
    );
  }

  Widget _getJsonRowCached(NodeAttribut attr, ModelSchemaDetail schema) {
    attr.info.cacheRowWidget = WidgetJsonRow(
      node: attr,
      schema: schema,
      fctGetRow: widget.modelInfo.config.getRow,
    );
    return attr.info.cacheRowWidget!;
  }

  Widget getHorizontal(Function fctChild) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var maxWidth = constraints.maxWidth;
        if (maxWidth < 600) {
          maxWidth = 600;
        }
        return Align(
          alignment: Alignment.topLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: maxWidth, child: fctChild(maxWidth)),
          ),
        );
      },
    );
  }

  void getVisibleNode(
    bool visible,
    TreeNode node,
    List<TreeNode> result,
    List<TreeNode> all,
  ) {
    Map<String, Node>? a = node.children as Map<String, Node>?;
    if (a != null) {
      for (var element in a.entries) {
        TreeNode tn = element.value as TreeNode;
        if (visible && node.isExpanded) {
          result.add(tn);
        }
        all.add(tn);
        getVisibleNode(visible, tn, result, all);
      }
    }
  }

  void _generateModel(ModelSchemaDetail modelSchemaDetail) {
    List<TreeNode<NodeAttribut>> result = [];
    List<TreeNode<NodeAttribut>> all = [];
    var tree2 =
        widget.modelInfo.treeController?.tree as TreeNode<NodeAttribut>?;
    if (tree2 != null) {
      result.add(tree2);
      getVisibleNode(true, tree2, result, all);

      if (all.isEmpty && modelSchemaDetail.modelYaml.isNotEmpty) {
        print("************* not change on error ****************");
      } else {
        modelSchemaDetail.reorgProperties(all);
        print(
          'nb list rows = ${result.length} prop = ${modelSchemaDetail.useAttributInfo.length}',
        );
      }
    }

    int ci = 0;
    var remove = <NodeAttribut>[];
    for (var i = 0; i < _list.length; i++) {
      NodeAttribut r = _list[i];
      TreeNode<NodeAttribut>? rc = result.length > ci ? result[ci] : null;
      if (r.info == rc?.data?.info) {
        ci++;
      } else {
        // recherche dans la list
        int idx = findInfoOnTree(_list._items, rc?.data);
        if (idx > -1) {
          for (var j = i; j < idx; j++) {
            remove.add(_list[j]);
          }
          i = idx;
          ci++;
        } else {
          // recherche dans le tree (si fermeture de node) 
          int idx = findInfoOnTree(result, _list._items[i]);
          if (idx > -1) {
            ci = idx + 1;
          } else {
            remove.add(_list[i]);
          }
        }
      }
    }

    for (var element in remove) {
      _remove(element);
    }

    var insert = <NodeAttribut>[];
    var insertIdx = <int>[];
    ci = 0;
    for (var i = 0; i < result.length; i++) {
      var r = result[i].data!;
      var rc = _list.length > ci ? _list[ci] : null;
      if (r.info == rc?.info) {
        ci++;
      } else {
        insert.add(r);
        insertIdx.add(i);
      }
    }

    for (var i = 0; i < insert.length; i++) {
      _insert(insert[i], insertIdx[i]);
    }
  }

  Widget _buildRemovedItem(
    NodeAttribut item,
    BuildContext context,
    Animation<double> animation,
  ) {
    return SizeTransition(
      sizeFactor: animation,
      child: widget.modelInfo.config.getRow(
        item,
        widget.modelInfo.config.getModel(),
      ),
    );
  }

  // Insert the "next item" into the list model.
  void _insert(NodeAttribut nextItem, int after) {
    _list.insert(after, nextItem);
  }

  // Remove the selected item from the list model.
  void _remove(NodeAttribut deleteItem) {
    var indexOf = _list.indexOf(deleteItem);
    if (indexOf != -1) {
      _list.removeAt(indexOf);
      //setState(() {});
    }
  }
}

//-----------------------------------------------------------------------------------------------

typedef RemovedItemBuilder<T> =
    Widget Function(T item, BuildContext context, Animation<double> animation);

class ListModel<E> {
  ListModel({
    required this.listKey,
    required this.removedItemBuilder,
    Iterable<E>? initialItems,
  }) : _items = List<E>.from(initialItems ?? <E>[]);

  final GlobalKey<AnimatedListState> listKey;
  final RemovedItemBuilder<E> removedItemBuilder;
  final List<E> _items;

  AnimatedListState? get _animatedList => listKey.currentState;

  void insert(int index, E item) {
    _items.insert(index, item);
    _animatedList?.insertItem(index, duration: Duration(milliseconds: 150));
  }

  E removeAt(int index) {
    final E removedItem = _items.removeAt(index);
    if (removedItem != null) {
      _animatedList!.removeItem(index, (
        BuildContext context,
        Animation<double> animation,
      ) {
        return removedItemBuilder(removedItem, context, animation);
      }, duration: Duration(milliseconds: 150));
    }
    return removedItem;
  }

  int get length => _items.length;

  E operator [](int index) => _items[index];

  int indexOf(E item) => _items.indexOf(item);

  List<E> get items => _items;
}
