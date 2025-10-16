import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_hover.dart';
import 'package:jsonschema/widget/widget_overflow.dart';

class TreeNodeData<T> {
  List<TreeNodeData<T>>? children;
  bool isExpanded;
  late int depth;
  late List<bool> lastChild;
  bool isLast = false;
  bool isRoot = false;
  Color? bgColor;

  int timeChange = 0;
  bool isToogleRequested = false;
  bool isInvisibleRequested = false;
  T data;

  ValueNotifier<int> changed = ValueNotifier(0);
  ValueNotifier<int> selected = ValueNotifier(0);

  String? rowCacheKey;
  Widget? rowCache;
  int numUpdate = 0;

  TreeViewState? stateCache;
  late TreeViewState tree;

  TreeNodeData({required this.data, this.children, this.isExpanded = true});

  void setCache(String key, {bool force = false}) {
    if (rowCacheKey != key || force) {
      rowCache = null;
    }
    rowCacheKey = key;
  }

  List<TreeNodeData<T>>? childrenToClear;
  void _reinitChild() {
    if (children != null) {
      childrenToClear = [...children!];
    } else {
      childrenToClear = null;
    }
    children = null;
  }

  void reinitRoot() {
    _reinitChild();
  }

  void doTapHeader() {
    tree.doTapHeader(this);
  }

  void doToogleChild() {
    tree.doToogle(this);
  }

  TreeNodeData<T> exist(T data, Function exist) {
    late TreeNodeData<T> v;
    if (childrenToClear != null) {
      v = childrenToClear!.firstWhere(
        (e) => exist(e.data) == exist(data),
        orElse: () => TreeNodeData(data: data),
      );

      childrenToClear!.remove(v);
      v._reinitChild();
    } else {
      v = TreeNodeData(data: data);
    }
    return v;
  }

  void add(TreeNodeData<T> child) {
    children ??= [];
    children!.add(child);
  }
}

typedef GetNode<T> = TreeViewData<T> Function();
typedef GetWidget<Y> = Widget Function(TreeNodeData<Y> node);
typedef OnTap<T> = void Function(TreeNodeData<T> node, BuildContext ctx);
typedef OnBuild<T> = void Function(TreeViewState<T> state, BuildContext ctx);
typedef IsSelected<T> =
    bool Function(
      TreeNodeData<T> node,
      State? current,
      State? oldSelectedState,
    );

class TreeViewData<T> {
  final List<TreeNodeData<T>> nodes;
  final double headerSize;

  TreeViewData({required this.nodes, required this.headerSize});
}

class TreeView<T> extends StatefulWidget {
  const TreeView({
    super.key,
    required this.getNodes,
    required this.getHeader,
    required this.getDataRow,
    this.onBuild,
    this.onTapHeader,
    required this.isSelected,
  });

  final GetNode<T> getNodes;
  final GetWidget<T> getHeader;
  final GetWidget<T> getDataRow;
  final OnTap<T>? onTapHeader;
  final OnBuild<T>? onBuild;
  final IsSelected<T> isSelected;

  @override
  State<TreeView> createState() => TreeViewState<T>();
}

class TreeViewState<T> extends State<TreeView<T>> {
  double headerSize = -1;
  int animateDelay = 200;
  //double height = 30.0;

  IndentInfo indent = IndentInfo(
    indent: 30,
    start: 12,
    end: 5,
    height: 30.0,
    color: Colors.white38,
  );

  int timeBuild = 0;
  final ScrollController _scrollController = ScrollController();
  late BuildContext ctx;
  int repaintInProgess = 0;
  int dragInProgess = 0;
  bool isDisposed = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    print("dispose");
    isDisposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ctx = context;
    if (widget.onBuild != null) {
      widget.onBuild!(this, ctx);
    }

    TreeViewData<T> data = widget.getNodes();

    List<TreeNodeData<T>> nodes = data.nodes;

    NodeStack stack = NodeStack();
    List<TreeNodeData<T>> list = _flattenNodeTree(stack, 0, nodes);

    var ret = ValueListenableBuilder(
      valueListenable: zoom,
      // pour appel durant le changement de zoom
      builder: (context, value, child) {
        timeBuild = DateTime.now().millisecondsSinceEpoch;
        if (headerSize == -1 ||
            (headerSize < data.headerSize && dragInProgess == 0)) {
          headerSize = data.headerSize;
          repaintInProgess = timeBuild;
          if (headerSize < 200) headerSize = 200;
        }
        return Scrollbar(
          controller: _scrollController,
          thumbVisibility: true, // ✅ Toujours visible sur desktop
          child: ListView.builder(
            primary: false,
            controller: _scrollController,
            shrinkWrap: true,
            itemCount: list.length,
            itemBuilder: (context, index) {
              var node = list[index];
              node.tree = this;
              var row = _getAnimatedHeightRow(
                node,
                _buildNode(context, node),
                ValueKey('${node.hashCode}#header'),
              );
              return row;
            },
          ),
        );
      },
    );

