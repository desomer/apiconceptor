import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jsonschema/core/core_expression.dart';
import 'package:jsonschema/core/designer/editor/view/prop_editor/helper_editor.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';

class CwStyleBox {
  String? layout;
  double? spacing;
  double? padding;

  AlignmentDirectional? align;
  EdgeInsets? edgeMargin;
  BoxDecoration? decoration;
  BorderRadius? borderRadius;
  BorderSide? side;
  EdgeInsets? edgePadding;
  double hBorder = 0;
  double hPadding = 0;
  double hMargin = 0;
  double wPadding = 0;
  double wMargin = 0;

  double? height;
  double? width;

  void clear() {
    align = null;
    edgeMargin = null;
    decoration = null;
    borderRadius = null;
    side = null;
    padding = null;
    hBorder = 0;
    hPadding = 0;
    hMargin = 0;
    wMargin = 0;
    wPadding = 0;
    height = null;
    width = null;
  }
}

class CoreStyleBehaviour {
  CoreStyleBehaviour(this.styles, this.condition);

  Map<String, dynamic> styles;
  CoreExpression? condition;
}

class CWStyleFactory {
  CWStyleFactory(this.ctx) {
    styleSrc = ctx?.dataWidget?[cwProps]?[cwStyle];
  }

  final CwWidgetCtx? ctx;
  late Map<String, dynamic>? styleSrc;
  Map<String, dynamic> style = {};

  CwStyleBox config = CwStyleBox();
  List<CoreStyleBehaviour> conditional = [];
  CWWidgetStateMgr stateMgr = CWWidgetStateMgr();

  bool styleExist(List<String> properties) {
    for (var p in properties) {
      if (style[p] != null) {
        return true;
      }
    }
    return false;
  }

  double getStyleDouble(String id, double def) {
    dynamic v = style[id];
    if (v == null) return def;

    return v is double ? v : (v as int).toDouble();
  }

  double? getStyleNDouble(String id, double min) {
    dynamic v = style[id];
    if (v == null) return null;

    var r = v is double ? v : (v as int).toDouble();
    if (r < min) return min;
    return r;
  }

  String? getStyleString(String id, String? def) {
    String? v = style[id];
    if (v == null) return def;

    return v;
  }

  double? getElevation() {
    return getStyleNDouble('elevation', 0);
  }

  Color? getColor(String id) {
    dynamic v = style[id];
    if (v == null) return null;
    return HelperEditor.getColorFromHex(v);
  }

  bool hasTag(String id, String tag) {
    return style[id]?.toString().contains(tag) ?? false;
  }

  Widget getMarginByDragCapable(Widget w) {
    // var mode = widget.aFactory.isModeDesigner()
    // var modeDragForMargin = CoreDesigner.of().shortcut.isShiftPress() ||
    //     segmentedButtonDragMode.contains(ModeDragSlot.margin);

    // if (mode == ModeRendering.view || !(modeDragForMargin)) {
    //   return w;
    // }

    // print('drag marge');
    // return Draggable<String>(
    //   onDragUpdate: (details) {
    //     CoreDataEntity prop = DesignCtx()
    //         .forDesign(widget.ctx)
    //         .preparePropChange(widget.ctx.loader);

    //     Map<String, dynamic>? s = prop.value[iDStyle];
    //     if (s == null) {
    //       prop.value[iDStyle] = widget.ctx.factory.loader.collectionDataModel
    //           .createEntity('StyleModel')
    //           .value;
    //     }
    //     doMoveAxe(s, 'boxAlignHorizontal', 'pleft', 'pright', details.delta.dx);
    //     doMoveAxe(s, 'boxAlignVertical', 'ptop', 'pbottom', details.delta.dy);

    //     widget.repaint('drag marge');
    //     CoreDesigner.emit(CDDesignEvent.reselect, null);
    //   },
    //   //dragAnchorStrategy: dragAnchorStrategy,
    //   data: 'drag',
    //   feedback: Container(),
    //   child: w,
    // );
    return w;
  }

