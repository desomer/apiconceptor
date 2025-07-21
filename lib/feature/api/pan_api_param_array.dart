import 'package:flutter/material.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/repaint_manager.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/feature/api/pan_api_editor.dart';

class WidgetArrayParam extends StatefulWidget {
  const WidgetArrayParam({super.key, required this.apiCallInfo});
  final APICallInfo apiCallInfo;

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

    if (widget.apiCallInfo.params.isEmpty) {
      List<APIParamInfo> params = [];
      addParams('path', params);
      addParams('query', params);
      widget.apiCallInfo.params = params;
    }

    double h = widget.apiCallInfo.params.length * 30;
    if (h > 120) h = 120;

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

  void addParams(String type, List<APIParamInfo> params) {
    ModelSchema api = widget.apiCallInfo.currentAPI!;
    AttributInfo? query = api.mapInfoByJsonPath['root>$type'];
    if (query != null) {
      var pos = query.treePosition;
      int i = 0;
      while (true) {
        AttributInfo? param = api.mapInfoByTreePath['$pos;$i'];
        if (param == null) break;
        params.add(APIParamInfo(type: type, name: param.name, info: param));
        i++;
      }
    }
  }

  Widget getRowParam(APIParamInfo param) {
    return Row(
      children: [
        CellCheckEditor(
          key: ValueKey('sel ${param.hashCode}'),
          inArray: true,
          acces: ParamAccess(col: 0, paramInfo: param),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white24,
            border: Border.all(color: Colors.grey),
          ),
          width: 100,
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
          width: 30,
          height: 30,
          alignment: Alignment.center,
          child: Padding(
            padding: EdgeInsetsGeometry.symmetric(horizontal: 5),
            child: Text('='),
          ),
        ),
        CellEditor(
          key: ValueKey('val ${param.hashCode}'),
          inArray: true,
          line: 1,
          acces: ParamAccess(col: 1, paramInfo: param),
        ),
        Container(
          width: 100,
          height: 30,
          alignment: Alignment.center,
          child: Padding(
            padding: EdgeInsetsGeometry.symmetric(horizontal: 5),
            child: Text(param.info?.type ?? ''),
          ),
        ),
      ],
    );
  }
}

class ParamAccess extends ModelAccessor {
  ParamAccess({required this.paramInfo, required this.col});

  final APIParamInfo paramInfo;
  final int col;

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
    return paramInfo.type!='path' || col == 1;
  }

  @override
  void remove() {
    switch (col) {
      case 0:
        paramInfo.toSend = false;
      case 1:
        paramInfo.value = null;
    }
  }

  @override
  void set(value) {
    switch (col) {
      case 0:
        paramInfo.toSend = value;
      case 1:
        paramInfo.value = value;
    }
  }
}
