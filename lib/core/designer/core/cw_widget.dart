import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_iconpicker/Serialization/icondata_serialization.dart';
import 'package:jsonschema/core/compute/core_expression.dart';
import 'package:jsonschema/core/designer/core/cw_constraint_builder.dart';
import 'package:jsonschema/core/designer/core/widget_catalog/cw_mask_helper.dart';
import 'package:jsonschema/core/designer/core/widget_catalog/cw_table_row.dart';
import 'package:jsonschema/core/designer/editor/engine/undo_manager.dart';
import 'package:jsonschema/core/designer/editor/view/prop_editor/helper_editor.dart';
import 'package:jsonschema/core/designer/editor/view/prop_editor/bool_editor.dart';
import 'package:jsonschema/core/designer/editor/view/prop_editor/color_editor.dart';
import 'package:jsonschema/core/designer/editor/view/prop_editor/icon_editor.dart';
import 'package:jsonschema/core/designer/editor/view/prop_editor/slider_editor.dart';
import 'package:jsonschema/core/designer/editor/view/prop_editor/text_editor.dart';
import 'package:jsonschema/core/designer/editor/view/prop_editor/toogle_editor.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_selectable.dart';
import 'package:jsonschema/core/designer/core/cw_widget_style.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/core/cw_repository.dart';
import 'package:jsonschema/core/designer/core/cw_slot.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_event_bus.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/util.dart';
import 'package:jsonschema/feature/content/state_manager.dart';
import 'package:jsonschema/feature/content/widget/widget_content_input.dart';

class CwWidgetCtxSlot extends CwWidgetCtx {
  CwWidgetCtxSlot({
    required super.aFactory,
    required super.slotId,
    required super.parentCtx,
  });
}

class CwWidgetCtxVirtual extends CwWidgetCtx {
  CwWidgetCtxVirtual({
    required super.aFactory,
    required super.slotId,
    required super.parentCtx,
  });
}

class CwWidgetCtx {
  int buildSlotTime = 0;
  int changeTime = 0;
  //Map<String, CwSlot> cacheWidgetSlots = {};

  final WidgetFactory aFactory;
  final String slotId;

  CwWidgetCtx? parentCtx;
  Map<String, CwWidgetCtx>? childrenCtx;

  Map<String, dynamic>? dataWidget;
  CwWidgetState? widgetState;

  CWWidgetCtxSelector? _selectorCtx;
  CwSlotProp? slotProps;

  CwWidgetCtx({
    required this.aFactory,
    required this.slotId,
    required this.parentCtx,
  }) {
    if (aFactory.isModeDesigner()) {
      _selectorCtx ??= CWWidgetCtxSelector();
    }
    // dev.log("CwWidgetCtx created: $aWidgetPath");
  }

  CWWidgetCtxSelector get selectorCtx {
    _selectorCtx ??= CWWidgetCtxSelector();
    return _selectorCtx!;
  }

  CWWidgetCtxSelector? get selectorCtxIfDesign {
    if (aFactory.isModeViewer()) {
      return null;
    }
    _selectorCtx ??= CWWidgetCtxSelector();
    return _selectorCtx!;
  }

  GlobalKey? getKey() {
    if (aFactory.isModeViewer()) {
      // pas de GlobalKey en mode viewer sinon duplicate dans les listes
      return null;
    }
    selectorCtx._widgetKey = GlobalKey(
      debugLabel:
          'cw path ${parentCtx == null ? slotId : '${parentCtx!.aWidgetPath}/$slotId'}',
    );
    return selectorCtx._widgetKey;
  }

  GlobalKey? getInnerKey() {
    if (aFactory.isModeViewer()) {
      // pas besoin de GlobalKey en mode viewer
      return null;
    }

    selectorCtx._innerKey = GlobalKey(
      debugLabel:
          parentCtx == null
              ? slotId
              : '${parentCtx!.aWidgetPath}/$slotId-inner',
    );
    return selectorCtx._innerKey;
  }

  GlobalKey? getBoxKey() {
    if (selectorCtx._widgetKey?.currentState?.mounted == true) {
      return selectorCtx._widgetKey;
    } else {
      return selectorCtx.selectableState?.captureKey;
    }
  }

  String get aWidgetPath {
    if (parentCtx != null) {
      return '${parentCtx!.aWidgetPath}/$slotId';
    }
    return slotId;
  }

  bool isType(List<String> type) {
    return type.contains(dataWidget?[cwImplement]);
  }

  bool isParentOfType(List<String> type, {String? layout}) {
    if (parentCtx != null &&
        type.contains(parentCtx!.dataWidget?[cwImplement])) {
      var lay = parentCtx?.dataWidget?[cwProps]?['layout'];
      if (layout == null || lay == layout) {
        return true;
      }
    }
    return false;
  }

  bool hasParentOfType(List<String> type, {String? layout}) {
    if (isParentOfType(type, layout: layout)) {
      return true;
    }
    var current = parentCtx;
    while (current != null) {
      if (current.isParentOfType(type, layout: layout)) {
        return true;
      }
      current = current.parentCtx;
    }
    return false;
  }

