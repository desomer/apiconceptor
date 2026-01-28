import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class FrozenTableView extends StatefulWidget {
  final int rowCount;
  final int colCount;
  final int colFreezeLeftCount;

  final int rowCountTop;
  final int rowCountBottom;

  final double rowWidthBorderR;
  final double rowWidthBorderL;

  final Widget Function(int row, int col) buildTopCell;
  final Widget Function(int row, int col) buildBottomCell;
  final Widget Function(int row, int col) buildLeftCell;
  final Widget Function(int row, int col) buildBodyCell;
  final Widget Function(int row, bool isStartCols, Widget child) buildRow;
  final double Function(int col) getColWidth;
  final double? Function(int row) getRowHeight;

  const FrozenTableView({
    super.key,
    required this.rowCount,
    required this.colCount,
    required this.buildTopCell,
    required this.buildBottomCell,
    required this.buildLeftCell,
    required this.buildBodyCell,
    required this.rowCountTop,
    required this.rowCountBottom,
    required this.colFreezeLeftCount,
    required this.getColWidth,
    required this.getRowHeight,
    required this.buildRow,
    required this.rowWidthBorderR,
    required this.rowWidthBorderL,
  });

  @override
  State<FrozenTableView> createState() => _FrozenTableViewState();
}

class _FrozenTableViewState extends State<FrozenTableView> {
  final ScrollController vertical = ScrollController();
  final ScrollController vertical2 = ScrollController();
  final ScrollController horizontal1 = ScrollController();
  final ScrollController horizontal2 = ScrollController();
  final ScrollController horizontal3 = ScrollController();

  Map<int, double> colWidthMap = {};
  
  bool topScrollbarVisible = false;
  double topMargin =  0;

  @override
  void initState() {
    super.initState();
    vertical.addListener(() {
      if (vertical2.offset != vertical.offset) {
        vertical2.jumpTo(vertical.offset);
      }
    });
    vertical2.addListener(() {
      if (vertical.offset != vertical2.offset) {
        vertical.jumpTo(vertical2.offset);
      }
    });
    horizontal1.addListener(() {
      if (horizontal2.offset != horizontal1.offset) {
        horizontal2.jumpTo(horizontal1.offset);
      }
      if (horizontal3.offset != horizontal1.offset) {
        horizontal3.jumpTo(horizontal1.offset);
      }
    });
    horizontal2.addListener(() {
      if (horizontal1.offset != horizontal2.offset) {
        horizontal1.jumpTo(horizontal2.offset);
      }
    });
    horizontal3.addListener(() {
      if (horizontal1.offset != horizontal3.offset) {
        horizontal1.jumpTo(horizontal3.offset);
      }
    });
  }

