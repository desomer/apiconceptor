import 'package:flutter/material.dart';
import 'package:jsonschema/core/repaint_manager.dart';
import 'package:jsonschema/core/api/call_manager.dart';
import 'package:jsonschema/feature/api/api_widget_request_helper.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';
import 'package:jsonschema/widget/editor/search_editor.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';
import 'package:jsonschema/widget/widget_overflow.dart';

class WidgetArrayParam extends StatefulWidget {
  const WidgetArrayParam({
    super.key,
    required this.requestHelper,
    required this.constraints,
  });
  final WidgetRequestHelper requestHelper;
  final BoxConstraints constraints;

  @override
  State<WidgetArrayParam> createState() => _WidgetArrayParamState();
}

class _WidgetArrayParamState extends State<WidgetArrayParam> with WidgetHelper {
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

    bool hasBody = widget.requestHelper.apiCallInfo.initListParams();

    double hmax = 130;
    if (!hasBody) {
      hmax = widget.constraints.maxHeight - 150;
    }

    double h = widget.requestHelper.apiCallInfo.params.length * 30;
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
      height: widget.requestHelper.apiCallInfo.params.length * 30,
      child: ListView.builder(
        itemExtent: 30,
        itemCount: widget.requestHelper.apiCallInfo.params.length,
        itemBuilder: (context, index) {
          return getRowParamWidget(
            widget.requestHelper.apiCallInfo.params[index],
          );
        },
      ),
    );
  }



  Widget getRowParamWidget(APIParamInfo param) {
    GlobalKey<CellEditorState> keyEditor = GlobalKey(debugLabel: 'keyEditor');
    GlobalKey<CellCheckEditorState> keySelected = GlobalKey(
      debugLabel: 'keySelected',
    );
    var paramAccessEditor = ParamAccess(
      col: 1,
      paramInfo: param,
      check: keySelected,
      requestHelper: widget.requestHelper,
    );

    return getToolTip(
      toolContent: getTooltipFromAttr(param.info),
      child: NoOverflowErrorFlex(
        direction: Axis.horizontal,
        children: [
          CellCheckEditor(
            key: keySelected,
            inArray: true,
            acces: ParamAccess(
              col: 0,
              paramInfo: param,
              requestHelper: widget.requestHelper,
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
      ),
    );
  }
}

class ParamAccess extends ValueAccessor {
  ParamAccess({
    required this.paramInfo,
    required this.col,
    this.check,
    required this.requestHelper,
  });

  final APIParamInfo paramInfo;
  final int col;
  final GlobalKey<CellCheckEditorState>? check;
  final WidgetRequestHelper requestHelper;

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
    requestHelper.changeUrl.value++;
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
    requestHelper.changeUrl.value++;
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