  CwWidgetCtxSlot cloneForSlot() {
    var ret = CwWidgetCtxSlot(
      slotId: slotId,
      aFactory: aFactory,
      parentCtx: parentCtx,
    );
    ret.dataWidget = parentCtx?.getData()?[cwSlots]?[slotId];
    ret.widgetState = parentCtx?.widgetState;
    ret.selectorCtxIfDesign?.selectableState =
        parentCtx?.selectorCtxIfDesign?.selectableState;
    ret.selectorCtxIfDesign?._widgetKey = selectorCtxIfDesign?._widgetKey;
    return ret;
  }

  String getPropsName() {
    return this is CwWidgetCtxSlot ? cwPropsSlot : cwProps;
  }

  CwWidgetCtx getSlotCtx(String cid, {Map? data, bool virtual = false}) {
    var wd = data ?? getData();
    if (childrenCtx?[cid] != null) {
      var ret = childrenCtx![cid]!;
      ret.dataWidget = wd?[cwSlots]?[cid];
      return ret;
    }

    if (virtual) {
      var c = CwWidgetCtxVirtual(
        slotId: cid,
        aFactory: aFactory,
        parentCtx: this,
      );
      childrenCtx ??= {};
      childrenCtx![cid] = c;
      c.dataWidget = wd?[cwSlots]?[cid];
      return c;
    } else {
      var c = CwWidgetCtx(slotId: cid, aFactory: aFactory, parentCtx: this);
      childrenCtx ??= {};
      childrenCtx![cid] = c;
      c.dataWidget = wd?[cwSlots]?[cid];
      return c;
    }
  }

  void createDataOnParentIfNeeded() {
    if (parentCtx != null && parentCtx!.dataWidget![cwSlots]?[slotId] == null) {
      dataWidget = aFactory.addInSlot(parentCtx!.dataWidget!, slotId, {});
    }
  }

  List<Map<String, dynamic>> initBehaviorIfNeeded() {
    var props = getData()![cwBehaviors];
    if (props == null) {
      props = <Map<String, dynamic>>[];
      getData()![cwBehaviors] = props;
    }
    return props;
  }

  Map<String, dynamic> initPropsIfNeeded({List<String>? path}) {
    var props = getData()![getPropsName()];
    if (props == null) {
      props = <String, dynamic>{};
      getData()![getPropsName()] = props;
    }
    for (var p in path ?? []) {
      if (props[p] == null) {
        props[p] = <String, dynamic>{};
      }
      props = props[p];
    }
    return props;
  }

  bool isEmptySlot() {
    return dataWidget?[cwImplement] == null;
  }

  bool isDesignSelected() {
    return currentSelectorManager.lastSelectedCtx == this;
  }

  Map? getData() {
    return dataWidget ?? parentCtx?.getData()?[cwSlots]?[slotId];
  }

  CwWidgetConfig? getConfig() {
    if (getData()?[cwImplement] == null) return null;
    return aFactory.builderConfig[getData()![cwImplement]]!(this);
  }

  ValueChanged<Map> onValueChange(
    CwWidgetProperties properties, {
    bool repaint = true,
    bool repaintParent = false,
    bool resize = true,
    bool unselect = false,
    List<String>? path,
  }) {
    return (newJson) {
      var propBeforeChange = getData()![getPropsName()];
      if (path != null) {
        getData()![getPropsName()] ??= <String, dynamic>{};
        propBeforeChange = getData()![getPropsName()];
        for (var i = 0; i < path.length; i++) {
          propBeforeChange![path[i]] ??= <String, dynamic>{};
          propBeforeChange = propBeforeChange[path[i]];
        }
      }
      final deepClone = jsonDecode(jsonEncode(propBeforeChange));
      print(
        "do onValueChange for $aWidgetPath value = $propBeforeChange with $newJson",
      );

      globalUndoManager.execute(
        UndoAction(
          doAction: () {
            doChange(
              properties: properties,
              repaint: repaint,
              repaintParent: repaintParent,
              resize: resize,
              unselect: unselect,
              path: path,
              newJson: newJson,
            );
          },
          undoAction: () {
            doChange(
              properties: properties,
              repaint: repaint,
              repaintParent: repaintParent,
              resize: resize,
              unselect: unselect,
              path: path,
              newJson: deepClone,
            );
          },
        ),
      );
    };
  }

