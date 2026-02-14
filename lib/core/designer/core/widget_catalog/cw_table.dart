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

class CwTable extends CwWidget {
  const CwTable({super.key, required super.ctx, required super.cacheWidget});

  static void initFactory(WidgetFactory factory) {
    factory.register(
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
    stateRepository!.disposeContainer(pathData, this);
    super.dispose();
  }

  @override
  bool isWidgetCacheEnable(BoxConstraints? constraints) {
    return false;
  }

  @override
  bool clearWidgetCache({bool clearInnerWidget = false}) {
    if (mounted) {
      var state = tableKey.currentState;
      if (state is FrozenTableViewState) {
        state.clearWidgetCache();
        return true;
      }
    }
    return super.clearWidgetCache(clearInnerWidget: clearInnerWidget);
  }

  @override
  Widget build(BuildContext context) {
    return buildWidget(true, ModeBuilderWidget.layoutBuilder, (
      ctx,
      constraints,
      _,
    ) {
      List listRow = [];
      StateContainerArray? arrayContainer;

      if (stateRepository != null && attribut != null) {
        String? oldPathData = pathData;

        pathData = stateRepository!.getDataPath(
          context,
          attribut!.info.path,
          widgetPath: ctx.aWidgetPath,
          typeListContainer: true,
          inArray: false,
          state: this,
        );
        if (oldPathData != '?' && oldPathData != pathData) {
          stateRepository!.disposeContainer(oldPathData, this);
        }
        stateRepository!.registerContainer(pathData, this);

        String pathContainer;
        String attrName;
        (pathContainer, attrName) = stateRepository!.getPathInfo(pathData);
        StateContainer? dataContainer;
        (dataContainer, _) = stateRepository!.getStateContainer(
          pathContainer,
          context: context,
          pathWidgetRepos: ctx.aWidgetPath,
        );

        if (dataContainer != null) {
          var l = dataContainer.jsonData[attrName] ?? [];

          if (l is List) {
            //print(' listRow $pathData length=${l.length}');
            arrayContainer =
                dataContainer.stateChild[attrName] as StateContainerArray?;
            listRow = l;
          } else {
            listRow = [];
          }
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
      double defaultColWidth =
          (constraints!.maxWidth -
              styleFactory.config.wMargin -
              styleFactory.config.wPadding -
              (styleFactory.config.side?.width ?? 0) * 2 -
              1 -
              (rowWidthBorder * 2) -
              pleft -
              pright -
              mleft -
              mright) /
          nbCol;

      if (defaultColWidth < 100) {
        // pas trop petit
        defaultColWidth = 100;
      }

      if (defaultColWidth == double.infinity) {
        // si pas de width defini
        defaultColWidth = 100;
      }

      var array = FrozenTableView(
        key: tableKey,
        colCount: nbCol,
        rowWidthBorderR:
            (rowWidthBorder + pright + mright) +
            (nbColFreeze == 0 ? (rowWidthBorder + pleft + mleft) : 0),
        rowWidthBorderL:
            nbColFreeze == 0 ? 0 : (rowWidthBorder + pleft + mleft),
        rowCount: listRow.length + 1,
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
            data: row == 0 ? propsRow : listRow[row - 1],
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
            key: ObjectKey(row == 0 ? propsRow : listRow[row - 1]),
            rowkey: rowWidget.key as GlobalKey,
            tableKey: tableKey,
            path: pathData,
            rowIdx: row - 1,
            child: rowWidget,
          );
        },

        getColWidth: (int col) {
          num? colWidth =
              ctx.dataWidget?[cwSlots]?['header_$col']?[cwProps]?['width'];

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
}
