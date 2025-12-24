import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:jsonschema/core/designer/component/helper/helper_editor.dart';
import 'package:jsonschema/core/designer/component/prop_editor/bool_editor.dart';
import 'package:jsonschema/core/designer/component/prop_editor/color_editor.dart';
import 'package:jsonschema/core/designer/component/prop_editor/icon_editor.dart';
import 'package:jsonschema/core/designer/component/prop_editor/text_editor.dart';
import 'package:jsonschema/core/designer/component/prop_editor/toogle_editor.dart';
import 'package:jsonschema/core/designer/core/widget_selectable.dart';
import 'package:jsonschema/core/designer/cw_factory.dart';
import 'package:jsonschema/core/designer/cw_slot.dart';
import 'package:jsonschema/core/designer/core/widget_event_bus.dart';
import 'package:jsonschema/widget/constraint_builder.dart';

class CwWidgetCtxSlot extends CwWidgetCtx {
  CwWidgetCtxSlot({required super.aFactory, required super.id});
}

class CwWidgetCtx {
  int buildSlotTime = 0;

  final WidgetFactory aFactory;
  final String id;

  String get aPath {
    if (parentCtx != null) {
      return '${parentCtx!.aPath}/$id';
    }
    return id;
  }

  CwWidgetCtx? parentCtx;
  Map<String, CwWidgetCtx>? childrenCtx;

  Map<String, dynamic>? dataWidget;

  String? inSlotName;
  CwSlotProp? slotProps;

  CwWidgetState? state;
  GlobalKey? keyCapture;
  Map<String, dynamic>? extraRenderingData;

  CwWidgetCtx({required this.aFactory, required this.id});

  CwWidgetCtxSlot cloneForSlot() {
    var ret = CwWidgetCtxSlot(id: id, aFactory: aFactory);
    ret.dataWidget = parentCtx?.getData()?[cwSlots]?[id];
    ret.parentCtx = parentCtx;
    ret.state = parentCtx?.state;
    return ret;
  }

  String getPropsName() {
    return this is CwWidgetCtxSlot ? cwPropsSlot : cwProps;
  }

  CwWidgetCtx getSlotCtx(String cid) {
    if (childrenCtx?[cid] != null) {
      var ret = childrenCtx![cid]!;
      ret.dataWidget = getData()?[cwSlots]?[cid];
      return ret;
    }

    var c = CwWidgetCtx(id: cid, aFactory: aFactory)..parentCtx = this;
    childrenCtx ??= {};
    childrenCtx![cid] = c;
    c.dataWidget = getData()?[cwSlots]?[cid];
    return c;
  }

  void createDataOnParentIfNeeded() {
    if (parentCtx != null && parentCtx!.dataWidget![cwSlots]?[id] == null) {
      dataWidget = aFactory.addInSlot(parentCtx!.dataWidget!, id, {});
    }
  }

  Map<String, dynamic> initPropsIfNeeded() {
    var props = getData()![getPropsName()];
    if (props == null) {
      props = <String, dynamic>{};
      getData()![getPropsName()] = props;
    }
    return props;
  }

  Map? getData() {
    return dataWidget;
  }

  CwWidgetConfig? getConfig() {
    if (getData()?[cwType] == null) return null;
    return aFactory.builderConfig[getData()![cwType]]!(this);
  }