  void doChange({
    required CwWidgetProperties properties,
    required bool repaint,
    required bool repaintParent,
    required bool resize,
    required bool unselect,
    List<String>? path,
    required Map newJson,
  }) {
    createDataOnParentIfNeeded();
    Map? prop = getData()![getPropsName()];
    if (path != null) {
      getData()![getPropsName()] ??= <String, dynamic>{};
      prop = getData()![getPropsName()];
      for (var i = 0; i < path.length; i++) {
        prop![path[i]] ??= <String, dynamic>{};
        prop = prop[path[i]];
      }
    }
    if (prop == null) {
      getData()![getPropsName()] = newJson;
    } else {
      if (newJson[properties.id] == null) {
        prop.remove(properties.id);
      } else {
        prop[properties.id] = newJson[properties.id];
      }
    }

    initChanged();

    if (repaint) {
      if (this is CwWidgetCtxVirtual) {
        widgetState = parentCtx?.widgetState;
      }

      CwWidgetState? aWidgetState = widgetState;
      if (aWidgetState == null || aWidgetState.mounted == false) {
        // cas de slot vide
        parentCtx?.initChanged();
        aWidgetState = parentCtx?.widgetState;
      }
      if (aWidgetPath == "") {
        // cas de la racine qui n'a pas toujours de widgetState
        aWidgetState = aFactory.rootCtx?.widgetState;
      }

      if (aWidgetState == null || aWidgetState.mounted == false) {
        print(
          'ERROR: onValueChange state is null for $aWidgetPath ${aWidgetState?.hashCode}',
        );
        return;
      }
      aWidgetState.widget.ctx.repaint();
      // // ignore: invalid_use_of_protected_member
      // aWidgetState.setState(() {});
    }

    if (repaintParent) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        parentCtx!.repaint();
      });
    }

    if (currentSelectorManager.getSelectedPath() != aWidgetPath) {
      // changement d'un parent, on reselectionne onlyOverlay
      SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
        selectOnDesigner(onlyOverlay: true);
      });
    } else if (unselect) {
      emitLater(CDDesignEvent.unselect, null);
    } else if (resize) {
      emitLater(CDDesignEvent.reselect, null, multiple: true);
    }
  }

  void initChanged() {
    changeTime = DateTime.now().millisecondsSinceEpoch;
  }

  bool hasChangedSince(int time) {
    if (!withWidgetCache) {
      return true;
    }
    return changeTime > time;
  }

  void cleanWidgetData(int buildtime) {
    //remove children from ctx if buildtime different
    if (buildtime >= 0) {
      childrenCtx?.removeWhere(
        (key, value) => value.buildSlotTime != buildtime,
      );
    }

    _cleanSlotNotUse();

    // clean props if empty
    var prop = dataWidget?[cwProps] as Map?;
    if (prop?.isEmpty == true) {
      dataWidget?.remove(cwProps);
    } else {
      if (prop?[cwStyle] is Map && (prop?[cwStyle] as Map).isEmpty) {
        prop!.remove(cwStyle);
      } else {
        if (prop?[cwStyle] is Map) {
          var styleMap = prop![cwStyle] as Map;
          styleMap.removeWhere((key, value) => value == '' || value == null);
          if (styleMap.isEmpty) {
            prop.remove(cwStyle);
          }
        }
      }
    }

    // clean propsSlots if empty
    prop = dataWidget?[cwPropsSlot] as Map?;
    if (prop?.isEmpty == true) {
      dataWidget?.remove(cwPropsSlot);
    }
  }

  void _cleanSlotNotUse() {
    var slots = dataWidget?[cwSlots] as Map?;
    List<String> slotIdsToRemove = [];
    for (MapEntry entry in slots?.entries ?? const []) {
      var cid = entry.key;
      var data = entry.value as Map<String, dynamic>;
      var ctxChild = childrenCtx?[cid];
      var type = data[cwImplement];
      if (type != 'datasrc') {
        // keep data source even if not used
        // because it can be used by other component
        // later
      } else if (ctxChild == null) {
        // remove unused slot
        slotIdsToRemove.add(cid);
      } else {
        var pp = data[cwProps] as Map<String, dynamic>?;
        var ps = data[cwPropsSlot] as Map<String, dynamic>?;
        if (type == null &&
            (pp == null || pp.isEmpty) &&
            (ps == null || ps.isEmpty)) {
          slotIdsToRemove.add(cid);
        }
      }
    }
    for (var cid in slotIdsToRemove) {
      slots?.remove(cid);
    }

    if (slots == null || slots.isEmpty) {
      dataWidget?.remove(cwSlots);
    }
  }

  void selectParentOnDesigner() {
    emit(
      CDDesignEvent.select,
      CWEventCtx()
        ..ctx = parentCtx
        ..path = parentCtx!.aWidgetPath,
    );
    parentCtx!.repaintSelectorForEnableDrag();

    emitLater(
      CDDesignEvent.select,
      //waitFrame: 1,
      CWEventCtx()
        ..extra = {'displayProps': false}
        ..ctx = parentCtx
        ..path = parentCtx!.aWidgetPath
        ..callback = () {},
      multiple: true,
    );
  }

  void selectOnDesigner({bool onlyOverlay = false}) {
    emit(
      CDDesignEvent.select,
      CWEventCtx()
        ..extra = {'displayProps': !onlyOverlay}
        ..ctx = this
        ..path = aWidgetPath
        ..callback = () {},
    );

    repaintSelectorForEnableDrag();

    emitLater(
      CDDesignEvent.select,
      //waitFrame: 1,
      CWEventCtx()
        ..extra = {'displayProps': false}
        ..ctx = this
        ..path = aWidgetPath
        ..callback = () {
          //repaintSelector();
        },
      multiple: true,
    );
  }

  // permet le drag après une sélection
  void repaintSelectorForEnableDrag() {
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      if (selectorCtx.selectableState?.mounted == true) {
        // ignore: invalid_use_of_protected_member
        selectorCtx.selectableState?.setState(() {});
      }
    });
  }

  void clearWidgetCache({bool clearInnerWidget = false}) {
    initChanged();
    widgetState?.clearWidgetCache(clearInnerWidget: clearInnerWidget);
  }

  void repaint() {
    initChanged();
    _selectorCtx?.slotState?.repaint();
    if (widgetState != null && widgetState!.mounted) {
      // ignore: invalid_use_of_protected_member
      widgetState!.setState(() {});
    }
  }

  void setSelectorCtx(CwWidgetCtx ctxSrc) {
    _selectorCtx = ctxSrc._selectorCtx;
    widgetState = ctxSrc.widgetState;
  }

  CwWidgetCtx? findByPath(String path) {
    if (path == aWidgetPath) {
      return this;
    }
    if (childrenCtx != null) {
      for (var c in childrenCtx!.values) {
        var found = c.findByPath(path);
        if (found?.aWidgetPath == path) {
          return found;
        }
      }
    }
    return null;
  }

  dynamic getDataValueForEval({
    String? jsonPath,
    String? pathJson,
    required Map<String, AttributBindInfo>? listBindInfo,
    required CwWidgetStateBindJson? state,
    required BuildContext context,
  }) {
    Map bind = dataWidget?[cwProps]?['bind'];
    String repoId = bind['repository'];
    var repository = aFactory.mapRepositories[repoId];
    var stateRepository = repository?.dataState;

    AttributBindInfo bindInfo = AttributBindInfo();
    bindInfo.stateRepository = stateRepository;
    bindInfo.repository = repository;
    bindInfo.bindAttribut = AttributInfo();
    String path = jsonPath!.replaceAll(".", ">");
    var p = 'root>$path';
    bindInfo.bindAttribut!.path = p;
    bool inArray = parentCtx?.isType(['list', 'table']) ?? false;
    var ret = bindInfo.getValue(context, this, state!, inArray, false);
    return ret;
  }

  CwWidgetCtx? findParentArrayContainer() {
    CwWidgetCtx? arrayCtx;
    CwWidgetCtx? aParentCtx = parentCtx;

    while (aParentCtx != null && arrayCtx == null) {
      if (aParentCtx.dataWidget?[cwImplement] == 'table') {
        arrayCtx = aParentCtx;
        break;
      }
      aParentCtx.childrenCtx?.entries.forEach((e) {
        if (e.value.dataWidget?[cwImplement] == 'table') {
          arrayCtx = e.value;
        }
      });
      aParentCtx = aParentCtx.parentCtx;
    }

    return arrayCtx;
  }

  List<CwWidgetCtx> getAllCellsCtx() {
    List<CwWidgetCtx> data = [];
    List<CwWidgetCtx> dataCompute = [];
    childrenCtx?.entries.forEach((e) {
      if (e.key.startsWith('cell_')) {
        findAllInputCtx(e.value, data, dataCompute);
      }
    });
    data.addAll(dataCompute);
    return data;
  }

  void findAllInputCtx(
    CwWidgetCtx value,
    List<CwWidgetCtx> data,
    List<CwWidgetCtx> dataCompute,
  ) {
    if (value.dataWidget?[cwImplement] == 'input') {
      if ((value.widgetState as CwWidgetStateBindJson).bindInfo.computedInfo !=
          null) {
        dataCompute.add(value);
      } else {
        data.add(value);
      }
    }
    value.childrenCtx?.entries.forEach((e) {
      findAllInputCtx(e.value, data, dataCompute);
    });
  }

  dynamic getValueFromRow(
    Map row,
    CwWidgetStateBindJson<CwWidget> arrayState,
    String? pathArray,
  ) {
    var b = widgetState as CwWidgetStateBindJson;
    if (b.bindInfo.computedInfo != null) {
      var eval = CoreExpression();
      eval.init(
        b.bindInfo.computedInfo!["expression"],
        logs: [],
        isAsync: false,
      );

      var r = eval.eval(
        variables: {
          '\$\$__ctx__\$\$': this,
          '\$\$__row__\$\$': row,
          '\$\$__rowPath__\$\$': arrayState.bindInfo.bindAttribut?.getJsonPath(
            sep: '.',
            withRoot: false,
          ),
        },
        logs: [],
      );
      return r;
    } else {
      var pathD = b.bindInfo.bindAttribut?.getJsonPath(sep: '/');
      if (pathD != null && pathArray != null) {
        String path = pathD.substring(pathArray.length + 1);
        // print('export pathD=$pathD pathA=$pathArray path=$path');
        var v = getValueFromPath(row, path);
        // print('export value=$v');
        return v;
      }
    }
  }
}

