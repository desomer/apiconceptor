import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/component/helper/helper_editor.dart';
import 'package:jsonschema/core/designer/cw_factory.dart';
import 'package:jsonschema/core/designer/cw_slot.dart';
import 'package:jsonschema/core/designer/cw_widget.dart';

class CwList extends CwWidget {
  const CwList({super.key, required super.ctx});

  static void initFactory(WidgetFactory factory) {
    factory.register(
      id: 'list',
      build: (ctx) => CwList(ctx: ctx),
      config: (ctx) {
        return CwWidgetConfig();
      },
    );
  }

  @override
  State<CwList> createState() => _CwListState();
}

class _CwListState extends CwWidgetStateBindJson<CwList> with HelperEditor {
  @override
  void initState() {
    super.initState();
    initBind();
  }

  GlobalKey parentKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return buildWidget(true, (ctx, constraints) {
      List listRow = [];

      if (stateRepository != null) {
        String? oldPathData = pathData;

        pathData = stateRepository!.getDataPath(
          context,
          attribut!.info,
          typeList: true,
        );
        if (oldPathData != '?' && oldPathData != pathData) {
          stateRepository!.disposeContainer(oldPathData);
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

      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 100, maxHeight: 200),
        child: ListView.builder(
          key: parentKey,
          itemCount: listRow.length,
          shrinkWrap: true,
          itemBuilder: (context, index) {
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