  @override
  void dispose() {
    vertical.dispose();
    vertical2.dispose();
    horizontal1.dispose();
    horizontal2.dispose();
    horizontal3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ------------------ TOP FROZEN ROW ------------------
        Row(
          mainAxisSize: MainAxisSize.max,
          children: [_topFrozenColumn(), Expanded(child: _topFrozenRow())],
        ),

        // ------------------ BODY + LEFT FROZEN COLUMN ------------------
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_leftFrozenColumn(), Expanded(child: _body())],
          ),
        ),

        // ------------------ BOTTOM FROZEN ROW ------------------
        Row(
          children: [
            _bottomFrozenColumn(),
            Expanded(child: _bottomFrozenRow()),
          ],
        ),
      ],
    );
  }

  double getWitdhL(int start, int end) {
    double total = 0;
    for (int i = start; i < end; i++) {
      if (colWidthMap.containsKey(i)) {
        total += colWidthMap[i]!;
        continue;
      }

      total += widget.getColWidth(i);
    }
    return total + widget.rowWidthBorderL;
  }

  double getWitdhR(int start, int end) {
    double total = 0;
    for (int i = start; i < end; i++) {
      if (colWidthMap.containsKey(i)) {
        total += colWidthMap[i]!;
        continue;
      }

      total += widget.getColWidth(i);
    }
    return total + widget.rowWidthBorderR;
  }

  double getColWidth(int colIndex) {
    if (colWidthMap.containsKey(colIndex)) {
      return colWidthMap[colIndex]!;
    }
    return widget.getColWidth(colIndex);
  }

  Widget getHeader(Widget child, int rowIndex, int colIndex) {
    ValueNotifier<bool> isHover = ValueNotifier(false);
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (rowIndex == 0)
          Positioned(
            right: 10,
            top: 0,
            bottom: 0,
            left: 10,
            child: getAction(isHover),
          ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: getResizeHandle(colIndex),
        ),
      ],
    );
  }

  Widget getAction(ValueNotifier<bool> isHover) {
    return MouseRegion(
      opaque: false,
      onEnter: (_) {},
      onExit: (_) {
        isHover.value = false;
      },
      onHover: (_) {
        isHover.value = true;
      },
      child: ValueListenableBuilder(
        valueListenable: isHover,
        builder:
            (context, value, child) => Visibility(
              visible: isHover.value,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Material(
                    elevation: 3,
                    color: Colors.black12,
                    shape: CircleBorder(),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      onPressed: () {},
                      icon: Icon(
                        Icons.expand_more,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Widget getResizeHandle(int colIndex) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) {
        // Handle resize logic here
        setState(() {
          // Update column width based on drag details
          // This is a simplified example; you may want to add constraints
          // and more complex logic depending on your requirements
          // For this example, we'll just increase the width of the first column
          if (colWidthMap.containsKey(colIndex)) {
            colWidthMap[colIndex] = (colWidthMap[colIndex]! + details.delta.dx)
                .clamp(50.0, 500.0);
          } else {
            colWidthMap[colIndex] = (getColWidth(colIndex) + details.delta.dx)
                .clamp(50.0, 500.0);
          }
        });
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: Container(width: 5),
      ),
    );
  }

  Widget _getWeellPointerScrollBehavior(
    ScrollController controller,
    ScrollbarOrientation orientation,
    Widget child,
    bool? alwaysVisible,
    bool? enableScrollIndicator,
  ) {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          // event.scrollDelta.dy = mouvement de la molette
          final delta = event.scrollDelta.dy * 0.3;

          controller.jumpTo(
            (controller.offset + delta).clamp(
              0.0,
              controller.position.maxScrollExtent,
            ),
          );
        }
      },
      child:
          enableScrollIndicator == true
              ? Scrollbar(
                scrollbarOrientation: orientation,
                interactive: true,
                controller: controller,
                thumbVisibility: alwaysVisible, // toujours visible
                trackVisibility: true, // optionnel
                child: child,
              )
              : child,
    );
  }

  // Ligne gelée en haut
  Widget _topFrozenRow() {
    var witdh = getWitdhR(widget.colFreezeLeftCount, widget.colCount);

    return _getWeellPointerScrollBehavior(
      horizontal1,
      ScrollbarOrientation.top,
      SingleChildScrollView(
        controller: horizontal1,
        scrollDirection: Axis.horizontal,

        child: Container(
          margin: EdgeInsets.fromLTRB(0, topMargin, 0, 0),
          //  height: widget.rowHeight * widget.rowCountTop,
          width: witdh, // <-- FIX
          child: ListView.builder(
            primary: false,
            shrinkWrap: true,
            itemCount: widget.rowCountTop,
            itemBuilder:
                (_, row) => widget.buildRow(
                  row,
                  false,
                  SizedBox(
                    // height: widget.getRowHeight(row),
                    width: witdh, // <-- FIX
                    child: Row(
                      children: [
                        for (
                          int col = widget.colFreezeLeftCount;
                          col < widget.colCount;
                          col++
                        )
                          SizedBox(
                            width: getColWidth(col),
                            height: widget.getRowHeight(row),
                            child: getHeader(
                              widget.buildTopCell(row, col),
                              row,
                              col,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
          ),
        ),
      ),
      null,
      topScrollbarVisible,
    );
  }

  // Ligne gelée en bas
  Widget _bottomFrozenRow() {
    var witdh = getWitdhR(widget.colFreezeLeftCount, widget.colCount);
    return _getWeellPointerScrollBehavior(
      horizontal1,
      ScrollbarOrientation.bottom,
      SingleChildScrollView(
        controller: horizontal2,
        scrollDirection: Axis.horizontal,
        physics: AlwaysScrollableScrollPhysics(),
        child: Container(
          margin: EdgeInsets.fromLTRB(0, 0, 0, 10),
          // height: widget.rowHeight * widget.rowCountBottom,
          width: witdh, // <-- FIX
          child: ListView.builder(
            shrinkWrap: true,
            primary: false,
            itemCount: widget.rowCountBottom,
            itemBuilder:
                (_, row) => widget.buildRow(
                  row + widget.rowCount - widget.rowCountBottom,
                  true,
                  SizedBox(
                    // height: widget.getRowHeight(
                    //   row + widget.rowCount - widget.rowCountBottom,
                    // ),
                    width: witdh, // <-- FIX
                    child: Row(
                      children: [
                        for (
                          int col = widget.colFreezeLeftCount;
                          col < widget.colCount;
                          col++
                        )
                          SizedBox(
                            width: getColWidth(col),
                            height: widget.getRowHeight(
                              row + widget.rowCount - widget.rowCountBottom,
                            ),
                            child: widget.buildBottomCell(
                              row + widget.rowCount - widget.rowCountBottom,
                              col,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
          ),
        ),
      ),
      true,
      true,
    );
  }

  // Colonne gelée à gauche
  Widget _topFrozenColumn() {
    if (widget.colFreezeLeftCount == 0) {
      return SizedBox.shrink();
    }

    var witdh = getWitdhL(0, widget.colFreezeLeftCount);

    return Container(
      margin: EdgeInsets.fromLTRB(0, topMargin, 0, 0),
      //height: widget.rowCountTop * widget.rowHeight,
      width: witdh, // <-- FIX
      child: ListView.builder(
        primary: false,
        shrinkWrap: true,
        //controller: vertical,
        itemCount: widget.rowCountTop,
        itemBuilder:
            (_, row) => widget.buildRow(
              row,
              true,
              SizedBox(
                // height: widget.getRowHeight(row),
                width: witdh,
                child: Row(
                  children: [
                    for (int col = 0; col < widget.colFreezeLeftCount; col++)
                      SizedBox(
                        width: getColWidth(col),
                        height: widget.getRowHeight(row),
                        child: getHeader(
                          widget.buildLeftCell(row, col),
                          row,
                          col,
                        ),
                      ),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  // Colonne gelée à gauche
  Widget _bottomFrozenColumn() {
    if (widget.colFreezeLeftCount == 0) {
      return SizedBox.shrink();
    }
    var witdh = getWitdhL(0, widget.colFreezeLeftCount);
    return Container(
      margin: EdgeInsets.fromLTRB(0, 0, 0, 10),
      //height: widget.rowCountBottom * widget.rowHeight,
      width: witdh, // <-- FIX
      child: ListView.builder(
        primary: false,
        shrinkWrap: true,
        //controller: vertical,
        itemCount: widget.rowCountBottom,
        itemBuilder:
            (_, row) => widget.buildRow(
              row + widget.rowCount - widget.rowCountBottom,
              false,
              SizedBox(
                // height: widget.getRowHeight(
                //   row + widget.rowCount - widget.rowCountBottom,
                // ),
                width: witdh,
                child: Row(
                  children: [
                    for (int col = 0; col < widget.colFreezeLeftCount; col++)
                      SizedBox(
                        width: getColWidth(col),
                        height: widget.getRowHeight(
                          row + widget.rowCount - widget.rowCountBottom,
                        ),
                        child: widget.buildLeftCell(
                          row + widget.rowCount - widget.rowCountBottom,
                          col,
                        ),
                      ),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  // Colonne gelée à gauche
  Widget _leftFrozenColumn() {
    if (widget.colFreezeLeftCount == 0) {
      return SizedBox.shrink();
    }

    var witdh = getWitdhL(0, widget.colFreezeLeftCount);
    return SizedBox(
      //height: widget.rowCount * widget.rowHeight,
      width: witdh, // <-- FIX
      child: ListView.builder(
        shrinkWrap: true,
        primary: false,
        controller: vertical,
        itemCount: widget.rowCount - widget.rowCountTop - widget.rowCountBottom,
        itemBuilder:
            (_, row) => SizedBox(
              //height: widget.getRowHeight(row + widget.rowCountTop),
              width: witdh,
              child: widget.buildRow(
                row + widget.rowCountTop,
                true,
                Row(
                  children: [
                    for (int col = 0; col < widget.colFreezeLeftCount; col++)
                      SizedBox(
                        width: getColWidth(col),
                        height: widget.getRowHeight(row + widget.rowCountTop),
                        child: widget.buildLeftCell(
                          row + widget.rowCountTop,
                          col,
                        ),
                      ),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  // Corps du tableau
  Widget _body() {
    var witdh = getWitdhR(widget.colFreezeLeftCount, widget.colCount);
    return SingleChildScrollView(
      controller: vertical2,
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        controller: horizontal3,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          //height: widget.rowHeight * widget.rowCount,
          width: witdh,
          // (widget.colCount - widget.colFreezeLeftCount) *
          // widget.colWidth, // <-- FIX
          child: ListView.builder(
            primary: false,
            shrinkWrap: true,
            itemCount:
                widget.rowCount - widget.rowCountTop - widget.rowCountBottom,
            itemBuilder:
                (_, row) => widget.buildRow(
                  row + widget.rowCountTop,
                  false,
                  SizedBox(
                    // height: widget.getRowHeight(row + widget.rowCountTop),
                    width: witdh, // <-- FIX
                    child: Row(
                      children: [
                        for (
                          int col = widget.colFreezeLeftCount;
                          col < widget.colCount;
                          col++
                        )
                          SizedBox(
                            width: getColWidth(col),
                            height: widget.getRowHeight(
                              row + widget.rowCountTop,
                            ),
                            child: widget.buildBodyCell(
                              row + widget.rowCountTop,
                              col,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
          ),
        ),
      ),
    );
  }
}
