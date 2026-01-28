import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jsonschema/core/designer/core/cw_factory_action.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_overlay_selector.dart';
import 'package:jsonschema/core/designer/editor/view/prop_editor/helper_editor.dart';
import 'package:jsonschema/core/designer/core/cw_widget_style.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/core/cw_slot.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';
import 'package:jsonschema/core/designer/core/widget_catalog/cw_list.dart';
import 'package:jsonschema/core/designer/core/widget_catalog/cw_table_layout.dart';
import 'package:jsonschema/feature/content/state_manager.dart';

class CwTable extends CwWidget {
  const CwTable({super.key, required super.ctx});

  static void initFactory(WidgetFactory factory) {
    factory.register(
      id: 'table',
      build: (ctx) => CwTable(key: ctx.getKey(), ctx: ctx),
      config: (ctx) {
        return CwWidgetConfig().addProp(
          CwWidgetProperties(id: 'size', name: 'size')..isSize(ctx),
        );
      },
    );
  }

  @override
  State<CwTable> createState() => _CwTableState();
}

class _CwTableState extends CwWidgetStateBindJson<CwTable> with HelperEditor {
  late final ScrollController controller;

  GlobalKey parentKey = GlobalKey(debugLabel: '_CwTableState parentKey');

  @override
  void initState() {
    controller = ScrollController();
    super.initState();
    initBind();
  }

