import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_iconpicker/Serialization/icondata_serialization.dart';
import 'package:jsonschema/core/core_expression.dart';
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

  bool isParentOfType(String type, {String? layout}) {
    if (parentCtx?.dataWidget?[cwImplement] == type) {
      var lay = parentCtx?.dataWidget?[cwProps]?['layout'];
      if (layout == null || lay == layout) {
        return true;
      }
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
      if (aWidgetState == null || aWidgetState.mounted == false) {
        print('ERROR: onValueChange state is null for $aWidgetPath');
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
}

class CWWidgetCtxSelector {
  Size? lastSize;
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

class CwWidgetStateBindJson<T extends CwWidget> extends CwWidgetState<T> {
  String pathData = '?';
  CwRepository? repository;
  StateRepository? stateRepository;
  NodeAttribut? attribut;
  bool isPrimitiveArrayValue = false; // bind sur un tableau de string ou nombre
  CoreExpression? eval;

  void setSelectedRow(
    BuildContext context, {
    CwWidgetStateBindJson? stateArray,
  }) {
    String r;
    if (stateArray == null && stateRepository != null && attribut != null) {
      //String? oldPathData = pathData;
      bool inArray = widget.ctx.parentCtx?.isType(['list', 'table']) ?? false;
      r = stateRepository!.getDataPath(
        // ignore: use_build_context_synchronously
        context,
        widgetPath: widget.ctx.aWidgetPath,
        attribut!.info.path,
        typeListContainer: false,
        inArray: inArray,
        state: this,
      );
      pathData = r;
    } else {
      var s = stateArray ?? widget.ctx.parentCtx?.widgetState;
      if (s is! CwWidgetStateBindJson) return;
      var pathJson =
          'root${s.pathData.replaceAll('/', '>').replaceAll('[*]', '[]')}';
      pathJson = '$pathJson[]>*';

      stateRepository = s.stateRepository;
      r = stateRepository!.getDataPath(
        // ignore: use_build_context_synchronously
        context,
        pathJson,
        widgetPath: widget.ctx.aWidgetPath,
        typeListContainer: false,
        inArray: true,
        state: this,
      );
      if (stateArray == null) {
        pathData = r;
      }
    }
    doChangeRow(
      rowContext: context,
      pathRow: r,
      pathWidgetRepos: stateArray?.widget.ctx.aWidgetPath,
    );
  }

  void doChangeRow({
    String? pathWidgetRepos,
    String? pathRow,
    BuildContext? rowContext,
  }) {
    if (stateRepository != null) {
      String pathContainer;
      (pathContainer, _) = stateRepository!.getPathInfo(pathRow ?? pathData);
      (_, _) = stateRepository!.getStateContainer(
        pathContainer,
        context: rowContext ?? context,
        pathWidgetRepos: pathWidgetRepos,
        onIndexChange: (int idx) {
          print("Update data on blur ${pathRow ?? pathData} to index $idx");
          stateRepository!.reloadDependentContainers(pathRow ?? pathData);
        },
      );
    }
  }

  void initBind() {
    Map? bind = widget.ctx.dataWidget?[cwProps]?['bind'];
    if (bind != null) {
      String repoId = bind['repository'];
      repository = widget.ctx.aFactory.mapRepositories[repoId];
      if (repository != null && bind['from'] == 'criteria') {
        String attrId = bind['attr'];
        stateRepository = repository!.criteriaState;
        attribut =
            repository!
                .ds
                .helper!
                .apiCallInfo
                .currentAPIRequest!
                .nodeByMasterId[attrId];
      } else if (repository != null && bind['from'] == 'data') {
        String? attrId = bind['attr'];
        stateRepository = repository!.dataState;
        if (attrId?.startsWith('self@') ?? false) {
          // bind sur un tableau de string ou nombre
          attrId = attrId!.substring(5);
          isPrimitiveArrayValue = true;
        }
        attribut = repository!.ds.modelHttp200!.nodeByMasterId[attrId];
      } else if (repository != null && bind['computedId'] != null) {
        if (widget.ctx.aFactory.isModeViewer()) {
          stateRepository = repository!.dataState;
          Map computedInfo =
              widget.ctx.aFactory.appData[cwRepos][repoId][cwComputed];
          String computedId = bind['computedId'];
          if (computedInfo[computedId] != null) {
            String expression = computedInfo[computedId]['expression'];
            eval = CoreExpression();
            eval!.init(expression, logs: []);
          }
        }
      }
    }
  }

  void setSelectedRowIndex(int idx) {}
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
    widget.ctx.widgetState = this;
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
        icon = Icon(iconDes.data, color: styleFactory.getColor('fgColor'));
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
          repaintParent: ctx.isParentOfType('table'),
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
          repaintParent: ctx.isParentOfType('table'),
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