class CWWidgetCtxSelector {
  Size? lastSizeForDrag;
  String? inSlotName;
  CwSlotState? slotState;

  GlobalKey? _widgetKey;
  GlobalKey? _innerKey;
  bool withPadding = false;

  WidgetSelectableState? selectableState;

  Map<String, dynamic>? extraRenderingData;
}

class CachedWidget {
  int buildtime = 0;
  Widget? builtWidget;
  BoxConstraints? lastConstraints;

  void dispose() {
    builtWidget = null;
  }
}

abstract class CwWidget extends StatefulWidget {
  //final CachedWidget cacheWidget = CachedWidget();
  final CachedWidget cacheWidget;
  final CwWidgetCtx ctx;
  const CwWidget({super.key, required this.ctx, required this.cacheWidget});
}

class AttributBindInfo {
  CoreExpression? eval;

  CwRepository? repository;
  StateRepository? stateRepository;
  Map? computedInfo;

  String pathData = '?';
  AttributInfo? bindAttribut;
  bool isPrimitiveArrayValue = false; // bind sur un tableau de string ou nombre

  String? attrName;
  StateContainer? dataContainer;

  void initBind(CwWidgetCtx widgetCtx) {
    Map? bind = widgetCtx.dataWidget?[cwProps]?['bind'];
    if (bind != null) {
      String repoId = bind['repository'];
      repository = widgetCtx.aFactory.mapRepositories[repoId];
      if (repository != null && bind['from'] == 'criteria') {
        String attrMasterPath = bind['attr'];
        stateRepository = repository!.criteriaState;
        bindAttribut =
            repository!.ds.helper!.apiCallInfo.currentAPIRequest!
                .getNodeByMasterIdPath(attrMasterPath)
                ?.info;
      } else if (repository != null && bind['from'] == 'data') {
        String? attrMasterPath = bind['attr'];
        stateRepository = repository!.dataState;
        if (attrMasterPath?.startsWith('self@') ?? false) {
          // bind sur un tableau de string ou nombre
          attrMasterPath = attrMasterPath!.substring(5);
          isPrimitiveArrayValue = true;
        }
        bindAttribut =
            repository!.ds.modelHttp200!
                .getNodeByMasterIdPath(attrMasterPath)
                ?.info;
      } else if (repository != null && bind['computedId'] != null) {
        stateRepository = repository!.dataState;
        Map aComputedInfo =
            widgetCtx.aFactory.appData[cwRepos][repoId][cwComputed];
        String computedId = bind['computedId'];
        if (aComputedInfo[computedId] != null) {
          computedInfo = aComputedInfo[computedId];
          String expression = computedInfo!['expression'];
          if (widgetCtx.aFactory.isModeViewer()) {
            eval = CoreExpression();
            eval!.init(expression, logs: [], isAsync: true);
          }
        }
      }
    }
  }

