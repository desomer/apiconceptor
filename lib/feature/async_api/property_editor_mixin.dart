import 'package:flutter/material.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/async_api/pan_attribut_editor_async.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';

mixin PropertyEditorMixin {
  Widget getListProp(
    List<AttributeEditorAsync> listProp,
    NodeAttribut info,
    ModelSchema model,
    List<Widget> row,
  ) {
    String? lastCat = "";
    for (AttributeEditorAsync prop in listProp) {
      String? propName = prop.name;
      var cat = prop.name.split('.');
      if (cat.length > 1) {
        propName = cat.last;
        if (lastCat != cat.first) {
          lastCat = cat.first;
          row.add(SizedBox(height: 5));
          row.add(Text(lastCat, style: TextStyle(fontWeight: FontWeight.bold)));
        }
      }

      row.add(
        CellEditor(
          key: ValueKey('${prop.name}#${info.hashCode}'),
          acces: ModelAccessorAttr(
            node: info,
            schema: model,
            propName: propName,
          ),
          line: 1,
          inArray: false,
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(10),
      child: Column(
        spacing: 10,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: row,
      ),
    );
  }
}
