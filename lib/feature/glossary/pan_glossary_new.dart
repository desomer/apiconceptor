import 'package:flutter/material.dart';
import 'package:jsonschema/authorization_manager.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/pan_attribut_editor.dart';
import 'package:jsonschema/json_browser/browse_glossary.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/widget/tree_editor/pan_yaml_tree.dart';
import 'package:jsonschema/widget/tree_editor/tree_view.dart';

// ignore: must_be_immutable
class PanGlossary extends PanYamlTree {
  PanGlossary({super.key, required super.getSchemaFct});

  @override
  void onInitSchema(BuildContext context) {
    getSchema().onChange = (change) {
      NodeAttribut node = change['node'];
      String ope = change['ope'];
      String path = change['path'];
      String? from = change['from'];
      if (ope == ChangeOpe.rename.name) {
        var sp = from!.split('>');
        currentCompany.glossaryManager.dico.remove(sp.last.toLowerCase());
      }
      if (ope == ChangeOpe.remove.name) {
        currentCompany.glossaryManager.dico.remove(
          node.info.name.toLowerCase(),
        );
      } else if (ope != ChangeOpe.change.name || path.endsWith('.type')) {
        if (autorizedGlossaryType.contains(node.info.type)) {
          currentCompany.glossaryManager.add(node);
        }
      }
    };
  }

  @override
  void addRowWidget(
    TreeNodeData<NodeAttribut> node,
    ModelSchema schema,
    List<Widget> row,
    BuildContext context,
  ) {
    var attr = node.data;

    if (attr.info.type == 'root') {
      row.add(Container(height: rowHeight));
      return;
    }

    row.add(SizedBox(width: 10));
    row.add(
      CellEditor(
        inArray: true,
        key: ValueKey(
          '${schema.getVersionId()}%${attr.info.name}%${attr.info.numUpdateForKey}',
        ),
        acces: ModelAccessorAttr(node: attr, schema: schema, propName: 'title'),
      ),
    );

    // //addWidgetMasterId(attr, row);

    // if (attr.info.type == 'model') {
    //   row.add(SizedBox(width: 10));
    //   row.add(
    //     WidgetVersionState(
    //       margeVertical: 2,
    //       version: null,
    //       model: getSchema(),
    //       attr: attr,
    //     ),
    //   );
    //   row.add(
    //     Padding(
    //       padding: EdgeInsetsGeometry.fromLTRB(5, 0, 0, 0),
    //       child: getChip(
    //         Text(attr.info.properties?['#version'] ?? ''),
    //         color: null,
    //       ),
    //     ),
    //   );
    //   row.add(
    //     TextButton.icon(
    //       onPressed: () async {
    //         node.doTapHeader();
    //       },
    //       label: Icon(Icons.remove_red_eye),
    //     ),
    //   );
    //   row.add(
    //     TextButton.icon(
    //       icon: Icon(Icons.import_export),
    //       onPressed: () async {
    //         if (attr.info.type == 'model') {
    //           var key = attr.info.properties![constMasterID];

    //           // ignore: use_build_context_synchronously
    //           context.push(Pages.modelJsonSchema.id(key));
    //         }
    //       },
    //       label: Text('Json schemas'),
    //     ),
    //   );
    // }
  }

  @override
  Widget? getAttributProperties(BuildContext context) {
    return EditorProperties(
      typeAttr: TypeAttr.model,
      key: keyAttrEditor,
      getModel: () {
        return getSchema();
      },
    );
  }
}
