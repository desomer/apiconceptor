import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/editor/engine/overlay_action.dart';
import 'package:jsonschema/core/designer/core/widget_catalog/cw_table_row.dart';
import 'package:jsonschema/core/designer/editor/view/prop_editor/helper_editor.dart';
import 'package:jsonschema/core/designer/core/cw_widget_style.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/core/cw_slot.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';
import 'package:jsonschema/core/designer/core/widget_catalog/cw_table_layout.dart';
import 'package:jsonschema/feature/content/state_manager.dart';

import 'package:flutter/services.dart';
import 'package:jsonschema/widget/widget_scroller.dart';

import 'export/export.dart';
import 'export/export_csv.dart';

class CwTable extends CwWidget {
  const CwTable({super.key, required super.ctx, required super.cacheWidget});

  static void initFactory(WidgetFactory factory) {
    factory.registerComponent(
      id: 'table',
      build:
          (ctx) =>
              CwTable(key: ctx.getKey(), ctx: ctx, cacheWidget: CachedWidget()),
      config: (ctx) {
        return CwWidgetConfig().addProp(
          CwWidgetProperties(id: 'size', name: 'size')..isSize(ctx),
        );
      },
    );
  }

  @override
  State<CwTable> createState() => CwTableState();
}

class CwTableState extends CwWidgetStateBindJson<CwTable> with HelperEditor {
  GlobalKey tableKey = GlobalKey(debugLabel: '_CwTableState parentKey');

  @override
  void initState() {
    super.initState();
    initBind();
  }

  @override
  void dispose() {
    bindInfo.stateRepository!.depsBindingManager.disposeContainer(
      bindInfo.pathData,
      this,
    );
    super.dispose();
  }

  @override
  bool isWidgetCacheEnable(BoxConstraints? constraints) {
    return false;
  }

  @override
  void setFilterValue(String? text, List<CwWidgetCtx> listCell) {
    var pathA = bindInfo.bindAttribut?.getJsonPath(sep: '/');
    var v = bindInfo.getValue(context, widget.ctx, this, false, true);

    List listRow = [];
    if (v is List) {
      listRow = v;
    }

    if (text == null || text.isEmpty) {
      var hasRemove = false;
      for (Map r in listRow) {
        if (r.remove('#isFilterHide') == true) {
          hasRemove = true;
        }
      }
      if (hasRemove) {
        clearWidgetCache();
        widget.ctx.repaint();
      }
      return;
    }

    for (Map r in listRow) {
      var match = false;
      a:
      for (var d in listCell) {
        var v = d.getValueFromRow(r, this, pathA);
        if (v is bool && v == true) {
          v =
              d.dataWidget?[cwProps]?['tooltip'] ??
              d.dataWidget?[cwProps]?['label'];
        }
        if (v != null &&
            v.toString().toLowerCase().contains(text.toLowerCase())) {
          match = true;
          break a;
        }
      }
      if (match) {
        r.remove('#isFilterHide');
      } else {
        r['#isFilterHide'] = true;
      }
    }
    clearWidgetCache();
    widget.ctx.repaint();
  }

  @override
  bool clearWidgetCache({bool clearInnerWidget = false}) {
    //if (mounted) {
      var state = tableKey.currentState;
      if (state is FrozenTableViewState) {
        state.clearWidgetCache();
        return true;
      }
    //}
    return super.clearWidgetCache(clearInnerWidget: clearInnerWidget);
  }