  dynamic getValue(
    BuildContext context,
    CwWidgetCtx ctx,
    CwWidgetStateBindJson state,
    bool inArray,
    bool typeListContainer,
  ) {
    var modeDesigner = ctx.aFactory.isModeDesigner();
    String? oldPathData = pathData;

    pathData = stateRepository!.getDataPath(
      context,
      isPrimitiveArrayValue ? '${bindAttribut!.path}>*' : bindAttribut!.path,
      typeListContainer: typeListContainer,
      widgetPath: ctx.aWidgetPath,
      inListOrArray: inArray,
      state: state,
    );

    if (isPrimitiveArrayValue) {
      // bind sur un tableau de string ou nombre
      int i = pathData.lastIndexOf('[');
      int i2 = pathData.lastIndexOf(']');
      var substring = pathData.substring(i + 1, i2);
      pathData = pathData.substring(0, i);
      int idx = int.tryParse(substring) ?? 0;
      StateContainer? dataContainer;
      (dataContainer, _) = stateRepository!.getStateContainer(
        pathData,
        context: context,
        pathWidgetRepos: ctx.aWidgetPath,
      );
      //print('object $pathData => ${dataContainer?.jsonData} + $idx');
      dynamic val = dataContainer!.jsonData[idx];
      return val?.toString() ?? '';
    } else {
      if (oldPathData != '?' && oldPathData != pathData) {
        if (typeListContainer) {
          stateRepository!.depsBindingManager.disposeContainer(
            oldPathData,
            state,
          );
        } else {
          stateRepository!.depsBindingManager.disposeInput(oldPathData, state);
        }
      }
      if (typeListContainer) {
        stateRepository!.depsBindingManager.registerContainer(pathData, state);
      } else {
        stateRepository!.depsBindingManager.registerInput(pathData, state);
      }

      String pathContainer;
      String aAttrName;
      (pathContainer, aAttrName) = stateRepository!.getSplitPathInfo(pathData);
      attrName = aAttrName;
      StateContainer? aDataContainer;

      (aDataContainer, _) = stateRepository!.getStateContainer(
        pathContainer,
        context: context,
        pathWidgetRepos: ctx.parentCtx!.aWidgetPath,
      );
      dataContainer = aDataContainer;
      if (dataContainer != null) {
        dynamic val = dataContainer!.jsonData[attrName];
        if (modeDesigner && !typeListContainer) {
          return '{$attrName}';
        } else {
          return val;
        }
      }
    }
  }

  void doChangeRow({
    String? pathWidgetRepos,
    String? pathRow,
    BuildContext? rowContext,
  }) {
    var aPathData = pathRow ?? pathData;
    if (stateRepository != null && aPathData != '?') {
      String pathContainer;
      (pathContainer, _) = stateRepository!.getSplitPathInfo(aPathData);
      (_, _) = stateRepository!.getStateContainer(
        pathContainer,
        context: rowContext,
        pathWidgetRepos: pathWidgetRepos,
        onIndexChange: (int idx) {
          print("Update data on blur $aPathData to index $idx");
          stateRepository!.depsBindingManager.reloadDependentContainers(
            aPathData,
          );
        },
      );
    }
  }
}

