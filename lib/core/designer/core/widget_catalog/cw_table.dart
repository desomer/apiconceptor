import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jsonschema/core/designer/core/cw_factory_action.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_overlay_selector.dart';
import 'package:jsonschema/core/designer/editor/view/prop_editor/helper_editor.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_style.dart';
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
        return CwWidgetConfig();
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

      if (stateRepository != null) {
        String? oldPathData = pathData;

        pathData = stateRepository!.getDataPath(
          context,
          attribut!.info,
          typeListContainer: true,
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
          listRow = dataContainer.jsonData[attrName] ?? [];
        }
      }

      void onActionCell(CwWidgetCtx ctx, DesignAction action) {
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

      Widget cellBuilder(int row, int col) {
        if (row == 0) {
          return getSlot(
            CwSlotProp(
              id: 'header_$col',
              name: 'Header $col',
              type: 'header',
              onAction: onActionCell,
            ),
          );
        }

        return getSlot(
          CwSlotProp(
            id: 'cell_$col',
            name: 'Cell $col',
            type: 'cell',
            onAction: onActionCell,
          ),
        );
      }

      int nbCol = getIntProp(ctx, 'nbchild') ?? 0;

      var wd = ctx.dataWidget!;
      var dataRow = wd[cwSlots]?['d-row'];

      CWStyleFactory? styleBox = CWStyleFactory(null);
      styleBox.style = dataRow?[cwProps]?['style'] ?? {};
      styleBox.setConfigBox();
      styleBox.setConfigMargin();

      int nbColFreeze = 1;
      //double margin = 0.0;
      var bSize = styleBox.getStyleDouble('bSize', 1);
      var pleft = styleBox.getStyleDouble('pleft', 0);
      var pright = styleBox.getStyleDouble('pright', 0);
      var mleft = styleBox.getStyleDouble('mleft', 0);
      var mright = styleBox.getStyleDouble('mright', 0);

      double rowWidthBorder = ((bSize + 1) * 1);
      double colWidth =
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

      // print('rowWidthBorder=$rowWidthBorder colWidth=$colWidth');

      if (colWidth < 200) {
        colWidth = 200;
      }

      return FrozenTableView(
        key: parentKey,
        colCount: nbCol,
        rowWidthBorderR: rowWidthBorder + pright + mright,
        rowWidthBorderL: rowWidthBorder + pleft + mleft,
        rowCount: listRow.length + 1,
        buildTopCell: cellBuilder,
        buildBottomCell: cellBuilder,
        buildLeftCell: cellBuilder,
        buildBodyCell: cellBuilder,
        rowCountTop: 1,
        rowCountBottom: 0,
        colFreezeLeftCount: nbColFreeze,
        buildRow: (int row, bool isStartCols, Widget child) {
          return getRowStyleWidget(
            styleBox,
            row,
            isStartCols,
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
          return colWidth;
        },
        getRowHeight: (int row) {
          return 30;
        },
      );
    });
  }

  Widget getRowStyleWidget(
    CWStyleFactory styleBox,
    int row,
    bool isStartCols,
    Map<String, dynamic>? dataRow,
    Widget child,
  ) {
    if (row == 0) return child; // pas de style pour la ligne header

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
        topLeft: isStartCols ? Radius.circular(bRadius) : Radius.zero,
        topRight: isStartCols ? Radius.zero : Radius.circular(bRadius),
        bottomLeft: isStartCols ? Radius.circular(bRadius) : Radius.zero,
        bottomRight: isStartCols ? Radius.zero : Radius.circular(bRadius),
      ),
      color: styleBox.config.decoration?.color,
      border: Border(
        bottom: BorderSide(color: bColor, width: bSize),
        top: BorderSide(color: bColor, width: bSize),
        left:
            isStartCols
                ? BorderSide(color: bColor, width: bSize)
                : BorderSide.none,
        right:
            isStartCols
                ? BorderSide.none
                : BorderSide(color: bColor, width: bSize),
      ),
    );

    if (elevation != null) {
      return Container(
        margin: EdgeInsets.fromLTRB(
          isStartCols ? pleft : 0,
          ptop,
          isStartCols ? 0 : pright,
          pbottom,
        ),
        child: Material(
          elevation: elevation,
          borderRadius: boxDecoration.borderRadius,
          child: Container(
            decoration: boxDecoration,
            padding: EdgeInsets.fromLTRB(
              isStartCols ? mleft : 0,
              mtop,
              isStartCols ? 0 : mright,
              mbottom,
            ),
            child: child,
          ),
        ),
      );
    } else {
      return Container(
        margin: EdgeInsets.fromLTRB(
          isStartCols ? pleft : 0,
          ptop,
          isStartCols ? 0 : pright,
          pbottom,
        ),
        decoration: boxDecoration,
        padding: EdgeInsets.fromLTRB(
          isStartCols ? mleft : 0,
          mtop,
          isStartCols ? 0 : mright,
          mbottom,
        ),
        child: child,
      );
    }
  }
}
