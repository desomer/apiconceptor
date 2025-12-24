import 'package:flutter/material.dart';

class DroppableListView<T extends Object, D extends Object>
    extends StatefulWidget {
  final List<T> initialItems;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final T Function(DragTargetDetails data) onDropConvert;
  final Axis scrollDirection;
  final Function(T item) onItemRemoved;

  const DroppableListView({
    super.key,
    required this.initialItems,
    required this.itemBuilder,
    required this.onDropConvert,
    this.scrollDirection = Axis.vertical,
    required this.onItemRemoved,
  });

  @override
  State<DroppableListView<T, D>> createState() =>
      _DroppableListViewState<T, D>();
}

class _DroppableListViewState<T extends Object, D extends Object>
    extends State<DroppableListView<T, D>> {
  late List<T> items;

  @override
  void initState() {
    super.initState();
    items = widget.initialItems;
    for (var item in items) {
      _keys[item.hashCode] = GlobalKey();
    }
  }

  void _insertAt(int index, DragTargetDetails data) {
    setState(() {
      var element = widget.onDropConvert(data);
      var i = items.indexOf(element);
      if (i != -1) {
        items.removeAt(i);
        if (i < index) {
          index -= 1;
        }
      }
      items.insert(index, element);
    });
  }

  final Map<int, GlobalKey> _keys = {};
  final Map<int, double> _positions = {};

  @override
  void didUpdateWidget(covariant DroppableListView<T, D> oldWidget) {
    super.didUpdateWidget(oldWidget);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePositions();
    });
  }

  double max = 0;

  void _updatePositions() {
    // Ajouter les nouvelles clés si nécessaire
    for (var item in items) {
      _keys.putIfAbsent(item.hashCode, () => GlobalKey());
    }

    final newPositions = <int, double>{};
    //var findRenderObject = listKey.currentContext?.findRenderObject();
    double pos = 12.0;
    bool hasChanged = false;
    for (var item in items) {
      final key = _keys[item.hashCode]!;
      final context = key.currentContext;
      if (context != null) {
        final box = context.findRenderObject() as RenderBox;
        // final offset = box.localToGlobal(
        //   Offset.zero,
        //   ancestor: findRenderObject,
        // );
        newPositions[item.hashCode] = pos;
        if (_positions[item.hashCode] != pos) {
          hasChanged = true;
        }
        pos += box.size.height;
      } else {
        newPositions[item.hashCode] = pos;
        pos += 48;
      }
    }

    final context = last.currentContext;
    if (context != null) {
      newPositions[last.hashCode] = pos;
      if (_positions[last.hashCode] != pos) {
        hasChanged = true;
      }
    }
    max = pos;

    if (hasChanged) {
      setState(() {
        _positions.clear();
        _positions.addAll(newPositions);
      });
    }
  }

  GlobalKey last = GlobalKey();
  GlobalKey last2 = GlobalKey();
  GlobalKey listKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updatePositions();
        });

        return SizedBox(
          height: constraints.maxHeight,
          child: Stack(
            key: listKey,
            children: [
              for (var item in items)
                AnimatedPositioned(
                  key: ValueKey(item),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  top: _positions[item.hashCode] ?? max,
                  left: 0,
                  right: 0,
                  child: Container(
                    key: _keys[item.hashCode],
                    child: getRow(item, items),
                  ),
                ),
              AnimatedPositioned(
                key: last2,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                top: _positions[last.hashCode] ?? max,
                left: 0,
                right: 0,
                child: Container(key: last, child: getRow(null, items)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget getRow(T? item, List<T> items) {
    if (item == null) {
      return _DropZone<T, D>(
        onAccept: (data) => _insertAt(items.length, data),
        isLast: true,
      );
    } else {
      final itemIndex = items.indexOf(item);
      return Stack(
        children: [
          getDrop(item, widget.itemBuilder(context, item, itemIndex)),
          Positioned(
            top: 16,
            right: 10,
            child: InkWell(onTap: () {
              setState(() {
                items.removeAt(itemIndex);
                widget.onItemRemoved(item);
              });
            }, child: Icon(Icons.delete)),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Transform.translate(
              offset: const Offset(0, -12),
              child: _DropZone<T, D>(
                onAccept: (data) => _insertAt(itemIndex, data),
                isLast: false,
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Transform.translate(
              offset: const Offset(0, 14),
              child: _DropZone<T, D>(
                onAccept: (data) => _insertAt(itemIndex + 1, data),
                isLast: false,
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget getDrop(T data, Widget child) {
    return Draggable<T>(
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: SizedBox(width: 300, height: 48, child: child),
      data: data,
      child: child,
    );
  }
}

class _DropZone<T extends Object, D extends Object> extends StatelessWidget {
  final void Function(DragTargetDetails data) onAccept;
  final bool isLast;
  const _DropZone({required this.onAccept, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return DragTarget<Object>(
      onWillAcceptWithDetails: (detail) {
        var data = detail.data;
        return data is T || data is D; // ✅ accepte 2 types
      },

      onAcceptWithDetails: onAccept,
      builder: (context, candidateData, rejectedData) {
        final isActive = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          height: isActive ? (isLast ? 48 : 36) : (isLast ? 36 : 24),
          decoration: BoxDecoration(
            color: isActive ? Colors.blue.withAlpha(20) : null,
            borderRadius: BorderRadius.circular(8),
            border:
                isActive
                    ? Border.all(color: Colors.blueAccent)
                    : (isLast
                        ? Border.all(color: Colors.grey)
                        : Border.all(color: Colors.transparent)),
          ),
          child:
              isLast
                  ? Center(
                    child: Text(
                      'Drop here',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                  : null,
        );
      },
    );
  }
}
