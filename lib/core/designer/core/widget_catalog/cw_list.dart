import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/editor/view/prop_editor/helper_editor.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/core/cw_slot.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';
import 'package:jsonschema/feature/content/state_manager.dart';

class CwList extends CwWidget {
  const CwList({super.key, required super.ctx});

  static void initFactory(WidgetFactory factory) {
    factory.register(
      id: 'list',
      build: (ctx) => CwList(key: ctx.getKey(), ctx: ctx),
      config: (ctx) {
        return CwWidgetConfig();
      },
    );
  }

  @override
  State<CwList> createState() => _CwListState();
}

class _CwListState extends CwWidgetStateBindJson<CwList> with HelperEditor {
  late final ScrollController controller;

  GlobalKey parentKey = GlobalKey(debugLabel: '_CwListState parentKey');

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

  Widget getScrollCapable(Widget child) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 100, maxHeight: 100),
      child: ScrollbarTheme(
        data: ScrollbarThemeData(
          //thumbColor: WidgetStateProperty.all(Colors.red),
        ),

        child: Scrollbar(
          controller: controller,
          thumbVisibility: true,
          child: child,
        ),
      ),
    );
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

      var rowState = getRowState(context);
      var primaryList = rowState == null ? true : false;
      bool withScroll = primaryList;

      if (!withScroll) {
        return ListView(
          shrinkWrap: true, // prends la taille necessaire
          physics: NeverScrollableScrollPhysics(),
          key: parentKey,
          children: List.generate(listRow.length, (index) {
            // print("add CWInheritedRow 2 $pathData index $index ${listRow[index]}");
            return CWInheritedRow(
              parentKey: parentKey,
              path: pathData,
              rowIdx: index,
              child: getSlot(
                CwSlotProp(id: 'item0', name: 'Item ${index + 1}'),
              ),
            );
          }),
        );
      }

      return getScrollCapable(
        ListView.builder(
          controller: controller,
          primary: false,
          key: parentKey,
          itemCount: listRow.length,
          shrinkWrap: false, // avec autoscroll
          itemBuilder: (context, index) {
            // print("add CWInheritedRow $pathData index $index ${listRow[index]}");
            return CWInheritedRow(
              parentKey: parentKey,
              path: pathData,
              rowIdx: index,
              child: getSlot(
                CwSlotProp(id: 'item0', name: 'Item ${index + 1}'),
              ),
            );
          },
        ),
      );
    });
  }
}

class CWInheritedRow extends InheritedWidget {
  const CWInheritedRow({
    super.key,
    required super.child,
    required this.path,
    required this.rowIdx,
    required this.parentKey,
  });
  final String path;
  final int rowIdx;
  final GlobalKey parentKey;

  void getAll(Map<String, CWInheritedRow> list) {
    var r =
        parentKey.currentContext
            ?.getInheritedWidgetOfExactType<CWInheritedRow>();
    if (r != null) {
      list[r.path] = r;
      r.getAll(list);
    }
  }

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return true;
  }
}