class CwWidgetStateBindJson<T extends CwWidget> extends CwWidgetState<T> {
  AttributBindInfo bindInfo = AttributBindInfo();

  void doChangeRowFromParent(
    BuildContext context, {
    CwWidgetStateBindJson? stateArray,
    String? pathWidgetRepos,
  }) {
    var pathRow = getPathData(
      context,
      bindInfo: bindInfo,
      stateArray: stateArray,
    );
    bindInfo.doChangeRow(
      rowContext: context,
      pathRow: pathRow,
      pathWidgetRepos: stateArray?.widget.ctx.aWidgetPath ?? pathWidgetRepos,
    );
  }

  String? getPathData(
    BuildContext context, {
    CwWidgetStateBindJson? stateArray,
    required AttributBindInfo bindInfo,
  }) {
    String r;
    if (stateArray == null &&
        bindInfo.stateRepository != null &&
        bindInfo.bindAttribut != null) {
      //String? oldPathData = pathData;
      bool inArray = widget.ctx.hasParentOfType(['list', 'table']);
      r = bindInfo.stateRepository!.getDataPath(
        // ignore: use_build_context_synchronously
        context,
        widgetPath: widget.ctx.aWidgetPath,
        bindInfo.bindAttribut!.path,
        typeListContainer: false,
        inListOrArray: inArray,
        state: this,
      );
      bindInfo.pathData = r;
    } else {
      var s = stateArray ?? widget.ctx.parentCtx?.widgetState;
      while (s != null && s is! CwWidgetStateBindJson) {
        s = s.widget.ctx.parentCtx?.widgetState;
      }
      if (s == null || s is! CwWidgetStateBindJson) {
        return null;
      }
      var pathJson =
          'root${s.bindInfo.pathData.replaceAll('/', '>').replaceAll('[*]', '[]')}';
      pathJson = '$pathJson[]>*';

      bindInfo.stateRepository = s.bindInfo.stateRepository;
      r = bindInfo.stateRepository!.getDataPath(
        // ignore: use_build_context_synchronously
        context,
        pathJson,
        widgetPath: widget.ctx.aWidgetPath,
        typeListContainer: false,
        inListOrArray: true,
        state: this,
      );
      if (stateArray == null) {
        bindInfo.pathData = r;
      }
    }
    return r;
  }

  void initBind() {
    bindInfo.initBind(widget.ctx);
  }

  void setSelectedRowIndex(int idx) {}

  void setFilterValue(String? text, List<CwWidgetCtx> listCell) {}
}

enum ModeBuilderWidget { noConstraint, layoutBuilder, constraintBuilder }

class CwWidgetState<T extends CwWidget> extends WidgetBindJsonState<T> {
  late CWStyleFactory styleFactory;
  late CachedWidget cacheWidget;

  CWInheritedRow? getRowState(BuildContext context) {
    CWInheritedRow? row =
        context.getInheritedWidgetOfExactType<CWInheritedRow>();
    return row;
  }

  @override
  void initState() {
    widget.ctx.widgetState = this;
    styleFactory = CWStyleFactory(widget.ctx);
    cacheWidget = widget.cacheWidget;
    super.initState();
  }

  bool isWidgetCacheEnable(BoxConstraints? constraints) {
    return true;
  }

  bool clearWidgetCache({bool clearInnerWidget = false}) {
    cacheWidget.dispose();
    if (clearInnerWidget) {
      widget.ctx._selectorCtx?.slotState?.widget.config.innerWidget = null;
    }
    return true;
  }

