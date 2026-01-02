import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/cw_widget.dart';

mixin HelperEditor {
  static String? getStringProp(CwWidgetCtx ctx, String propName) {
    return ctx.getData()?[ctx.getPropsName()]?[propName]?.toString();
  }

  static Map<String, dynamic>? getObjProp(CwWidgetCtx ctx, String propName) {
    return ctx.getData()?[ctx.getPropsName()]?[propName];
  }

  static int? getIntProp(CwWidgetCtx ctx, String propName) {
    return int.tryParse(
      ctx.getData()?[ctx.getPropsName()]?[propName]?.toString() ?? '',
    );
  }

  static bool? getBoolProp(CwWidgetCtx? ctx, String propName) {
    return ctx?.getData()?[ctx.getPropsName()]?[propName] as bool?;
  }

  static Color? getColorFromHex(CwWidgetCtx ctx, String propName) {
    var hexColor = ctx.getData()?[ctx.getPropsName()]?[propName] as String?;
    if (hexColor == null || hexColor.isEmpty) {
      return null;
    }
    hexColor = hexColor.toUpperCase().replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    return Color(int.parse(hexColor, radix: 16));
  }

  InputDecoration getInputDecoration(String label, double margeTop) {
    InputDecoration inputDecoration = InputDecoration(
      // suffixIcon: info.suffixIcon,
      hintStyle: TextStyle(fontSize: 12),
      // hintText: info.hint,
      // error: _errorWidget,
      // labelText: labelWidget == null ? info.label : null,
      label: Text(label),
      border: UnderlineInputBorder(),
      isDense: true,
      contentPadding: EdgeInsets.fromLTRB(5, margeTop, 5, 5),
    );
    return inputDecoration;
  }

  static double? getDoubleProp(CwWidgetCtx ctx, String propName) {
    return double.tryParse(
      ctx.getData()?[ctx.getPropsName()]?[propName]?.toString() ?? '',
    );
  }
}
