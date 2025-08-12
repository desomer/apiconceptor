import 'package:flutter/material.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/repaint_manager.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/feature/api/pan_api_editor.dart';
import 'package:jsonschema/widget/editor/search_editor.dart';

class WidgetArrayParam extends StatefulWidget {
  const WidgetArrayParam({
    super.key,
    required this.apiCallInfo,
    required this.constraints,
  });
  final APICallInfo apiCallInfo;
  final BoxConstraints constraints;

  @override
  State<WidgetArrayParam> createState() => _WidgetArrayParamState();
}

class _WidgetArrayParamState extends State<WidgetArrayParam> {
  final _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    repaintManager.addTag(
      ChangeTag.apiparam,
      "_WidgetArrayParamState",
      this,
      () {
        return true;
      },
    );

    Map<String, APIParamInfo> mapParam = {};
    for (var element in widget.apiCallInfo.params) {
      mapParam['${element.type}/${element.name}'] = element;
    }

    addParams('path', widget.apiCallInfo.params, mapParam);
    addParams('query', widget.apiCallInfo.params, mapParam);

    int nbBody = getNbParam('body');
    double hmax = 130;
    if (nbBody == 0) {
      hmax = widget.constraints.maxHeight - 150;
    }

    double h = widget.apiCallInfo.params.length * 30;
    if (h > hmax) h = hmax;

    return Padding(
      padding: EdgeInsetsGeometry.fromLTRB(0, 0, 0, 5),
      child: SizedBox(
        height: h,
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: getArrayParam(),
          ),
        ),
      ),
    );
  }

  Widget getArrayParam() {
    return SizedBox(
      height: widget.apiCallInfo.params.length * 30,
      child: ListView.builder(
        itemExtent: 30,
        itemCount: widget.apiCallInfo.params.length,
        itemBuilder: (context, index) {
          return getRowParam(widget.apiCallInfo.params[index]);
        },
      ),
    );
  }

  int getNbParam(String type) {
    ModelSchema api = widget.apiCallInfo.currentAPI!;
    AttributInfo? query = api.mapInfoByJsonPath['root>$type'];
    int i = 0;
    if (query != null) {
      var pos = query.treePosition;
      while (true) {
        AttributInfo? param = api.mapInfoByTreePath['$pos;$i'];
        if (param == null) break;
        i++;
      }
    }
    return i;
  }

  void addParams(
    String type,
    List<APIParamInfo> params,
    Map<String, APIParamInfo> mapParam,
  ) {
    ModelSchema api = widget.apiCallInfo.currentAPI!;
    AttributInfo? query = api.mapInfoByJsonPath['root>$type'];
    if (query != null) {
      var pos = query.treePosition;
      int i = 0;
      while (true) {
        AttributInfo? param = api.mapInfoByTreePath['$pos;$i'];
        if (param == null) break;
        String idParam = '$type/${param.name}';
        var mapParam2 = mapParam[idParam];
        if (mapParam2 == null) {
          var apiParamInfo = APIParamInfo(
            type: type,
            name: param.name,
            info: param,
          );
          apiParamInfo.toSend = false;
          params.add(apiParamInfo);
          mapParam[idParam] = apiParamInfo;
        } else {
          mapParam2.info = param;
        }
        i++;
      }
    }
  }

  Widget getRowParam(APIParamInfo param) {
    GlobalKey<CellEditorState> keyEditor = GlobalKey();
    GlobalKey<CellCheckEditorState> keySelected = GlobalKey();
    var paramAccessEditor = ParamAccess(
      col: 1,
      paramInfo: param,
      check: keySelected,
      apiCallInfo: widget.apiCallInfo,
    );

    return Row(
      children: [
        CellCheckEditor(
          key: keySelected,
          inArray: true,
          acces: ParamAccess(
            col: 0,
            paramInfo: param,
            apiCallInfo: widget.apiCallInfo,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white24,
            border: Border.all(color: Colors.grey),
          ),
          width: 70,
          height: 30,
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsetsGeometry.symmetric(horizontal: 5),
            child: Text(param.type),
          ),
        ),
        Container(
          width: 150,
          height: 30,
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: Colors.white24,
            border: Border.all(color: Colors.grey),
          ),
          child: Padding(
            padding: EdgeInsetsGeometry.symmetric(horizontal: 5),
            child: Text(param.name),
          ),
        ),
        Container(
          width: 20,
          height: 30,
          alignment: Alignment.center,
          child: Text('='),
        ),
        SearchEditor(
          key: ValueKey('val ${param.hashCode}'),
          childKey: keyEditor,
          paramAccessEditor: paramAccessEditor,
          child: CellEditor(
            key: keyEditor,
            inArray: true,
            line: 1,
            acces: paramAccessEditor,
          ),
        ),
        Container(
          width: 70,
          height: 30,
          alignment: Alignment.center,
          child: Text(param.info?.type ?? ''),
        ),

        SizedBox(width: 5),
        if (param.info?.properties?['required'] == true)
          Icon(Icons.check_circle_outline),
        if (param.info?.properties?['enum'] != null) Icon(Icons.checklist),
      ],
    );
  }
}

class ParamAccess extends ValueAccessor {
  ParamAccess({
    required this.paramInfo,
    required this.col,
    this.check,
    required this.apiCallInfo,
  });

  final APIParamInfo paramInfo;
  final int col;
  final GlobalKey<CellCheckEditorState>? check;
  final APICallInfo apiCallInfo;

  @override
  dynamic get() {
    switch (col) {
      case 0:
        return paramInfo.toSend;
      case 1:
        return paramInfo.value ?? '';
    }
  }

  @override
  String getName() {
    return '';
  }

  @override
  bool isEditable() {
    return paramInfo.type != 'path' || col == 1;
  }

  @override
  void remove() {
    apiCallInfo.changeUrl.value++;
    switch (col) {
      case 0:
        paramInfo.toSend = false;
        break;
      case 1:
        paramInfo.value = null;
        break;
    }
  }

  @override
  void set(value) {
    apiCallInfo.changeUrl.value++;
    switch (col) {
      case 0:
        paramInfo.toSend = value;
        break;
      case 1:
        paramInfo.value = value;
        if (check case final c!) {
          c.currentState?.check(true);
        }
        break;
    }
  }
}