  Widget buildWidget(
    bool useContainerWrapper,
    ModeBuilderWidget mode,
    CacheWidgetBuilder builder,
  ) {
    Widget retWidget;

    switch (mode) {
      case ModeBuilderWidget.noConstraint:
        retWidget = _buildWidgetInternal(useContainerWrapper, builder, null);

      case ModeBuilderWidget.layoutBuilder:
        retWidget = LayoutBuilder(
          builder: (context, constraints) {
            cacheWidget.lastConstraints = constraints;
            return _buildWidgetInternal(
              useContainerWrapper,
              builder,
              constraints,
            );
          },
        );

      case ModeBuilderWidget.constraintBuilder:
        var cacheSizeSlot =
            widget.ctx.aFactory.cacheSizeSlots[widget.ctx.aWidgetPath];
        retWidget = ConstraintBuilder(
          fixedSize: cacheSizeSlot,
          builder: (context, constraints) {
            SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
              if (context.mounted) {
                final box = context.findRenderObject() as RenderBox;
                widget.ctx.aFactory.cacheSizeSlots[widget.ctx.aWidgetPath] =
                    box.size;
              }
            });
            cacheWidget.lastConstraints = constraints;
            return _buildWidgetInternal(
              useContainerWrapper,
              builder,
              constraints,
            );
          },
        );
    }
    return retWidget;
  }

  Widget _buildWidgetInternal(
    bool useContainerWrapper,
    CacheWidgetBuilder builder,
    BoxConstraints? constraints,
  ) {
    bool hasChanged = widget.ctx.hasChangedSince(cacheWidget.buildtime);
    if (isWidgetCacheEnable(constraints) &&
        !hasChanged &&
        cacheWidget.builtWidget != null) {
      return cacheWidget.builtWidget!;
    }

    styleFactory.init();
    styleFactory.setConfigMargin();
    styleFactory.setConfigBox();
    num? h = widget.ctx.dataWidget?[cwProps]?['height'];
    num? w = widget.ctx.dataWidget?[cwProps]?['width'];
    styleFactory.config.height = h?.toDouble();
    styleFactory.config.width = w?.toDouble();

    if (debugCreateSlotWidget) {
      print(
        ' build CwWidget ${widget.ctx.aWidgetPath} ${cacheWidget.buildtime}',
      );
    }

    cacheWidget.buildtime = DateTime.now().millisecondsSinceEpoch;
    cacheWidget.builtWidget = builder(widget.ctx, constraints, BuildInfo());
    widget.ctx.cleanWidgetData(cacheWidget.buildtime);

    cacheWidget.builtWidget = styleFactory.getStyledBox(
      cacheWidget.builtWidget!,
      context,
      initBefore: false,
      useContainerWrapper: useContainerWrapper,
    );

    return cacheWidget.builtWidget!;
  }

  @override
  Widget build(BuildContext context) {
    throw UnimplementedError();
  }

  @override
  void dispose() {
    cacheWidget.dispose();
    super.dispose();
  }

  // CwSlot getSlotFrom(Map? data, CwSlotProp slotProp) {
  //   var ret = widget.ctx.aFactory.getSlot(widget.ctx, slotProp.id, data: data);
  //   ret.config.ctx.selectorCtxIfDesign?.inSlotName = slotProp.name;
  //   ret.config.ctx.slotProps = slotProp;
  //   ret.config.ctx.buildSlotTime = buildtime;
  //   return ret;
  // }

  CwSlot getSlot(CwSlotProp slotProp, {CwWidgetCtx? fromCtx}) {
    CwSlot aSlot = widget.ctx.aFactory.getSlot(
      fromCtx ?? widget.ctx,
      slotProp.id,
    );
    aSlot.config.ctx.selectorCtxIfDesign?.inSlotName = slotProp.name;
    aSlot.config.ctx.slotProps = slotProp;
    aSlot.config.ctx.buildSlotTime = cacheWidget.buildtime;
    return aSlot;
  }

  String? getStringProp(CwWidgetCtx ctx, String propName) {
    return HelperEditor.getStringProp(ctx, propName);
  }

  Icon? getIconProp(CwWidgetCtx ctx, String propName) {
    Map<String, dynamic>? iconProp = getObjProp(ctx, propName);
    Icon? icon;
    if (iconProp != null) {
      var iconDes = deserializeIcon(iconProp);
      if (iconDes != null) {
        icon = Icon(
          iconDes.data,
          color: styleFactory.getColor('fgColor'),
          size: styleFactory.getStyleNDouble('tSize', 4),
        );
      }
    }
    return icon;
  }

  Map<String, dynamic>? getObjProp(CwWidgetCtx ctx, String propName) {
    return HelperEditor.getObjProp(ctx, propName);
  }

  int? getIntProp(CwWidgetCtx ctx, String propName) {
    return HelperEditor.getIntProp(ctx, propName);
  }

  double? getDoubleProp(CwWidgetCtx ctx, String propName) {
    return HelperEditor.getDoubleProp(ctx, propName);
  }

  bool? getBoolProp(CwWidgetCtx? ctx, String propName) {
    return HelperEditor.getBoolProp(ctx, propName);
  }

  Color? getColorFromHex(CwWidgetCtx ctx, String propName) {
    return HelperEditor.getColorProp(ctx, propName, null);
  }
}

class CwWidgetConfig {
  //Map<String, CwWidgetSlotConfig> slotsConfig = {};
  List<CwWidgetProperties> properties = [];
  List<CwWidgetProperties> style = [];

  CwWidgetConfig();

  // CwWidgetConfig addSlot(CwWidgetSlotConfig prop) {
  //   slotsConfig[prop.id] = prop;
  //   return this;
  // }

  CwWidgetConfig addProp(CwWidgetProperties prop) {
    properties.add(prop);
    return this;
  }

  CwWidgetConfig addStyle(CwWidgetProperties prop) {
    style.add(prop);
    return this;
  }
}

class CwWidgetSlotConfig {
  final String id;

  CwWidgetSlotConfig({required this.id});
}

class CwWidgetProperties {
  final String id;
  final String name;
  Widget? input;
  Map<String, dynamic>? json;
  final bool withEditor;

  CwWidgetProperties({
    required this.id,
    required this.name,
    this.withEditor = true,
  });

  Map<String, dynamic> jsonFromCtx(CwWidgetCtx ctx, List<String>? path) {
    ctx.createDataOnParentIfNeeded();
    json = ctx.initPropsIfNeeded(path: path);
    final deepClone = jsonDecode(jsonEncode(json));
    return deepClone!;
  }

