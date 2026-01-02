import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jsonschema/core/designer/component/helper/helper_editor.dart';
import 'package:jsonschema/core/designer/component/prop_editor/bool_editor.dart';
import 'package:jsonschema/core/designer/component/prop_editor/color_editor.dart';
import 'package:jsonschema/core/designer/component/prop_editor/icon_editor.dart';
import 'package:jsonschema/core/designer/component/prop_editor/slider_editor.dart';
import 'package:jsonschema/core/designer/component/prop_editor/text_editor.dart';
import 'package:jsonschema/core/designer/component/prop_editor/toogle_editor.dart';
import 'package:jsonschema/core/designer/core/widget_selectable.dart';
import 'package:jsonschema/core/designer/core/widget_style.dart';
import 'package:jsonschema/core/designer/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/cw_repository.dart';
import 'package:jsonschema/core/designer/cw_slot.dart';
import 'package:jsonschema/core/designer/core/widget_event_bus.dart';
import 'package:jsonschema/core/designer/widget/cw_list.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/feature/content/widget/widget_content_input.dart';
import 'package:jsonschema/widget/constraint_builder.dart';

class CwWidgetCtxSlot extends CwWidgetCtx {
  CwWidgetCtxSlot({
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
    selectorCtx._widgetKey ??= GlobalKey(
      debugLabel:
          parentCtx == null ? slotId : '${parentCtx!.aWidgetPath}/$slotId',
    );
    return selectorCtx._widgetKey;
  }

  GlobalKey? getInnerKey() {
    if (aFactory.isModeViewer()) {
      // pas besoin de GlobalKey en mode viewer
      return null;
    }

    selectorCtx._innerKey ??= GlobalKey(
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

  bool isType(String type) {
    return dataWidget?[cwType] == type;
  }

  bool isParentOfType(String type, {String? layout}) {
    if (parentCtx?.dataWidget?[cwType] == type) {
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

  CwWidgetCtx getSlotCtx(String cid, {Map? data}) {
    var wd = data ?? getData();
    if (childrenCtx?[cid] != null) {
      var ret = childrenCtx![cid]!;
      ret.dataWidget = wd?[cwSlots]?[cid];
      return ret;
    }

    var c = CwWidgetCtx(slotId: cid, aFactory: aFactory, parentCtx: this);
    childrenCtx ??= {};
    childrenCtx![cid] = c;
    c.dataWidget = wd?[cwSlots]?[cid];
    return c;
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
    return dataWidget?[cwType] == null;
  }

  bool isDesignSelected() {
    return currentSelectorManager.lastSelectedCtx == this;
  }

  Map? getData() {
    return dataWidget ?? parentCtx?.getData()?[cwSlots]?[slotId];
  }

  CwWidgetConfig? getConfig() {
    if (getData()?[cwType] == null) return null;
    return aFactory.builderConfig[getData()![cwType]]!(this);
  }

  ValueChanged<Map> onValueChange({
    bool repaint = true,
    bool resize = true,
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
        if (widgetState == null || widgetState!.mounted == false) {
          print('ERROR: onValueChange state is null for $aWidgetPath');
          //aFactory.rootCtx?.selectOnDesigner();
          //emitLater(CDDesignEvent.reselect, "displayProps", multiple: false);
          return;
        }
        // ignore: invalid_use_of_protected_member
        widgetState?.setState(() {});
      }

      if (currentSelectorManager.getSelectedPath() != aWidgetPath) {
        // changement d'un parent, on reselectionne onlyOverlay
        SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
          selectOnDesigner(onlyOverlay: true);
        });
      } else if (resize) {
        emitLater(CDDesignEvent.reselect, null, multiple: true);
      }
    };
  }

  void cleanWidget(int buildtime) {
    //remove children from ctx if buildtime different
    if (buildtime >= 0) {
      childrenCtx?.removeWhere(
        (key, value) => value.buildSlotTime != buildtime,
      );
    }

    _cleanSlotNotUse();

    // clean props if empty
    var prop = dataWidget?[cwProps] as Map?;
    if (prop == null || prop.isEmpty) {
      dataWidget?.remove(cwProps);
    }
    // clean propsSlots if empty
    prop = dataWidget?[cwPropsSlot] as Map?;
    if (prop == null || prop.isEmpty) {
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
      var type = data[cwType];
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

  void initBind() {
    Map? bind = widget.ctx.dataWidget?[cwProps]?['bind'];
    if (bind != null) {
      String repoId = bind['repository'];
      repository = widget.ctx.aFactory.mapRepositories['rp_$repoId'];
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
        String attrId = bind['attr'];
        stateRepository = repository!.dataState;
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

  Widget buildWidget(ModeBuilderWidget mode, CacheWidget builder) {
    switch (mode) {
      case ModeBuilderWidget.noConstraint:
        return _buildWidgetInternal(false, builder, null);

      case ModeBuilderWidget.layoutBuilder:
        return LayoutBuilder(
          builder: (context, constraints) {
            return _buildWidgetInternal(true, builder, constraints);
          },
        );

      case ModeBuilderWidget.constraintBuilder:
        var cacheSizeSlot =
            widget.ctx.aFactory.cacheSizeSlots[widget.ctx.aWidgetPath];
        return ConstraintBuilder(
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
            return _buildWidgetInternal(true, builder, constraints);
          },
        );
    }
  }

  Widget _buildWidgetInternal(
    bool bool,
    CacheWidget builder,
    BoxConstraints? constraints,
  ) {
    buildtime = DateTime.now().millisecondsSinceEpoch;
    //print('buildWidget ${widget.ctx.aWidgetPath} $buildtime');
    var ret = builder(widget.ctx, constraints);
    widget.ctx.cleanWidget(buildtime);
    ret = styleFactory.getStyledBox(ret, context, withContainer: true);
    return ret;
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

  CwSlot getSlot(CwSlotProp slotProp) {
    var ret = widget.ctx.aFactory.getSlot(widget.ctx, slotProp.id);
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
    return HelperEditor.getColorFromHex(ctx, propName);
  }
}

class CwWidgetConfig {
  Map<String, CwWidgetSlotConfig> slotsConfig = {};
  List<CwWidgetProperties> properties = [];

  CwWidgetConfig();

  CwWidgetConfig addSlot(CwWidgetSlotConfig prop) {
    slotsConfig[prop.id] = prop;
    return this;
  }

  CwWidgetConfig addProp(CwWidgetProperties prop) {
    properties.add(prop);
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

  void isInt(CwWidgetCtx ctx, {int defaultValue = 0, List<String>? path}) {
    var json = jsonFromCtx(ctx, path);
    input = TextEditor(
      key: ValueKey('$id@${json.hashCode}'),
      json: json,
      config: this,
      onJsonChanged: ctx.onValueChange(path: path),
    );
  }

  void isSlider(
    CwWidgetCtx ctx, {
    int defaultValue = 0,
    int min = 0,
    int max = 100,
    IconData? icon,
    List<String>? path,
  }) {
    var json = jsonFromCtx(ctx, path);
    input = SliderEditor(
      min: min,
      max: max,
      icon: icon,
      key: ValueKey('$id@${json.hashCode}'),
      json: json,
      config: this,
      onJsonChanged: ctx.onValueChange(path: path),
    );
  }

  void isColor(CwWidgetCtx ctx, {List<String>? path}) {
    var json = jsonFromCtx(ctx, path);
    input = HexColorEditor(
      key: ValueKey('$id@${json.hashCode}'),
      json: json,
      config: this,
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
      key: GlobalKey(), //ValueKey('$id@${json.hashCode}'),
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
      key: ValueKey('$id@${json.hashCode}'),
      json: json,
      config: this,
      onJsonChanged: ctx.onValueChange(path: path),
    );
  }
}