  @override
  Widget build(BuildContext context) {
    return buildWidget(true, ModeBuilderWidget.layoutBuilder, (
      ctx,
      constraints,
      _,
    ) {
      List filteredList = [];
      StateContainerArray? arrayContainer;

      List? originalList = bindInfo.getValue(context, ctx, this, false, true);
      if (originalList != null) {
        //print(' listRow $pathData length=${l.length}');
        arrayContainer =
            bindInfo.dataContainer!.stateChild[bindInfo.attrName]
                as StateContainerArray?;
        for (var element in originalList) {
          if (element is Map && element['#isFilterHide'] == true) {
            continue;
          }
          filteredList.add(element);
        }
      }

      int nbCol = getIntProp(ctx, 'nbchild') ?? 0;

      var wd = ctx.dataWidget!;
      var propsRow = wd[cwSlots]?['d-row'];
      var propsHeader = wd[cwSlots]?['h-row'];

      CWStyleFactory? styleBoxRow = CWStyleFactory(null);
      styleBoxRow.style = propsRow?[cwProps]?['style'] ?? {};
      styleBoxRow.setConfigBox();
      styleBoxRow.setConfigMargin();

      CWStyleFactory? styleBoxHeader = CWStyleFactory(null);
      styleBoxHeader.style = propsHeader?[cwProps]?['style'] ?? {};
      styleBoxHeader.setConfigBox();
      styleBoxHeader.setConfigMargin();

      int nbColFreeze = 0;
      //double margin = 0.0;
      var bSize = styleBoxRow.getStyleDouble('bSize', 1);
      var pleft = styleBoxRow.getStyleDouble('pleft', 0);
      var pright = styleBoxRow.getStyleDouble('pright', 0);
      var mleft = styleBoxRow.getStyleDouble('mleft', 0);
      var mright = styleBoxRow.getStyleDouble('mright', 0);

      double rowWidthBorder = ((bSize + 1) * 1);
      var availableWidth =
          (constraints!.maxWidth -
              styleFactory.config.wMargin -
              styleFactory.config.wPadding -
              (styleFactory.config.side?.width ?? 0) * 2 -
              1 -
              (rowWidthBorder * 2) -
              pleft -
              pright -
              mleft -
              mright);

      double defaultColWidth = availableWidth / nbCol;

      var array = FrozenTableView(
        key: tableKey,
        colCount: nbCol,
        rowWidthBorderR:
            (rowWidthBorder + pright + mright) +
            (nbColFreeze == 0 ? (rowWidthBorder + pleft + mleft) : 0),
        rowWidthBorderL:
            nbColFreeze == 0 ? 0 : (rowWidthBorder + pleft + mleft),
        rowCount: filteredList.length + 1,
        buildTopCell: _cellBuilder,
        buildBottomCell: _cellBuilder,
        buildLeftCell: _cellBuilder,
        buildBodyCell: _cellBuilder,
        rowCountTop: 1,
        rowCountBottom: 0,
        colFreezeLeftCount: nbColFreeze,
        buildRow: (
          int row,
          bool isStartCols,
          Widget child,
          FrozenTableViewState tableState,
        ) {
          var info = CwRowInfo(
            tableState: tableState,
            ctx: ctx,
            styleBox: row == 0 ? styleBoxHeader : styleBoxRow,
            row: row,
            isStartCols: isStartCols,
            nbColFreeze: nbColFreeze,
            propsRow: propsRow,
            arrayContainer: arrayContainer,
            data: row == 0 ? propsRow : filteredList[row - 1],
          );

          CwTableRow? rowWidgetCached = tableState.getCacheTableRowState(
            info,
            child,
          );
          if (rowWidgetCached?.info.data != info.data) {
            // nouvelle data, on invalide le cache
            rowWidgetCached = null;
          }

          Widget rowWidget =
              rowWidgetCached ??
              CwTableRow(
                key: GlobalKey(debugLabel: '_CwTableState row_$row'),
                info: info,
                child: child,
              );

          return CWInheritedRow(
            key: ObjectKey(row == 0 ? propsRow : filteredList[row - 1]),
            rowkey: rowWidget.key as GlobalKey,
            tableKey: tableKey,
            path: bindInfo.pathData,
            rowIdx:
                row == 0 ? -1 : originalList!.indexOf(filteredList[row - 1]),
            child: rowWidget,
          );
        },

        getColWidth: (int col, double usedWidth, bool isCalc, int nbFillCol) {
          num? colWidth =
              ctx.dataWidget?[cwSlots]?['header_$col']?[cwProps]?['width'];
          if (isCalc && colWidth != null) {
            return colWidth.toDouble();
          }

          if (isCalc) {
            return -1;
          }

          var canCalcDefault = usedWidth >= 0 && nbFillCol >= 0;
          if (canCalcDefault && colWidth == null) {
            defaultColWidth =
                (availableWidth - usedWidth) / (nbCol - nbFillCol);
            if (defaultColWidth == double.infinity) {
              // si pas de width defini
              defaultColWidth = 100;
            }
            if (defaultColWidth < 100) {
              defaultColWidth = 100;
            }
          }
          return colWidth?.toDouble() ?? defaultColWidth;
        },
        getRowHeight: (int row) {
          if (row == 0) {
            return propsHeader?[cwProps]?['height']?.toDouble() ?? 30;
          }
          return propsRow?[cwProps]?['height']?.toDouble() ?? 30;
        },
      );

      var isSizeDefined = styleFactory.isSizeDefined();
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isSizeDefined ? double.infinity : 100,
          maxHeight: isSizeDefined ? double.infinity : 100,
        ),
        child: array,
      );
    });
  }

  @override
  void setSelectedRowIndex(int idx) {
    if (mounted) {
      var state = tableKey.currentState;
      if (state is FrozenTableViewState) {
        state.setSelectedRowIndex(idx);
      }
    }
  }

  Widget _cellBuilder(int row, int col) {
    if (row == 0) {
      return getSlot(
        CwSlotProp(
          id: 'header_$col',
          name: 'Header $col',
          type: 'header',
          onAction: onActionCellTable,
        ),
      );
    }

    return getSlot(
      CwSlotProp(
        id: 'cell_$col',
        name: 'Cell $col',
        type: 'cell',
        onAction: onActionCellTable,
      ),
    );
  }

  void doExport(BuildContext context) {
    List<CwWidgetCtx> data = widget.ctx.getAllCellsCtx();

    var arrayState = widget.ctx.widgetState as CwWidgetStateBindJson;
    var v = arrayState.bindInfo.getValue(
      context,
      widget.ctx,
      this,
      false,
      true,
    );

    List filteredList = [];
    if (v is List) {
      for (Map element in v) {
        if (element['#isFilterHide'] == true) {
          continue;
        }
        filteredList.add(element);
      }
    }
    List<Map<String, dynamic>> jsonl = [];
    var pathA = arrayState.bindInfo.bindAttribut?.getJsonPath(sep: '/');
    for (var element in filteredList) {
      var l = <String, dynamic>{};
      for (var d in data) {
        var label = d.dataWidget?[cwProps]['label'];
        if (label != null) {
          var v = d.getValueFromRow(element, arrayState, pathA);
          l[label] = v;
        }
      }
      jsonl.add(l);
    }

    showCsvDialog(context, jsonl);
  }
}

