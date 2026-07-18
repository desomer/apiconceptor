import 'package:flutter/material.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/async_api/pan_attribut_editor_async.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/image2base64_widget.dart';
import 'package:jsonschema/widget/widget_tab.dart';

mixin PropertyEditorMixin {
  String _formatLabel(String text) {
    return text.replaceAll('_', ' ');
  }

  Map<String, List<AttributeEditorAsync>> _groupPropsByCategory(
    List<AttributeEditorAsync> listProp,
  ) {
    final grouped = <String, List<AttributeEditorAsync>>{};

    for (final prop in listProp) {
      final parts = prop.name.split('.');
      final category = parts.length > 1 ? parts.first : 'General';
      grouped.putIfAbsent(category, () => <AttributeEditorAsync>[]).add(prop);
    }

    return grouped;
  }

  Widget _buildPropsForCategory(
    String category,
    List<AttributeEditorAsync> props,
    NodeAttribut info,
    ModelSchema model,
    List<Widget> row,
  ) {
    final widgets = <Widget>[...row];
    String? lastGroup = '';

    for (final prop in props) {
      final parts = prop.name.split('.');
      //String propName = prop.name;

      if (parts.length >= 3) {
        final subCategory = parts[1];
        //propName = parts.sublist(2).join('.');
        if (lastGroup != subCategory) {
          lastGroup = subCategory;
          widgets.add(const SizedBox(height: 5));
          widgets.add(
            Text(
              _formatLabel(subCategory),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        }
      } else if (parts.length == 2) {
        //propName = parts[1];
      }

      addEditor(widgets, prop, info, model);
    }

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        spacing: 10,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      ),
    );
  }

  Widget getListProp(
    List<AttributeEditorAsync> listProp,
    NodeAttribut info,
    ModelSchema model,
    List<Widget> row,
  ) {
    String? lastCat = "";
    for (AttributeEditorAsync prop in listProp) {
      //String? propName = prop.name;
      var cat = prop.name.split('.');
      if (cat.length > 1) {
        //propName = cat.last;
        if (lastCat != cat.first) {
          lastCat = cat.first;
          row.add(SizedBox(height: 5));
          row.add(
            Text(
              _formatLabel(lastCat),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        }
      }

      addEditor(row, prop, info, model);
    }

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        spacing: 10,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: row,
      ),
    );
  }

  void addEditor(
    List<Widget> row,
    AttributeEditorAsync prop,
    NodeAttribut info,
    ModelSchema model,
  ) {
    switch (prop.type) {
      case 'logo':
        var info2 =  model.getExtendedNode(info.info.getMasterID());
        info2.info.singleSaveKey = prop.name;
        var v = ModelAccessorAttr(
          node: info2,
          schema: model,
          propName: prop.name,
        );

        row.add(
          ImageUrlToBase64Widget(
            initialBase64: v.get(),
            showBase64Text: false,
            onBase64Changed: (value) {
              if (value.isEmpty) {
                v.remove();
                return;
              }
              v.set(value, withHistory: false);
            },
          ),
        );
        break;
      default:
        row.add(
          CellEditor(
            key: ValueKey('${prop.name}#${info.hashCode}'),
            acces: ModelAccessorAttr(
              node: info,
              schema: model,
              propName: prop.name,
            ),
            line: 1,
            inArray: false,
          ),
        );
        break;
    }
  }

  Widget getTabProp(
    List<AttributeEditorAsync> listProp,
    NodeAttribut info,
    ModelSchema model,
    List<Widget> row,
  ) {
    final grouped = _groupPropsByCategory(listProp);
    final categories = grouped.keys.toList(growable: false);

    if (categories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: Column(children: row),
      );
    }

    if (categories.length == 1) {
      final category = categories.first;
      return _buildPropsForCategory(
        category,
        grouped[category]!,
        info,
        model,
        row,
      );
    }

    return WidgetTab(
      heightTab: 36,
      listTab: categories
          .map((category) => Tab(text: _formatLabel(category)))
          .toList(),
      listTabCont: categories
          .map(
            (category) => SingleChildScrollView(
              child: _buildPropsForCategory(
                category,
                grouped[category]!,
                info,
                model,
                row,
              ),
            ),
          )
          .toList(),
      heightContent: true,
    );
  }
}