    return ret;
  }

  List<TreeNodeData<T>> _flattenNodeTree(
    NodeStack stack,
    int deep,
    List<TreeNodeData<T>> nodes,
  ) {
    List<TreeNodeData<T>> result = [];
    for (var node in nodes) {
      node.depth = deep;
      node.isRoot = deep == 0;
      node.isLast = node == nodes.last;
      result.add(node);
      var r = <bool>[];
      for (var i = 0; i < stack.stack.length; i++) {
        r.add(stack.stack[i].isLast);
      }
      node.lastChild = r;
      stack.push(node);

      if (node.children != null &&
          node.children!.isNotEmpty &&
          node.isExpanded) {
        result.addAll(_flattenNodeTree(stack, deep + 1, node.children!));
      }
      stack.pop();
    }

    return result;
  }

  State? rowSelectedState;

  Widget getHover(TreeNodeData<T> attr, Widget child) {
    return HoverableCard(
      isSelected: (State state) {
        bool isSelected = widget.isSelected(attr, state, rowSelectedState);
        if (isSelected) {
          if (state != rowSelectedState) {
            var old = rowSelectedState;
            SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
              if (old?.mounted == true) {
                // ignore: invalid_use_of_protected_member
                old?.setState(() {});
              }
            });
          }
          rowSelectedState = state;
        }
        return isSelected;
      },
      child: child,
    );
  }

  void doTapHeader(TreeNodeData<T> node) {
    if (widget.onTapHeader case final OnTap<T> on) {
      on(node, ctx);
    }
  }

  void doToogle(TreeNodeData<T> node) {
    setState(() {
      if (node.children != null && node.children!.isNotEmpty) {
        if (node.isExpanded == false) {
          node.isExpanded = true;
          node.isToogleRequested = false;
        } else {
          node.isToogleRequested = true;
          node.timeChange = DateTime.now().millisecondsSinceEpoch;
        }

        _toogleChildren(node, node.isToogleRequested);
      }
    });
  }

  // Widget _getJsonRowCached(NodeAttribut attr, ModelSchema schema) {
  //   int time = DateTime.now().millisecondsSinceEpoch;
  //   if (dataAttr.info.cacheRowWidget != null && time - timezoom > 300) {
  //     cell = dataAttr.info.cacheRowWidget!;
  //   } else {
  //     cell = _getJsonRowCached(dataAttr, widget.modelInfo.config.getModel());
  //   }

  //   attr.info.cacheRowWidget = WidgetJsonRow(
  //     node: attr,
  //     schema: schema,
  //     fctGetRow: widget.modelInfo.config.getRow,
  //   );
  //   return attr.info.cacheRowWidget!;
  // }

  Widget _buildNode(BuildContext context, TreeNodeData<T> node) {
    return Stack(
      children: [
        getHover(node, _getRowCached(node)),
        if (node.depth > 0)
          Positioned(
            left: 0,
            top: 0,
            child: TreeConnector(node: node, indentInfo: indent),
          ),
      ],
    );
  }

  Widget _getRowCached(TreeNodeData<T> node) {
    int numUpdate = 0;
    if (node.data is NodeAttribut) {
      numUpdate = (node.data as NodeAttribut).info.numUpdateForKey;
    }

    if (node.rowCache == null ||
        node.stateCache != this ||
        timeBuild - repaintInProgess < 500 ||
        timeBuild - timezoom < 500 ||
        numUpdate != node.numUpdate) {
      node.numUpdate = numUpdate;
      node.stateCache = this;
      node.rowCache = _getRow(node);
    }
    return node.rowCache!;
  }

  Widget _getRow(TreeNodeData<T> node) {
    return Container(
      color: node.bgColor,
      height: rowHeight,
      //width:  300,
      padding: EdgeInsets.only(left: indent.indent * node.depth, right: 10),
      child: NoOverflowErrorFlex(
        direction: Axis.horizontal,
        children: [
          SizedBox(
            width: headerSize - indent.indent * node.depth,
            child: widget.getHeader(node),
          ),
          _getBtnToogle(node, node.isExpanded),
          _getDrag(rowHeight),
          Expanded(child: widget.getDataRow(node)),
        ],
      ),
    );
  }

  Widget _getDrag(double height) {
    return Draggable<String>(
      onDragUpdate: (details) {
        setState(() {
          repaintInProgess = DateTime.now().millisecondsSinceEpoch;
          dragInProgess = DateTime.now().millisecondsSinceEpoch;
          headerSize = headerSize + details.delta.dx;
          if (headerSize < 100) {
            headerSize = 100;
          }
        });
      },
      data: '',
      feedback: SizedBox(width: 10, height: height),
      childWhenDragging: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        hitTestBehavior: HitTestBehavior.opaque,
        child: SizedBox(width: 10, height: height),
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        hitTestBehavior: HitTestBehavior.opaque,
        child: SizedBox(width: 10, height: height),
      ),
    );
  }

  void _toogleChildren(TreeNodeData node, bool invisible) {
    for (var element in node.children ?? const <TreeNodeData>[]) {
      if (invisible) {
        element.isInvisibleRequested = invisible;
      } else {
        element.isInvisibleRequested = false;
        element.isExpanded = true;
      }
      element.timeChange = DateTime.now().millisecondsSinceEpoch;
      _toogleChildren(element, invisible);
    }
  }

  Widget _getBtnToogle(TreeNodeData<T> node, bool expanded) {
    return InkWell(
      onTap: () {
        doToogle(node);
      },
      child: SizedBox(
        width: 40,
        child:
            node.children?.isNotEmpty == true
                ? Icon(
                  expanded ? Icons.arrow_drop_down : Icons.arrow_right_sharp,
                )
                : const Text(''),
      ),
    );
  }

  Widget _getAnimatedHeightRow(TreeNodeData node, Widget child, Key key) {
    if (timeBuild - node.timeChange < 500) {
      node.timeChange = 0;
      if (node.isToogleRequested) {
        node.isToogleRequested = false;

        Future.delayed(Duration(milliseconds: animateDelay)).then((value) {
          setState(() {
            // les ligne sont retirer de la fin
            node.isExpanded = false;
          });
        });

        return ClipRect(
          key: key,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: animateDelay),
            builder: (context, value, child) {
              return child!;
            },
            child: child,
          ),
        );
      }

      return ClipRect(
        key: key,
        child: TweenAnimationBuilder<double>(
          tween:
              node.isInvisibleRequested
                  ? Tween(begin: 1, end: 0)
                  : Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: animateDelay),
          builder: (context, value, child) {
            return Align(heightFactor: value, child: child);
          },
          onEnd: () {
            if (node.isInvisibleRequested) {
              node.isExpanded = true;
            }
            node.isInvisibleRequested = false;
          },
          child: child,
        ),
      );
    } else {
      return child;
    }
  }
}