  void doMoveAxe(
    Map<String, dynamic>? s,
    String axe,
    String a,
    String b,
    double delta,
  ) {
    var align = s?[axe] ?? '-1';
    if (align == '-1' || align == '0') {
      double v = s?[a] ?? 0;
      s?[a] = max(0.0, v + delta);
      s?.remove(b);
    } else {
      double v = s?[b] ?? 0;
      s?[b] = max(0.0, v - delta);
      s?.remove(a);
    }
  }

  void init() {
    styleSrc = ctx?.dataWidget?[cwProps]?[cwStyle];
    style.clear();
    if (styleSrc != null) {
      style.addAll(styleSrc!);
    }

    config.clear();
    conditional.clear();
  }

  Widget getPaddingBox(Widget content) {
    if (config.edgePadding != null) {
      return Padding(padding: config.edgePadding!, child: content);
    }
    return content;
  }

  static Size getBoxSize(BuildContext context) {
    final box = context.findRenderObject() as RenderBox;
    return box.size;
  }

  Widget getStyledBox(
    Widget content,
    BuildContext context, {
    bool useContainerWrapper = false,
    bool withContentKey = true,
    bool initBefore = true,
  }) {
    ctx?.selectorCtxIfDesign?.withPadding = false;
    if (initBefore) {
      init();
      setConfigMargin();
      if (useContainerWrapper) {
        setConfigBox();
      }
    }

    // if (!styleExist(['pleft', 'ptop', 'pright', 'pbottom'])) {
    //   content = getMarginByDragCapable(content);
    // }

    if (useContainerWrapper) {
      content = getMarginByDragCapable(content);
      return getStyledContainer(content, context);
    } else {
      if (config.edgeMargin != null) {
        content = Padding(
          key: withContentKey ? ctx?.getInnerKey() : null,
          padding: config.edgeMargin!,
          child: content,
        );
      }

      if (isSizeDefined()) {
        content = SizedBox(
          height: config.height,
          width: config.width,
          child: content,
        );
      }

      if (config.align != null) {
        return _getVisibility(
          Container(
            alignment: config.align,
            child: getMarginByDragCapable(content),
          ),
        );
      } else {
        return _getVisibility(getMarginByDragCapable(content));
      }
    }
  }

  bool isSizeDefined() {
    var isHeightOrWidthDefined = config.height != null || config.width != null;
    return isHeightOrWidthDefined;
  }

  void setConfigMargin() {
    if (styleExist(['boxAlignV', 'boxAlignH'])) {
      config.align = AlignmentDirectional(
        double.parse(style['boxAlignH'] ?? '-1'),
        double.parse(style['boxAlignV'] ?? '-1'),
      );
    }

    if (styleExist(['pleft', 'ptop', 'pright', 'pbottom'])) {
      var ptop = getStyleDouble('ptop', 0);
      var pbottom = getStyleDouble('pbottom', 0);
      var pleft = getStyleDouble('pleft', 0);
      var pright = getStyleDouble('pright', 0);
      config.edgeMargin = EdgeInsets.fromLTRB(pleft, ptop, pright, pbottom);
      config.hMargin = ptop + pbottom;
      config.wMargin = pleft + pright;
    }
  }

  // void evalCondition(String? self, CWRepository? repos) {
  //   var stateMgr = this.stateMgr;
  //   stateMgr.stateBehaviour?.clear();
  //   var mode = widget.ctx.modeRendering;
  //   if (mode == ModeRendering.design) return;

  //   List? behaviour = widget.ctx.getProp(iDBehaviour);
  //   if (behaviour != null) {
  //     for (Map<String, dynamic> element in behaviour) {
  //       var param = element['param'];
  //       if (element['on'] == 'binding') {
  //         var category = element['cat'];
  //         if (element['if'].toString().isNotEmpty && category == 'style') {
  //           var exp = CoreStyleBehaviour(
  //             param,
  //             CoreExpression()..init(element['if']),
  //           );
  //           conditional.add(exp);
  //         }
  //       }
  //       if (element['on'] == 'change') {
  //         stateMgr.stateBehaviour ??= [];
  //         stateMgr.stateBehaviour!.add(BehaviourConfig()..param = param);
  //       }
  //     }
  //   }
  //   //print('conditional $conditional $behaviour   ${widget.ctx.pathWidget}');
  //   for (var element in conditional) {
  //     var row = repos?.getEntity()?.value;
  //     if (element.condition?.evalBool(self: self, row: row) ?? false) {
  //       style.addAll(element.styles);
  //       print('add all $style self $self');
  //     }
  //   }
  // }

