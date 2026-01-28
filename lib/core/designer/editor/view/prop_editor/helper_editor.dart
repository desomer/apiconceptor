import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';
import 'package:jsonschema/core/designer/core/widget_catalog/cw_mask_helper.dart';

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

  static Color? getColorProp(
    CwWidgetCtx ctx,
    String propName,
    List<String>? path,
  ) {
    if (path != null) {
      var data = ctx.getData()?[ctx.getPropsName()];
      for (var p in path) {
        data = data?[p];
        if (data == null) {
          return null;
        }
      }
      var hexColor = data![propName] as String?;
      return getColorFromHex(hexColor);
    } else {
      var hexColor = ctx.getData()?[ctx.getPropsName()]?[propName] as String?;
      return getColorFromHex(hexColor);
    }
  }

  static Color? getColorFromHex(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) {
      return null;
    }
    hexColor = hexColor.toUpperCase().replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    return Color(int.parse(hexColor, radix: 16));
  }

  InputDecoration getInputDecoration(
    String label,
    double margeTop, {
    TextfieldBuilderInfo? info,
    TextEditingController? deleteController,
  }) {
    InputDecoration inputDecoration = InputDecoration(
      hintStyle: TextStyle(fontSize: 12),
      hintText: info?.hint,
      //error: _errorWidget,
      // labelText: labelWidget == null ? info.label : null,
      label: Text(label),
      border: UnderlineInputBorder(),
      isDense: true,
      contentPadding: EdgeInsets.fromLTRB(5, margeTop, 5, 5),
      suffixIcon:
          deleteController != null
              ? IconButton(
                padding: EdgeInsets.zero, // retire le padding interne
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.delete_forever),
                onPressed: () {
                  deleteController.clear();
                },
              )
              : info?.suffixIcon,
    );
    return inputDecoration;
  }

  static double? getDoubleProp(CwWidgetCtx ctx, String propName) {
    return double.tryParse(
      ctx.getData()?[ctx.getPropsName()]?[propName]?.toString() ?? '',
    );
  }
}