class IndentInfo {
  final double indent;
  final double start;
  final double end;
  final double height;
  final Color color;

  IndentInfo({
    required this.height,
    required this.color,
    required this.indent,
    required this.start,
    required this.end,
  });
}

class TreeConnector extends StatelessWidget {
  final TreeNodeData node;
  final IndentInfo indentInfo;

  const TreeConnector({
    super.key,
    required this.indentInfo,
    required this.node,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(node.depth * indentInfo.indent, indentInfo.height),
      painter: _TreeConnectorPainter(indentInfo: indentInfo, node: node),
    );
  }
}

class _TreeConnectorPainter extends CustomPainter {
  final TreeNodeData node;
  final IndentInfo indentInfo;

  _TreeConnectorPainter({required this.indentInfo, required this.node});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = indentInfo.color
          ..strokeWidth = 1.5;

    var indentPix = indentInfo.indent * (node.depth - 1);

    final midY = size.height / 2;
    final startX = indentPix + indentInfo.start;
    final endX = indentPix + indentInfo.indent - indentInfo.end;

    // Trait vertical : ajusté si dernier
    final topY = 0.0;
    final bottomY = node.isLast ? midY : size.height;

    canvas.drawLine(Offset(startX, topY), Offset(startX, bottomY), paint);

    // Trait horizontal
    canvas.drawLine(Offset(startX, midY), Offset(endX, midY), paint);
    indentPix = indentInfo.start;
    // print('${node.data} >  ${node.lastChild}');
    for (var i = 1; i < node.lastChild.length; i++) {
      indentPix = indentPix + indentInfo.indent;
      if (!node.lastChild[i]) {
        final startX = indentPix - indentInfo.indent;
        final bottomY = size.height;
        canvas.drawLine(Offset(startX, topY), Offset(startX, bottomY), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class NodeStack {
  final List<TreeNodeData> stack = [];

  void push(TreeNodeData value) {
    stack.add(value);
  }

  TreeNodeData pop() {
    if (stack.isEmpty) {
      throw StateError('La pile est vide');
    }
    return stack.removeLast();
  }

  TreeNodeData peek() {
    if (stack.isEmpty) {
      throw StateError('La pile est vide');
    }
    return stack.last;
  }

  bool get isEmpty => stack.isEmpty;

  int get length => stack.length;

  void clear() => stack.clear();
}