  static Map<String, DecorationImage> cacheImage = {};

  void setConfigBox() {
    if (styleExist(['bSize', 'bColor'])) {
      var bSize = getStyleDouble('bSize', 1);
      config.side = BorderSide(
        width: bSize,
        color: getColor('bColor') ?? Colors.transparent,
      );
      config.hBorder = bSize * 2;
    }

    if (styleExist(['bRadius'])) {
      config.borderRadius = BorderRadius.all(
        Radius.circular(getStyleDouble('bRadius', 0)),
      );
    }

    if (config.side != null ||
        config.borderRadius != null ||
        styleExist(['bgColor', 'bRadius', 'imagebg', 'gradient'])) {
      var idImage = style['imagebg'];
      var withImage = idImage != null && idImage != '';

      DecorationImage? image;

      if (withImage) {
        image = cacheImage[idImage];
        if (image == null) {
          // image = DecorationImage(
          //   image: CWNetworkImageById(id: idImage),
          //   fit: BoxFit.cover,
          //   filterQuality: FilterQuality.medium,
          // );
          // cacheImage[idImage] = image;
        }
      }

      config.decoration = BoxDecoration(
        image: image,
        gradient: getGradient(),
        color: getColor('bgColor'),
        border:
            config.side != null ? Border.fromBorderSide(config.side!) : null,
        borderRadius: config.borderRadius,
      );
    }

    if (styleExist(['mleft', 'mtop', 'mright', 'mbottom'])) {
      var mtop = getStyleDouble('mtop', 0);
      var mbottom = getStyleDouble('mbottom', 0);
      var mleft = getStyleDouble('mleft', 0);
      var mright = getStyleDouble('mright', 0);
      config.edgePadding = EdgeInsets.fromLTRB(mleft, mtop, mright, mbottom);
      config.hPadding = mtop + mbottom;
      config.wPadding = mleft + mright;
    }
  }

  bool isDarkMode() {
    // CWApp root = widget.ctx.findWidgetByXid('root')! as CWApp;
    // return root.isDark();
    return false;
  }

  Gradient? getGradient() {
    if (style['gradient'] == 'lin') {
      bool isDark = isDarkMode();
      Color mainColor = Colors.white;

      Color? color1 = getColor('bgColor1') ?? mainColor;
      Color? color2 =
          getColor('bgColor2') ??
          ((isDark ? Colors.grey.shade900 : Colors.white));

      return LinearGradient(
        colors: [color1, color2],
        stops: [
          getStyleDouble('gEnter1', 20) / 100,
          getStyleDouble('gEnter2', 100) / 100,
        ],
        begin: Alignment(
          getStyleDouble('gAlignX1', 0) / 100,
          getStyleDouble('gAlignY1', -100) / 100,
        ),
        end: Alignment(
          getStyleDouble('gAlignX2', 0) / 100,
          getStyleDouble('gAlignY2', 100) / 100,
        ),
      );
    }
    return null;
  }

  // .addAttr('gEnter1', CDAttributType.int)
  // .addAttr('gEnter2', CDAttributType.int)

  TextStyle getTextStyle(double? fontSize) {
    var tcolor = getColor('tColor');
    var fgColor = getColor('fgColor');
    return TextStyle(
      color: tcolor ?? fgColor,
      fontWeight: hasTag('textstyle', 'bold') ? FontWeight.bold : null,
      fontStyle: hasTag('textstyle', 'italic') ? FontStyle.italic : null,
      fontSize: getStyleNDouble('tSize', 4) ?? fontSize,
      overflow: TextOverflow.ellipsis,
      decorationColor: tcolor ?? fgColor,
      decoration:
          hasTag('textstyle', 'underline')
              ? TextDecoration.underline
              : (hasTag('textstyle', 'lineThrough')
                  ? TextDecoration.lineThrough
                  : (hasTag('textstyle', 'overline')
                      ? TextDecoration.overline
                      : null)),
    );
  }