void showCsvDialog(BuildContext context, List<Map<String, dynamic>> jsonl) {
  Size size = MediaQuery.of(context).size;
  double width = size.width * 0.8;
  double height = size.height * 0.8;

  showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text("CSV Result"),
        content: SizedBox(
          width: width,
          height: height,
          child: WidgetScroller(
            child: Text(
              jsonlToCsvExcelFriendly(
                jsonl,
                options: CsvOptions(separator: '\t'),
              ).csv,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ),

        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(
                ClipboardData(
                  text:
                      jsonlToCsvExcelFriendly(
                        jsonl,
                        options: CsvOptions(
                          separator: '\t',
                          excelProtectSensitiveValues: false,
                        ),
                      ).csv,
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("CSV copied to clipboard")),
              );
            },
            child: const Text("Clipboard Gsheet"),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(
                ClipboardData(
                  text:
                      jsonlToCsvExcelFriendly(
                        jsonl,
                        options: CsvOptions(separator: '\t'),
                      ).csv,
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("CSV copied to clipboard")),
              );
            },
            child: const Text("Clipboard Excel"),
          ),
          TextButton(
            onPressed: () async {
              final path = await exportCsv(
                jsonlToCsvExcelFriendly(
                  jsonl,
                  options: CsvOptions(
                    separator: ',',
                    excelProtectSensitiveValues: false,
                  ),
                ),
              );
              if (path != null) {
                ScaffoldMessenger.of(
                  // ignore: use_build_context_synchronously
                  context,
                ).showSnackBar(SnackBar(content: Text("File exported: $path")));
              }
            },
            child: const Text("CSV File GSheet"),
          ),
          TextButton(
            onPressed: () async {
              final path = await exportCsv(
                jsonlToCsvExcelFriendly(
                  jsonl,
                  options: CsvOptions(separator: ';'),
                ),
              );
              if (path != null) {
                ScaffoldMessenger.of(
                  // ignore: use_build_context_synchronously
                  context,
                ).showSnackBar(SnackBar(content: Text("File exported: $path")));
              }
            },
            child: const Text("CSV File Excel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      );
    },
  );
}