  @override
  void dispose() {
    controller.dispose();
    stateRepository!.disposeContainer(pathData, this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildWidget(true, ModeBuilderWidget.layoutBuilder, (
      ctx,
      constraints,
    ) {
      List listRow = [];

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
        (dataContainer, _) = stateRepository!.getStateContainer(pathContainer);
        if (dataContainer != null) {
          var l = dataContainer.jsonData[attrName] ?? [];
          if (l is List) {
            //print(' listRow $pathData length=${l.length}');
            listRow = l;
          } else {
            listRow = [];
          }
        }
      }

      int nbCol = getIntProp(ctx, 'nbchild') ?? 0;

      var wd = ctx.dataWidget!;
      var dataRow = wd[cwSlots]?['d-row'];
      var dataHeader = wd[cwSlots]?['h-row'];

      CWStyleFactory? styleBoxRow = CWStyleFactory(null);
      styleBoxRow.style = dataRow?[cwProps]?['style'] ?? {};
      styleBoxRow.setConfigBox();
      styleBoxRow.setConfigMargin();

      CWStyleFactory? styleBoxHeader = CWStyleFactory(null);
      styleBoxHeader.style = dataHeader?[cwProps]?['style'] ?? {};
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

      var isSizeDefined = styleFactory.isSizeDefined();
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isSizeDefined ? double.infinity : 100,
          maxHeight: isSizeDefined ? double.infinity : 100,
        ),
        child: FrozenTableView(
          key: parentKey,
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
          buildRow: (int row, bool isStartCols, Widget child) {
            return getRowStyleWidget(
              row == 0 ? styleBoxHeader : styleBoxRow,
              row,
              isStartCols,
              nbColFreeze,
              dataRow,
              CWInheritedRow(
                parentKey: parentKey,
                path: pathData,
                rowIdx: row - 1,
                child: child,
              ),
            );
          },

          getColWidth: (int col) {
            num? colWidth =
                ctx.dataWidget?[cwSlots]?['header_$col']?[cwProps]?['width'];

            return colWidth?.toDouble() ?? defaultColWidth;
          },
          getRowHeight: (int row) {
            if (row == 0) {
              return dataHeader?[cwProps]?['height']?.toDouble() ?? 30;
            }
            return dataRow?[cwProps]?['height']?.toDouble() ?? 30;
          },
        ),
      );
    });
  }

  Widget getRowStyleWidget(
    CWStyleFactory styleBox,
    int row,
    bool isStartCols,
    int nbColFreeze,
    Map<String, dynamic>? dataRow,
    Widget child,
  ) {
    // if (row == 0) return child; // pas de style pour la ligne header

    var bRadius = styleBox.getStyleDouble('bRadius', 0);
    var bColor = styleBox.getColor('bColor') ?? Colors.transparent;
    var bSize = styleBox.getStyleDouble('bSize', 1);

    if (bSize == 0) {
      bColor = Colors.transparent;
      bRadius = 0;
    }

    var ptop = styleBox.getStyleDouble('ptop', 0);
    var pbottom = styleBox.getStyleDouble('pbottom', 0);
    var pleft = styleBox.getStyleDouble('pleft', 0);
    var pright = styleBox.getStyleDouble('pright', 0);

    var mtop = styleBox.getStyleDouble('mtop', 0);
    var mbottom = styleBox.getStyleDouble('mbottom', 0);
    var mleft = styleBox.getStyleDouble('mleft', 0);
    var mright = styleBox.getStyleDouble('mright', 0);

    var elevation = styleBox.getElevation();

    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.only(
        topLeft:
            isStartCols || nbColFreeze == 0
                ? Radius.circular(bRadius)
                : Radius.zero,
        topRight:
            isStartCols && nbColFreeze != 0
                ? Radius.zero
                : Radius.circular(bRadius),
        bottomLeft:
            isStartCols || nbColFreeze == 0
                ? Radius.circular(bRadius)
                : Radius.zero,
        bottomRight:
            isStartCols && nbColFreeze != 0
                ? Radius.zero
                : Radius.circular(bRadius),
      ),
      color: styleBox.config.decoration?.color,
      border: Border(
        bottom: BorderSide(color: bColor, width: bSize),
        top: BorderSide(color: bColor, width: bSize),
        left:
            isStartCols || nbColFreeze == 0
                ? BorderSide(color: bColor, width: bSize)
                : BorderSide.none,
        right:
            isStartCols && nbColFreeze != 0
                ? BorderSide.none
                : BorderSide(color: bColor, width: bSize),
      ),
    );

    if (elevation != null) {
      return Container(
        key: ObjectKey(dataRow),
        margin: EdgeInsets.fromLTRB(
          isStartCols || nbColFreeze == 0 ? pleft : 0,
          ptop,
          isStartCols && nbColFreeze != 0 ? 0 : pright,
          pbottom,
        ),
        child: Material(
          elevation: elevation,
          borderRadius: boxDecoration.borderRadius,
          child: Container(
            decoration: boxDecoration,
            padding: EdgeInsets.fromLTRB(
              isStartCols || nbColFreeze == 0 ? mleft : 0,
              mtop,
              isStartCols && nbColFreeze != 0 ? 0 : mright,
              mbottom,
            ),
            child: child,
          ),
        ),
      );
    } else {
      return Container(
        key: ObjectKey(dataRow),
        margin: EdgeInsets.fromLTRB(
          isStartCols || nbColFreeze == 0 ? pleft : 0,
          ptop,
          isStartCols && nbColFreeze != 0 ? 0 : pright,
          pbottom,
        ),
        decoration: boxDecoration,
        padding: EdgeInsets.fromLTRB(
          isStartCols || nbColFreeze == 0 ? mleft : 0,
          mtop,
          isStartCols && nbColFreeze != 0 ? 0 : mright,
          mbottom,
        ),
        child: child,
      );
    }
  }

  void _onActionCell(CwWidgetCtx ctx, DesignAction action) {
    var props = ctx.parentCtx!.initPropsIfNeeded();
    int nbCol = getIntProp(ctx.parentCtx!, 'nbchild') ?? 0;
    int idx = int.parse(ctx.slotId.split('_').last);
    var actMgr = CwFactoryAction(ctx: ctx);
    print('OnActionCell action=$action');
    switch (action) {
      case DesignAction.delete:
        props['nbchild'] = nbCol - 1;
        actMgr.deleteSlot('header_', idx, nbCol);
        actMgr.deleteSlot('cell_', idx, nbCol);
        break;
      case DesignAction.addLeft:
        props['nbchild'] = nbCol + 1;
        actMgr.moveSlot('header_', nbCol, idx);
        actMgr.moveSlot('cell_', nbCol, idx);
        break;
      case DesignAction.addRight:
        props['nbchild'] = nbCol + 1;
        actMgr.moveSlot('header_', nbCol, idx + 1);
        actMgr.moveSlot('cell_', nbCol, idx + 1);
        break;
      case DesignAction.addBottom:
        // var slotFrom = 'cell_$idx';
        // var slotTo = 'cell_1';
        // actMgr.surround(slotFrom, slotTo, {
        //   cwImplement: 'container',
        //   cwProps: <String, dynamic>{'type':'column'},
        // });
        break;
      case DesignAction.addTop:
        // var slotFrom = 'cell_$idx';
        // var slotTo = 'cell_1';
        // actMgr.surround(slotFrom, slotTo, {
        //   cwImplement: 'container',
        //   cwProps: <String, dynamic>{'type':'column'},
        // });
        break;
      case DesignAction.moveLeft:
        actMgr.swapSlot('header_', idx, idx - 1);
        actMgr.swapSlot('cell_', idx, idx - 1);
        break;
      case DesignAction.moveRight:
        actMgr.swapSlot('header_', idx, idx + 1);
        actMgr.swapSlot('cell_', idx, idx + 1);
        break;

      default:
    }

    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      if (mounted) {
        setState(() {});
      }
      ctx.selectParentOnDesigner();
    });
  }

  Widget _cellBuilder(int row, int col) {
    if (row == 0) {
      return getSlot(
        CwSlotProp(
          id: 'header_$col',
          name: 'Header $col',
          type: 'header',
          onAction: _onActionCell,
        ),
      );
    }

    return getSlot(
      CwSlotProp(
        id: 'cell_$col',
        name: 'Cell $col',
        type: 'cell',
        onAction: _onActionCell,
      ),
    );
  }
}