  ValueChanged<Map> onValueChange({bool repaint = true, bool resize = true}) {
    return (newJson) {
      createDataOnParentIfNeeded();
      if (getData()![getPropsName()] == null) {
        getData()![getPropsName()] = newJson;
      } else {
        getData()![getPropsName()]!.addAll(newJson);
      }

      if (repaint) {
        if (state == null) {
          print('ERROR: onValueChange state is null for $aPath');
        }
        // ignore: invalid_use_of_protected_member
        state?.setState(() {});
      }

      if (currentSelectorManager.lastSelected?.widget.slotConfig?.ctx.aPath !=
          aPath) {
        SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
          select(onlyOverlay: true);
        });
      } else if (resize) {
        SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
          emit(CDDesignEvent.reselect, null);
        });
      }
    };
  }

  void cleanWidget(int buildtime) {
    //remove children from ctx if buildtime different
    childrenCtx?.removeWhere((key, value) => value.buildSlotTime != buildtime);

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
    for (MapEntry entry in slots?.entries ?? []) {
      var cid = entry.key;
      var data = entry.value as Map<String, dynamic>;
      var ctxChild = childrenCtx?[cid];
      if (ctxChild == null) {
        slotIdsToRemove.add(cid);
      } else {
        var t = data[cwType];
        var pp = data[cwProps] as Map<String, dynamic>?;
        var ps = data[cwPropsSlot] as Map<String, dynamic>?;
        if (t == null &&
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

  void selectParent() {
    emit(
      CDDesignEvent.select,
      CWEventCtx()
        ..ctx = parentCtx
        ..path = parentCtx!.aPath
        ..keybox = parentCtx!.keyCapture,
    );
  }

  void select({bool onlyOverlay = false}) {
    emit(
      CDDesignEvent.select,
      CWEventCtx()
        ..extra = {'displayProps': !onlyOverlay}
        ..ctx = this
        ..path = aPath
        ..keybox = keyCapture,
    );
  }
}

abstract class CwWidget extends StatefulWidget {
  final CwWidgetCtx ctx;
  const CwWidget({super.key, required this.ctx});
}

class CwWidgetState<T extends CwWidget> extends State<T> {
  int buildtime = 0;

  Widget buildWidget(bool withContraint, CacheWidget builder) {
    widget.ctx.state = this;

    if (withContraint) {
      return ConstraintBuilder(
        builder: (context, constraints) {
          buildtime = DateTime.now().millisecondsSinceEpoch;
          print('buildWidget ${widget.ctx.aPath} $buildtime');
          var ret = builder(widget.ctx, constraints);
          widget.ctx.cleanWidget(buildtime);
          return ret;
        },
      );
    } else {
      buildtime = DateTime.now().millisecondsSinceEpoch;
      print('buildWidget ${widget.ctx.aPath} $buildtime');
      var ret = builder(widget.ctx, null);
      widget.ctx.cleanWidget(buildtime);
      return ret;
    }
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

  @override
  void initState() {
    widget.ctx.state = this;
    super.initState();
  }

  CwSlot getSlot(CwSlotProp slotProp) {
    var ret = widget.ctx.aFactory.getSlot(widget.ctx, slotProp.id);
    ret.config.ctx.inSlotName = slotProp.name;
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

  Map<String, dynamic> jsonFromCtx(CwWidgetCtx ctx) {
    ctx.createDataOnParentIfNeeded();
    return ctx.initPropsIfNeeded();
  }

  void isIcon(CwWidgetCtx ctx) {
    var json = jsonFromCtx(ctx);
    input = IconEditor(
      key: ValueKey('$id@${json.hashCode}'),
      json: json,
      config: this,
      onJsonChanged: ctx.onValueChange(),
    );
  }

  void isInt(CwWidgetCtx ctx, {int defaultValue = 0}) {
    var json = jsonFromCtx(ctx);
    input = TextEditor(
      key: ValueKey('$id@${json.hashCode}'),
      json: json,
      config: this,
      onJsonChanged: ctx.onValueChange(),
    );
  }

  void isColor(CwWidgetCtx ctx) {
    var json = jsonFromCtx(ctx);
    input = HexColorEditor(
      key: ValueKey('$id@${json.hashCode}'),
      json: json,
      config: this,
      onJsonChanged: ctx.onValueChange(),
    );
  }

  void isBool(CwWidgetCtx ctx, {ValueChanged<Map>? onJsonChanged}) {
    var json = jsonFromCtx(ctx);
    input = BoolEditor(
      key: ValueKey('$id@${json.hashCode}'),
      json: json,
      config: this,
      onJsonChanged: onJsonChanged ?? ctx.onValueChange(),
    );
  }

  void isToogle(
    CwWidgetCtx ctx,
    List items, {
    ValueChanged<Map>? onJsonChanged,
    bool isMultiple = false,
    String? defaultValue,
  }) {
    var json = jsonFromCtx(ctx);
    input = ToogleEditor(
      defaultValue: defaultValue,
      key: GlobalKey(), //ValueKey('$id@${json.hashCode}'),
      json: json,
      config: this,
      onJsonChanged: onJsonChanged ?? ctx.onValueChange(),
      items: items,
      isMultiple: isMultiple,
    );
  }

  void isText(CwWidgetCtx ctx) {
    var json = jsonFromCtx(ctx);
    input = TextEditor(
      key: ValueKey('$id@${json.hashCode}'),
      json: json,
      config: this,
      onJsonChanged: ctx.onValueChange(),
    );
  }
}