  ButtonStyle getButtonStyle(double? fontSize, TextStyle? styleText) {
    var fgcolor = getColor('fgColor');
    var bgcolor = getColor('bgColor');
    var roundedRectangleBorder = getRoundedRectangleBorder();
    return ButtonStyle(
      shape:
          roundedRectangleBorder != null
              ? WidgetStateProperty.all(roundedRectangleBorder)
              : null,
      elevation:
          getElevation() != null
              ? WidgetStateProperty.all(getElevation())
              : null,
      foregroundColor:
          fgcolor != null ? WidgetStateProperty.all(fgcolor) : null,
      textStyle: WidgetStateProperty.all(styleText),
      backgroundColor:
          bgcolor != null ? WidgetStateProperty.all(bgcolor) : null,

      padding:
          config.edgePadding != null
              ? WidgetStateProperty.all(config.edgePadding)
              : null,
    );
  }

  Widget _getClipRect(Widget content) {
    if (config.borderRadius != null) {
      return ClipRRect(borderRadius: config.borderRadius!, child: content);
    }
    return content;
  }

  RoundedRectangleBorder? getRoundedRectangleBorder() {
    if (config.borderRadius != null || config.side != null) {
      return RoundedRectangleBorder(
        borderRadius: getBorderRadius(),
        side: config.side ?? BorderSide.none,
      );
    }
    return null;
  }

  BorderRadius getBorderRadius() {
    return config.borderRadius ?? const BorderRadius.all(Radius.circular(4.0));
  }

  Widget getStyledContainer(Widget content, BuildContext context) {
    if (styleExist(['elevation'])) {
      content = Material(
        // clipBehavior: Clip.none,
        // color: Colors.transparent,
        elevation: getElevation() ?? 0,
        borderRadius: config.borderRadius,
        textStyle: DefaultTextStyle.of(context).style,
        child: _getClipRect(
          Container(
            padding: config.edgePadding,
            decoration: config.decoration,
            child: getMarginByDragCapable(content),
          ),
        ),
      );

      // if (config.margin != null) {
      //   content = Padding(padding: config.margin!, child: content);
      // }

      if (config.height != null || config.width != null) {
        content = SizedBox(
          height: config.height,
          width: config.width,
          child: content,
        );
      }

      if (config.align != null || config.edgeMargin != null) {
        content = Container(
          alignment: config.align,
          padding: config.edgeMargin,
          child: content,
        );
      }

      return _getVisibility(content);
    } else if (config.edgeMargin != null ||
        config.decoration != null ||
        config.align != null ||
        config.padding != null ||
        config.height != null ||
        config.width != null) {
      return _getVisibility(
        Container(
          height: config.height,
          width: config.width,
          margin: config.edgeMargin,
          decoration: config.decoration,
          padding: config.edgePadding,
          alignment: config.align,
          child: _getClipRect(getMarginByDragCapable(content)),
        ),
      );
    } else {
      return _getVisibility(getMarginByDragCapable(content));
    }
  }

  bool? visible;
  double? maxHeight;

  Widget _getVisibility(Widget childVisible) {
    if (visible != stateMgr.isVisible) {
      GlobalKey<CWAnimatedVisibilityState> key = GlobalKey(
        debugLabel: '_CWAnimatedVisibilityKey',
      );
      bool? last = visible;
      visible = stateMgr.isVisible;
      if (stateMgr.isVisible && last == null) {
        return childVisible;
      }
      if (!stateMgr.isVisible && last == null) {
        return Container();
      }

      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (stateMgr.isVisible == true) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            key.currentState?.setHeight(1);
            SchedulerBinding.instance.addPostFrameCallback((_) {
              key.currentState?.setHeight(
                maxHeight ?? key.currentState!.heightMax,
              );
            });
          });
        } else {
          var size = getBoxSize(key.currentContext!);
          maxHeight = size.height;
          key.currentState?.setHeight(size.height);
          SchedulerBinding.instance.addPostFrameCallback((_) {
            key.currentState?.setHeight(0);
          });
        }
      });
      return CWAnimatedVisibility(
        visibility: !visible!,
        key: key,
        delay: last == null ? 0 : 100,
        child: childVisible,
        atEndVisibility: (double max) {
          maxHeight = max;
        },
      );
    }

    return childVisible;
  }
}

