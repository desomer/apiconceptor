import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/component/helper/helper_editor.dart';
import 'package:jsonschema/core/designer/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/cw_slot.dart';
import 'package:jsonschema/core/designer/cw_widget.dart';
import 'package:jsonschema/core/designer/widget/cw_list.dart';
import 'package:jsonschema/core/designer/widget/cw_table_layout.dart';

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

  GlobalKey parentKey = GlobalKey();

  @override
  void initState() {
    controller = ScrollController();

    super.initState();
    initBind();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildWidget(ModeBuilderWidget.layoutBuilder, (ctx, constraints) {
      List listRow = [];

      if (stateRepository != null) {
        String? oldPathData = pathData;

        pathData = stateRepository!.getDataPath(
          context,
          attribut!.info,
          typeList: true,
        );
        if (oldPathData != '?' && oldPathData != pathData) {
          stateRepository!.disposeContainer(oldPathData, this);
        }
        stateRepository!.registerContainer(pathData, this);

        String pathContainer;
        String attrName;
        (pathContainer, attrName) = stateRepository!.getPathInfo(pathData);
        var dataContainer = stateRepository!.getStateContainer(pathContainer);
        if (dataContainer != null) {
          listRow = dataContainer.jsonData[attrName] ?? [];
        }
      }

      //var rowState = getRowState(context);
      //var primaryList = rowState == null ? true : false;
      //bool withScroll = primaryList;

      var wd = ctx.dataWidget!; //![cwSlots]!['item0'];
      Widget cell(int row, int col) {
        var cell = wd[cwSlots]?['cell_$col'];
        if (row == 0) {
          return Container(
            color: Colors.grey.withAlpha(100),
            child: Center(child: Text(cell?[cwProps]?['label'] ?? 'col. $col')),
          );
        }

        return getSlot(CwSlotProp(id: 'cell_$col', name: 'Cell $col'));
      }

      int nbCol = getIntProp(ctx, 'nbchild') ?? 0;

      return FrozenTableView(
        key: parentKey,
        colCount: nbCol,
        rowCount: listRow.length + 1,
        buildTopCell: cell,
        buildBottomCell: cell,
        buildLeftCell: cell,
        buildBodyCell: cell,
        rowCountTop: 1,
        rowCountBottom: 0,
        colFreezeLeftCount: 1,
        buildRow: (int row, Widget child) {
          return CWInheritedRow(
            parentKey: parentKey,
            path: pathData,
            rowIdx: row - 1,
            child: child,
          );
        },

        getColWidth: (int col) {
          return 200;
        },
        getRowHeight: (int row) {
          if (row == 0) {
            return 30;
          }
          return 50;
        },
      );
    });
  }
}
