import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart' show GoRouterState;
import 'package:highlight/languages/yaml.dart';
import 'package:json2yaml/json2yaml.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/pages/content/content_map_page_detail.dart';
import 'package:jsonschema/pages/router_config.dart';
import 'package:jsonschema/pages/router_generic_page.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/editor/code_editor.dart';
import 'package:jsonschema/widget/widget_breadcrumb.dart';

// ignore: must_be_immutable
class MappingEnginePage extends GenericPageStateless {
  const MappingEnginePage({super.key});

  @override
  bool isCacheValid(GoRouterState state, String uri) {
    return false;
  }

  String prettyPrintJson(dynamic input) {
    const JsonEncoder encoder = JsonEncoder.withIndent('   ');
    return encoder.convert(input);
  }

  @override
  Widget build(BuildContext context) {
    MappingEngineConfig config = currentCompany.currentMapEngine!;

    var object = {
      "src": config.currentSrcModel!.id,
      "srcMamespace": config.currentSrcModel!.namespace,
      "dest": config.currentDestModel!.id,
      "destMamespace": config.currentDestModel!.namespace,
      "fields": config.listMapping.map((e) => e.getJson()).toList(),
    };

    Map<String, dynamic> dest = {};
    browseJsonNode(object, dest, []);

    // dest to yaml
    var yamlString = json2yaml(dest, yamlStyle: YamlStyle.generic);

    return TextEditor(
      config: CodeEditorConfig(
        readOnly: true,
        mode: yaml,
        getText: () => yamlString,
        onChange: (String json, CodeEditorConfig config) {
          // Handle changes if needed
        },
        notifError: ValueNotifier(''),
      ),
      header: 'Parameters',
    );
  }

  WidgetFactory getFactory(String keyFactory) {
    WidgetFactory? f = cacheLinkPage.get(keyFactory);
    if (f == null) {
      f = WidgetFactory();
      cacheLinkPage.put(keyFactory, f);
    }
    return f;
  }

  @override
  NavigationInfo? initNavigation(
    GoRouterState routerState,
    BuildContext context,
    PageInit? pageInit,
  ) {
    return NavigationInfo()
      ..navLeft = [
        BreadNode(
          icon: const Icon(Icons.api_outlined),
          settings: const RouteSettings(name: 'Map Spec.'),
          type: BreadNodeType.widget,
          path: Pages.mapDataDetail.urlpath,
        ),

        BreadNode(
          icon: const Icon(Icons.engineering),
          settings: const RouteSettings(name: 'Yaml'),
          type: BreadNodeType.widget,
          path: Pages.mapDataYaml.urlpath,
        ),
      ];
  }

  void browseJsonNode(Map object, Map dest, List<String> path) {
    // browse all nodes
    object.forEach((key, value) {
      if (value is Map) {
        if (value.isNotEmpty) {
          dest[key] = <String, dynamic>{};
          browseJsonNode(value, dest[key], [...path, key]);
        }
      } else if (value is List) {
        if (value.isNotEmpty) {
          var arrDest = [];
          dest[key] = arrDest;
          for (var item in value) {
            arrDest.add(<String, dynamic>{});
            if (item is Map) {
              browseJsonNode(item, arrDest.last, [...path, key]);
            }
          }
        }
      } else {
        if (key == 'options' || key == '\$options') {
        } else if (key == 'source') {
          var attr = currentCompany.currentMapEngine!.currentSrcModel!
              .getNodeByMasterIdPath(value);
          dest[key] =
              attr != null ? attr.info.getJsonPath(withRoot: false) : value;
        } else if (key == 'target') {
          var attr = currentCompany.currentMapEngine!.currentDestModel!
              .getNodeByMasterIdPath(value);
          dest[key] =
              attr != null ? attr.info.getJsonPath(withRoot: false) : value;
        } else {
          dest[key] = value;
        }
      }
    });
  }
}
