import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jsonschema/core/designer/core/cw_constraint_builder.dart';
import 'package:jsonschema/core/designer/core/widget_catalog/cw_mask_helper.dart';
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
import 'package:jsonschema/core/designer/core/widget_catalog/cw_list.dart';
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
          'key -${parentCtx == null ? slotId : '${parentCtx!.aWidgetPath}/$slotId'}',
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
      if (lay == layout) {
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

  ValueChanged<Map> onValueChange({
    bool repaint = true,
    bool resize = true,
    bool unselect = false,
    List<String>? path,
  }) {
    return (newJson) {
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
        prop.addAll(newJson);
      }

      if (repaint) {
        if (this is CwWidgetCtxVirtual) {
          widgetState = parentCtx?.widgetState;
        }

        CwWidgetState? aWidgetState = widgetState;
        if (aWidgetState == null || aWidgetState.mounted == false) {
          // cas de slot vide
          aWidgetState = parentCtx?.widgetState;
        }
        if (aWidgetState == null || aWidgetState.mounted == false) {
          print('ERROR: onValueChange state is null for $aWidgetPath');
          return;
        }
        // ignore: invalid_use_of_protected_member
        aWidgetState.setState(() {});
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
    };
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
        ..callback = () {
          //repaintSelector();
        },
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

  void repaint() {
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

  GlobalKey? _widgetKey;
  GlobalKey? _innerKey;
  bool withPadding = false;

  WidgetSelectableState? selectableState;
  CwSlotState? slotState;

  Map<String, dynamic>? extraRenderingData;
}

abstract class CwWidget extends StatefulWidget {
  final CwWidgetCtx ctx;
  const CwWidget({super.key, required this.ctx});
}

class CwWidgetStateBindJson<T extends CwWidget> extends CwWidgetState<T> {
  String pathData = '?';
  CwRepository? repository;
  StateRepository? stateRepository;
  NodeAttribut? attribut;
  bool isPrimitiveArrayValue = false; // bind sur un tableau de string ou nombre

  void doChangeRow() {
    if (stateRepository != null) {
      String pathContainer;
      (pathContainer, _) = stateRepository!.getPathInfo(pathData);
      //StateContainer? dataContainer;
      (_, _) = stateRepository!.getStateContainer(
        pathContainer,
        onIndexChange: (int idx) {
          print("Update data on blur $pathData");
          stateRepository!.reloadDependentContainers(pathData);
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
      }
    }
  }
}

enum ModeBuilderWidget { noConstraint, layoutBuilder, constraintBuilder }

class CwWidgetState<T extends CwWidget> extends WidgetBindJsonState<T> {
  int buildtime = 0;
  late CWStyleFactory styleFactory;

  CWInheritedRow? getRowState(BuildContext context) {
    CWInheritedRow? row =
        context.getInheritedWidgetOfExactType<CWInheritedRow>();
    return row;
  }

  @override
  void initState() {
    widget.ctx.widgetState = this;
    styleFactory = CWStyleFactory(widget.ctx);
    super.initState();
  }

  Widget buildWidget(
    bool useContainerWrapper,
    ModeBuilderWidget mode,
    CacheWidget builder,
  ) {
    widget.ctx.widgetState = this;
    styleFactory.init();
    styleFactory.setConfigMargin();
    styleFactory.setConfigBox();
    num? h = widget.ctx.dataWidget?[cwProps]?['height'];
    num? w = widget.ctx.dataWidget?[cwProps]?['width'];
    styleFactory.config.height = h?.toDouble();
    styleFactory.config.width = w?.toDouble();

    Widget builtWidget;

    switch (mode) {
      case ModeBuilderWidget.noConstraint:
        builtWidget = _buildWidgetInternal(useContainerWrapper, builder, null);

      case ModeBuilderWidget.layoutBuilder:
        builtWidget = LayoutBuilder(
          builder: (context, constraints) {
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
        builtWidget = ConstraintBuilder(
          fixedSize: cacheSizeSlot,
          builder: (context, constraints) {
            //if (cacheSizeSlot == null) {
            SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
              if (context.mounted) {
                final box = context.findRenderObject() as RenderBox;
                widget.ctx.aFactory.cacheSizeSlots[widget.ctx.aWidgetPath] =
                    box.size;
              }
            });
            //}
            return _buildWidgetInternal(
              useContainerWrapper,
              builder,
              constraints,
            );
          },
        );
    }

    builtWidget = styleFactory.getStyledBox(
      builtWidget,
      context,
      initBefore: false,
      useContainerWrapper: useContainerWrapper,
    );
    return builtWidget;
  }

  Widget _buildWidgetInternal(
    bool useContainerWrapper,
    CacheWidget builder,
    BoxConstraints? constraints,
  ) {
    buildtime = DateTime.now().millisecondsSinceEpoch;
    //print('buildWidget ${widget.ctx.aWidgetPath} $buildtime');
    var builtWidget = builder(widget.ctx, constraints);
    widget.ctx.cleanWidgetData(buildtime);

    return builtWidget;
  }

  @override
  Widget build(BuildContext context) {
    throw UnimplementedError();
  }

  @override
  void dispose() {
    // widget.ctx.state = null;
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
    var ret = widget.ctx.aFactory.getSlot(fromCtx ?? widget.ctx, slotProp.id);
    ret.config.ctx.selectorCtxIfDesign?.inSlotName = slotProp.name;
    ret.config.ctx.slotProps = slotProp;
    ret.config.ctx.buildSlotTime = buildtime;
    return ret;
  }

  String? getStringProp(CwWidgetCtx ctx, String propName) {
    return HelperEditor.getStringProp(ctx, propName);
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
  Map<String, CwWidgetSlotConfig> slotsConfig = {};
  List<CwWidgetProperties> properties = [];
  List<CwWidgetProperties> style = [];

  CwWidgetConfig();

  CwWidgetConfig addSlot(CwWidgetSlotConfig prop) {
    slotsConfig[prop.id] = prop;
    return this;
  }

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

  CwWidgetProperties({required this.id, required this.name});

  Map<String, dynamic> jsonFromCtx(CwWidgetCtx ctx, List<String>? path) {
    ctx.createDataOnParentIfNeeded();
    return ctx.initPropsIfNeeded(path: path);
  }

  void isIcon(CwWidgetCtx ctx, {List<String>? path}) {
    var json = jsonFromCtx(ctx, path);
    input = IconEditor(
      key: ValueKey('$id@${json.hashCode}'),
      json: json,
      config: this,
      onJsonChanged: ctx.onValueChange(path: path),
    );
  }

  void isSize(
    CwWidgetCtx ctx, {
    int defaultValue = 0,
    ValueChanged<Map>? onJsonChanged,
    List<String>? path,
  }) {
    isInt(
      (ctx),
      defaultValue: defaultValue,
      onJsonChanged: onJsonChanged,
      path: path,
      config: CwWidgetProperties(id: 'height', name: 'height'),
    );
    var i1 = input!;
    isInt(
      (ctx),
      defaultValue: defaultValue,
      onJsonChanged: (value) {
        ctx.onValueChange(path: path)(value);
        if (ctx.isParentOfType('table')) {
          ctx.parentCtx?.repaint();
        }
      },
      path: path,
      config: CwWidgetProperties(id: 'width', name: 'width'),
    );
    var i2 = input!;

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
      onJsonChanged: onJsonChanged ?? ctx.onValueChange(path: path),
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
    input = SliderEditor(
      min: min,
      max: max,
      icon: icon,
      key: ValueKey('$id@${json.hashCode}'),
      json: json,
      config: this,
      onJsonChanged: ctx.onValueChange(path: path, unselect: unselect),
    );
  }

  void isColor(CwWidgetCtx ctx, {IconData? icon, List<String>? path}) {
    var json = jsonFromCtx(ctx, path);
    input = HexColorEditor(
      key: ValueKey('$id@${json.hashCode}'),
      json: json,
      config: this,
      icon: icon,
      onJsonChanged: ctx.onValueChange(path: path),
    );
  }

  void isBool(
    CwWidgetCtx ctx, {
    ValueChanged<Map>? onJsonChanged,
    List<String>? path,
  }) {
    var json = jsonFromCtx(ctx, path);
    input = BoolEditor(
      key: ValueKey('$id@${json.hashCode}'),
      json: json,
      config: this,
      onJsonChanged: onJsonChanged ?? ctx.onValueChange(path: path),
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
    input = ToogleEditor(
      defaultValue: defaultValue,
      key: GlobalKey(
        debugLabel: 'ToogleEditor',
      ), //ValueKey('$id@${json.hashCode}'),
      json: json,
      config: this,
      onJsonChanged: onJsonChanged ?? ctx.onValueChange(path: path),
      items: items,
      isMultiple: isMultiple,
    );
  }

  void isText(CwWidgetCtx ctx, {List<String>? path}) {
    var json = jsonFromCtx(ctx, path);
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
      onJsonChanged: ctx.onValueChange(path: path),
    );
  }
}
