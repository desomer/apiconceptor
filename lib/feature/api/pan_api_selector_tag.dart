import 'package:flutter/material.dart';
import 'package:jsonschema/core/export/export2swagger.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/widget/widget_expansive.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget/widget_overflow.dart';
import 'package:jsonschema/widget/widget_version_state.dart';
import 'package:markdown_widget/config/extensions.dart';

class PanApiSelectorTag extends StatefulWidget {
  const PanApiSelectorTag({
    super.key,
    required this.getSchemaFct,
    this.onSelModel,
  });
  final Function getSchemaFct;
  final Function? onSelModel;

  @override
  State<PanApiSelectorTag> createState() => _PanApiSelectorTagState();
}

class _PanApiSelectorTagState extends State<PanApiSelectorTag>
    with WidgetHelper {
  Widget? _cacheContent;
  late ModelSchema _schema;

  @override
  Widget build(BuildContext context) {
    dynamic futureModel = widget.getSchemaFct();
    if (futureModel is Future<ModelSchema>) {
      return FutureBuilder<ModelSchema>(
        future: futureModel,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _schema = snapshot.data!;

            _cacheContent = _getContent(context);

            return _cacheContent!;
          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else {
            return getLoader();
          }
        },
      );
    } else {
      _schema = futureModel as ModelSchema;
      _cacheContent = _getContent(context);
      return _cacheContent!;
    }
  }

  Widget _getContent(BuildContext context) {
    ExportToSwagger export = ExportToSwagger();
    export.browse(_schema, false);

    return ListView.builder(
      itemCount: export.tags.length,
      itemBuilder: (context, index) {
        var tag = export.tags[index];

        return WidgetExpansive(
          color: Colors.transparent,
          headers: [Text(tag.name)],
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: tag.apis.length,
            itemBuilder: (context, index) {
              var t = tag.apis[index];
              return getApiWidget(t);
            },
          ),
        );
      },
    );
  }

  ListTile getApiWidget(NodeTag tag) {
    Widget header = getHttpOpe(tag.name)!;

    List<Widget> pathWidget = [];

    NodeAttribut? nd = tag.node;
    String bufPath = '';
    nd = nd.parent;
    int level = 0;

    while (nd != null) {
      var n = getKeyParamFromYaml(nd.yamlNode.key).toLowerCase();
      var isServer = nd.info.properties?['\$server'];
      if (isServer != null) {
        n = '$isServer';
      }
      List<Widget> wpath = getHeaderPath(
        n,
        TextStyle(fontWeight: FontWeight.w400),
      );
      String sep = '';
      if (level > 0 && !n.endsWith('/') && !bufPath.startsWith('/')) {
        sep = '/';
        pathWidget = [...wpath, Text(sep), ...pathWidget];
      } else {
        pathWidget = [...wpath, ...pathWidget];
      }
      bufPath = n + sep + bufPath;
      if (nd.info.properties?['\$server'] != null) {
        break;
      }
      nd = nd.parent;
      level++;
    }
    pathWidget.insert(0, header);

    pathWidget.add(
      Padding(
        padding: EdgeInsetsGeometry.symmetric(horizontal: 50),
        child: Text(
          tag.node.info.properties?['summary'] ?? '',
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey,
            fontWeight: FontWeight.w100,
          ),
        ),
      ),
    );

    pathWidget.add(Spacer());
    pathWidget.add(WidgetVersionState(margeVertical: 2,));

    return ListTile(
      title: Container(
        padding: EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(7)),
          border: Border.all(color: getColor(tag.name) ?? Colors.black),
          color: (getColor(tag.name) ?? Colors.black).toOpacity(0.1),
        ),
        child: ClipRect(
          clipBehavior: Clip.hardEdge,
          child: NoOverflowErrorFlex(
            mainAxisSize: MainAxisSize.max,
            direction: Axis.horizontal,
            children: pathWidget,
          ),
        ),
      ),
      onTap: () {
        var sel = _schema.nodeByMasterId[tag.node.info.masterID]!;
        _schema.selectedAttr = sel;
        widget.onSelModel!(tag.node.info.masterID);
      },
    );
  }

  Widget getLoader() {
    return Center(child: CircularProgressIndicator());
  }
}
