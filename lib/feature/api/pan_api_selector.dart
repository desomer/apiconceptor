import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:json2yaml/json2yaml.dart';
import 'package:jsonschema/core/api/call_api_manager.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/util.dart';
import 'package:jsonschema/feature/api/html_swagger.dart';
import 'package:jsonschema/feature/api/pan_api_import.dart';
import 'package:jsonschema/feature/pan_attribut_editor.dart';
import 'package:jsonschema/pages/model_design/design_api_page.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/tree_editor/pan_yaml_tree.dart';
import 'package:jsonschema/widget/tree_editor/tree_view.dart';
import 'package:jsonschema/widget/widget_scroller.dart';
import 'package:jsonschema/widget/widget_version_state.dart';

import '../../core/designer/core/widget_catalog/export/export_csv.dart';

// ignore: must_be_immutable
class PanAPISelector extends PanYamlTree {
  PanAPISelector({
    required this.onSelModel,
    required this.browseOnly,
    super.key,
    required super.getSchemaFct,
  });

  final bool browseOnly;
  final Function? onSelModel;

  @override
  bool withEditor() {
    return !browseOnly;
  }

  @override
  void addRowWidget(
    TreeNodeData<NodeAttribut> node,
    ModelSchema schema,
    List<Widget> row,
    BuildContext context,
  ) {
    var info = node.data.info;
    if (info.type == 'ope') {
      row.add(
        CellEditor(
          inArray: true,
          key: ValueKey('${info.name}%${info.numUpdateForKey}'),
          acces: ModelAccessorAttr(
            node: node.data,
            schema: schema,
            propName: 'summary',
          ),
        ),
      );

      row.add(SizedBox(width: 10));
      row.add(
        WidgetVersionState(
          margeVertical: 2,
          version: null,
          model: schema,
          attr: node.data,
          modelParent: schema,
        ),
      );
      // row.add(
      //   TextButton.icon(
      //     onPressed: () async {
      //       // await goToAPI(attr, 1, context: context);
      //     },
      //     label: Icon(Icons.remove_red_eye),
      //   ),
      // );
      // row.add(
      //   TextButton.icon(
      //     icon: Icon(Icons.import_export),
      //     onPressed: () async {
      //       // await goToAPI(attr, 1, subtabNumber: 2, context: context);
      //     },
      //     label: Text('Test fake API'),
      //   ),
      // );
    }
  }

  @override
  Widget? getAttributProperties(BuildContext context) {
    return EditorProperties(
      typeAttr: TypeAttr.api,
      key: keyAttrEditor,
      getModel: () {
        return getSchema();
      },
      onClose: () {
        doShowAttrEditor(null);
      },
    );
  }

  @override
  Future<void> onActionRow(
    TreeNodeData<NodeAttribut> node,
    BuildContext context,
  ) async {
    var attr = node.data;
    goToAPI(attr, context: context);
  }

  Future<void> goToAPI(
    NodeAttribut attr, {
    required BuildContext context,
  }) async {
    var sel = getSchema().getNodeByMasterIdPath(attr.info.masterID)!;

    if (sel.info.type == 'ope') {
      if (onSelModel != null) {
        onSelModel!(sel.info.masterID!);
      } else {
        RouteManager.goto(Pages.apiDetail.id(sel.info.masterID!), context);
      }
    }
  }

  Future<void> showImportDialog(BuildContext ctx) async {
    return showDialog<void>(
      context: ctx,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return PanAPIImport(yamlEditorConfig: getYamlConfig());
      },
    );
  }

  final ValueNotifier<String> modelSwagger = ValueNotifier<String>('');
  Map yamlSwagger = {};

  void showSwaggerDialog(BuildContext ctx) async {
    showDialog<void>(
      context: ctx,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Swagger'),
          content: WidgetScroller(
            child: ValueListenableBuilder(
              valueListenable: modelSwagger,
              builder: (context, value, child) {
                return YamlHighlightViewer(
                  yaml: value.isEmpty ? 'Generate swagger...' : value,
                );
              },
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                if (modelSwagger.value.startsWith('Generat')) return;
                Navigator.of(context).pop();
                var html = HtmlSwagger().htmlSwagger(yamlSwagger);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Swagger HTML exported')),
                );
                var path = await exportFile(html, fileName: "swagger.html");
                await openHtmlInChrome(path, html);
              },
              icon: Icon(Icons.download),
              label: Text('Download HTML Swagger & Open in browser'),
            ),
            TextButton.icon(
              onPressed: () {
                if (modelSwagger.value.startsWith('Generat')) return;
                Navigator.of(context).pop();
                Clipboard.setData(ClipboardData(text: modelSwagger.value));
                exportFile(modelSwagger.value, fileName: "swagger.yaml");
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Swagger YAML copied to clipboard')),
                );
              },
              icon: Icon(Icons.copy),
              label: Text('Download Swagger YAML & Copy to clipboard'),
            ),

            TextButton(
              onPressed: () {
                if (modelSwagger.value.startsWith('Generat')) return;
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );

    var cmp = {'schemas': {}};
    var path = {};
    var servers = [];

    var listAPi = currentCompany.listAPI!;
    var r = listAPi.mapInfoByTreePath.entries;

    int nb = 0;
    for (MapEntry element in r) {
      AttributInfo value = element.value;
      if (value.type == 'ope') {
        nb++;
      }
    }

    int i = 0;

    for (MapEntry element in r) {
      AttributInfo value = element.value;
      if (value.type == 'ope') {
        modelSwagger.value = 'Generating swagger... ($i / $nb)';
        await exportSwagger(value, servers, cmp, path);
        i++;
      }
    }

    yamlSwagger = getOpenApiSpec(
      servers,
      path,
      cmp,
      'apis?id=${currentCompany.currentNameSpace}&ns=${currentCompany.currentNameSpace}',
    );
    modelSwagger.value = json2yaml(
      toStringKeyMap(yamlSwagger),
      yamlStyle: YamlStyle.generic,
    );
  }

  Future<APICallManager> exportSwagger(
    AttributInfo value,
    List<dynamic> servers,
    Map<String, Map<dynamic, dynamic>> cmp,
    Map<dynamic, dynamic> path,
  ) async {
    currentCompany.listAPI!.selectedAttr =
        currentCompany.listAPI!.nodeByMasterId[value.masterID]!.first;
    var getAPICall = _getAPICall(currentCompany.listAPI!.namespace!, value);

    Map aPath = await getAPICall.generateSwagger(servers, cmp);
    for (var key in aPath.keys) {
      if (path[key] == null) {
        path[key] = aPath[key];
      } else {
        // Fusionner les méthodes HTTP si le chemin existe déjà
        (path[key] as Map).addAll(aPath[key]);
      }
    }
    return getAPICall;
  }

  APICallManager _getAPICall(String namespace, AttributInfo attr) {
    String httpOpe = attr.name.toLowerCase();
    var apiCallInfo = APICallManager(
      namespace: namespace,
      attrApi: attr,
      httpOperation: httpOpe,
    );
    return apiCallInfo;
  }
}