class CWAnimatedVisibility extends StatefulWidget {
  const CWAnimatedVisibility({
    required this.child,
    required this.delay,
    required this.visibility,
    required this.atEndVisibility,
    super.key,
  });
  final Widget child;
  final int delay;
  final bool visibility;
  final Function atEndVisibility;

  @override
  State<CWAnimatedVisibility> createState() => CWAnimatedVisibilityState();
}

const double defaultVisibilityHeight = 35;

class CWAnimatedVisibilityState extends State<CWAnimatedVisibility> {
  double? height;
  double heightMax = defaultVisibilityHeight;
  int delay = 0;

  double getMaxHeight() {
    return heightMax;
  }

  void setHeight(double h) {
    if (h > heightMax) {
      heightMax = h;
    }
    setState(() {
      height = h;
    });
  }

  @override
  void initState() {
    delay = widget.delay;
    if (widget.visibility) {
      height = null;
    } else {
      height = 0;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (delay == 0) {
      if (height == null) {
        return widget.child;
      }
      if (height == 0) {
        return Container();
      }
      return widget.child;
    } else {
      return AnimatedContainer(
        duration: Duration(milliseconds: delay),
        height: height,
        clipBehavior: Clip.none,
        curve: Easing.linear,
        onEnd: () {
          doEndAnimation();
        },
        child: Container(height: heightMax),
      );
    }
  }

  void doEndAnimation() {
    if (height == defaultVisibilityHeight) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        setState(() {
          //force un container rempli su child
          delay = 0;
        });
        SchedulerBinding.instance.addPostFrameCallback((_) {
          var size =
              ((widget.key as GlobalKey).currentContext != null)
                  ? CWStyleFactory.getBoxSize(
                    (widget.key as GlobalKey).currentContext!,
                  )
                  : Size(0, 0);
          heightMax = size.height;
          delay = widget.delay;
          widget.atEndVisibility(heightMax);
        });
      });
    }
    if (height == 0) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        setState(() {
          //force un container vide
          delay = 0;
        });
      });
    }
  }
}

class CWWidgetStateMgr {
  bool isEmpty = false;
  bool isEditable = true;
  bool isVisible = true;
  bool isEnable = true;
  bool isSelectable = true;
  bool doClear = false;

  // List<BehaviourConfig>? stateBehaviour;

  // void calculateState(
  //   CWWidget widget,
  //   StateCW curState,
  //   CWInheritedRow? row,
  //   Map<String, dynamic>? bind,
  //   DateTime d,
  // ) {
  //   //    print('do state of ${curState.hashCode} $bind $stateBehaviour');
  //   if (stateBehaviour != null) {
  //     for (var bev in stateBehaviour!) {
  //       var xid = bev.param!['xid'];
  //       var attr = bev.param!['attr'];
  //       CWWidget? w;
  //       if (attr != null) {
  //         xid =
  //             widget
  //                 .ctx
  //                 .loader
  //                 .linkInfo
  //                 .reposXattr
  //                 .entries
  //                 .first
  //                 .value
  //                 .attrXxid[attr]
  //                 ?.first;
  //       }
  //       if (xid != null) w = widget.ctx.findWidgetByXid(xid);
  //       if (w != null) {
  //         var state = w.getState(row?.index ?? 0, force: true);
  //         if (state is StateCWInRowCapable) {
  //           state.initWidgetState(null, d, w as CWWidgetMapValue);
  //         }
  //         var stateMgr = state?.styledBox.stateMgr;
  //         var condEmpty =
  //             bev.param!['ifEmpty'] == true && (stateMgr?.isEmpty ?? false);
  //         var condFill =
  //             state != null &&
  //             !condEmpty &&
  //             bev.param!['ifFill'] == true &&
  //             (!stateMgr!.isEmpty);

  //         print(
  //           'get state row ${row?.index ?? 0} of ${state.hashCode} condEmpty=$condEmpty condFill=$condFill',
  //         );

  //         if (condEmpty || condFill) {
  //           if (bev.param!['isEnable'] == false) isEnable = false;
  //           if (bev.param!['isEditable'] == false) isEditable = false;
  //           if (bev.param!['isVisible'] == false) isVisible = false;
  //           if (bev.param!['doEmpty'] == true) doClear = true;
  //         }
  //       }
  //     }
  //   }
  //}
}