  void isIcon(CwWidgetCtx ctx, {List<String>? path}) {
    var json = jsonFromCtx(ctx, path);
    if (withEditor == false) {
      input = null;
      return;
    }
    input = IconEditor(
      key: ValueKey('$id@${json.hashCode}'),
      json: json,
      config: this,
      onJsonChanged: ctx.onValueChange(this, path: path),
    );
  }

  void isSize(
    CwWidgetCtx ctx, {
    int defaultValue = 0,
    ValueChanged<Map>? onJsonChanged,
    List<String>? path,
  }) {
    var cwPropHeight = CwWidgetProperties(
      id: 'height',
      name: 'height',
      withEditor: withEditor,
    );
    isInt(
      (ctx),
      defaultValue: defaultValue,
      onJsonChanged: (value) {
        ctx.onValueChange(
          cwPropHeight,
          path: path,
          repaintParent: ctx.isParentOfType(['table']),
        )(value);
      },
      path: path,
      config: cwPropHeight,
    );
    var i1 = input!;
    var cwPropWidth = CwWidgetProperties(
      id: 'width',
      name: 'width',
      withEditor: withEditor,
    );
    isInt(
      (ctx),
      defaultValue: defaultValue,
      onJsonChanged: (value) {
        ctx.onValueChange(
          cwPropWidth,
          path: path,
          repaintParent: ctx.isParentOfType(['table']),
        )(value);
      },
      path: path,
      config: cwPropWidth,
    );
    var i2 = input!;
    if (withEditor == false) {
      input = null;
      return;
    }
    input = Row(children: [Flexible(child: i1), Flexible(child: i2)]);
  }

  void isInt(
    CwWidgetCtx ctx, {
    int defaultValue = 0,
    ValueChanged<Map>? onJsonChanged,
    List<String>? path,
    CwWidgetProperties? config,
  }) {
    var idd = config?.id ?? id;
    var json = jsonFromCtx(ctx, path);
    if (withEditor == false) {
      input = null;
      return;
    }
    input = TextEditor(
      info: TextfieldBuilderInfo(
        label: name,
        bindType: 'INT',
        editable: true,
        enable: true,
      ),
      key: ValueKey('$idd@${json.hashCode}@${json[idd] ?? defaultValue}'),
      json: json,
      config: config ?? this,
      onJsonChanged: onJsonChanged ?? ctx.onValueChange(this, path: path),
    );
  }

  void isSlider(
    CwWidgetCtx ctx, {
    int defaultValue = 0,
    int min = 0,
    int max = 100,
    IconData? icon,
    List<String>? path,
    bool unselect = false,
  }) {
    var json = jsonFromCtx(ctx, path);
    if (withEditor == false) {
      input = null;
      return;
    }
    input = SliderEditor(
      min: min,
      max: max,
      icon: icon,
      key: ValueKey('$id@${json.hashCode}'),
      json: json,
      config: this,
      onJsonChanged: ctx.onValueChange(this, path: path, unselect: unselect),
    );
  }

  void isColor(CwWidgetCtx ctx, {IconData? icon, List<String>? path}) {
    var json = jsonFromCtx(ctx, path);
    if (withEditor == false) {
      input = null;
      return;
    }
    input = HexColorEditor(
      key: ValueKey('$id@${json.hashCode}'),
      json: json,
      config: this,
      icon: icon,
      onJsonChanged: ctx.onValueChange(this, path: path),
    );
  }

  void isBool(
    CwWidgetCtx ctx, {
    ValueChanged<Map>? onJsonChanged,
    List<String>? path,
  }) {
    var json = jsonFromCtx(ctx, path);
    if (withEditor == false) {
      input = null;
      return;
    }
    input = BoolEditor(
      key: ValueKey('$id@${json.hashCode}'),
      json: json,
      config: this,
      onJsonChanged: onJsonChanged ?? ctx.onValueChange(this, path: path),
    );
  }

  void isToogle(
    CwWidgetCtx ctx,
    List items, {
    ValueChanged<Map>? onJsonChanged,
    bool isMultiple = false,
    String? defaultValue,
    List<String>? path,
  }) {
    var json = jsonFromCtx(ctx, path);
    if (withEditor == false) {
      input = null;
      return;
    }
    input = ToogleEditor(
      defaultValue: defaultValue,
      key: GlobalKey(
        debugLabel: 'ToogleEditor',
      ), //ValueKey('$id@${json.hashCode}'),
      json: json,
      config: this,
      onJsonChanged: onJsonChanged ?? ctx.onValueChange(this, path: path),
      items: items,
      isMultiple: isMultiple,
    );
  }

  void isText(CwWidgetCtx ctx, {List<String>? path}) {
    var json = jsonFromCtx(ctx, path);
    if (withEditor == false) {
      input = null;
      return;
    }
    input = TextEditor(
      info: TextfieldBuilderInfo(
        label: name,
        bindType: 'NONE',
        editable: true,
        enable: true,
      ),
      key: ValueKey('$id@${json.hashCode}'),
      json: json,
      config: this,
      onJsonChanged: ctx.onValueChange(this, path: path),
    );
  }
}
