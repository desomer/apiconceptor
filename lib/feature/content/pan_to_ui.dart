import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/content/browser_pan.dart';
import 'package:jsonschema/feature/content/json_to_ui.dart';
import 'package:jsonschema/feature/content/state_manager.dart';
import 'package:jsonschema/feature/content/widget/widget_content_array.dart';
import 'package:jsonschema/feature/content/widget/widget_content_form.dart';
import 'package:jsonschema/feature/content/widget/widget_content_helper.dart';
import 'package:jsonschema/feature/content/widget/widget_content_object_anyof.dart';
import 'package:jsonschema/feature/content/widget/widget_content_row.dart';
import 'package:jsonschema/widget/widget_tab.dart';

class PanToUi with WidgetUIHelper implements GenericToUi {
  PanToUi({required this.state});

  PanContext? panContext;

  BuildContext? context;
  final State state;

  ModelSchema? model;

  ModelSchema? saveOnModel;
  bool saveUIOnModel = false;

  @override
  void loadData(dynamic data) {
    stateMgr.data = data;
    stateMgr.statesTreeData.clear();
    stateMgr.loadDataInContainer(data);
  }

  WidgetTyped? getWidget(
    PanInfo panInfo,
    WidgetType parentType,
    String pathJson,
  ) {
    print(
      " getWidget for path: $pathJson  template : ${panInfo.pathDataInTemplate}  attr : ${panInfo.attrName} ",
    );
 
    if (pathJson.endsWith('/')) {
      pathJson = pathJson.substring(0, pathJson.length - 1);
    }

    var rowTab = <WidgetTyped>[];
    UIParamContext ctx = UIParamContext(
      pathData: pathJson,
      path:
          (panInfo.type != 'Row' &&
                  panInfo.type != 'Bloc' &&
                  parentType != WidgetType.list)
              ? '$pathJson/${panInfo.attrName}'
              : pathJson,
      attrName: panInfo.attrName,
      parentType: parentType,
      rowTab: rowTab,
    )..data = getValueFromPath(stateMgr.data, pathJson);

    if (panInfo is PanInfoObject) {
      if (panInfo.type == 'Array' || panInfo.type == 'PrimitiveArray') {
        return _getArray(panInfo, ctx);
      } else {
        var widget = _getPanForm(panInfo, ctx, pathJson);
        return _getWidgetTypedForm(widget, ctx);
      }
    } else if (panInfo is PanInfoInput) {
      return getObjectInput(this, panInfo, ctx);
    }

    return null;
  }

  WidgetTyped _getWidgetTypedForm(Widget wid, UIParamContext ctx) {
    return WidgetTyped(
      height: -1,
      name: ctx.attrName,
      content: ctx.data,
      type: WidgetType.form,
      widget: Container(
        //key: ObjectKey(data),
        margin: EdgeInsets.all(5),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade700, width: 1),
        ),
        child: wid,
      ),
    );
  }

  WidgetTyped _getWidgetTypedArray(Widget wid, UIParamContext ctx) {
    return WidgetTyped(
      height: -1,
      name: ctx.attrName,
      content: ctx.data,
      type: WidgetType.list,
      widget: Container(
        margin: EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue, width: 1),
        ),
        child: wid,
      ),
    );
  }

  WidgetTyped? _getArray(PanInfoObject panInfo, UIParamContext ctx) {
    var lw = <Widget>[];

    var p = replaceAllIndexes(ctx.path);

    var confLayoutArray = stateMgr.configArray[p];
    confLayoutArray ??= ConfigArrayContainer(name: p);
    ctx.layoutArray = confLayoutArray;

    Widget wid = getArrayWidget(panInfo, lw, ctx);

    var widgetTyped = _getWidgetTypedArray(wid, ctx);

    var confLayout =
        ctx.layoutConfiguration?.firstWhereOrNull((element) {
              return element.name == ctx.attrName;
            })
            as ConfigFormContainer?;

    String layout = 'Flow';
    if (confLayout != null) {
      layout = confLayout.layout;
    }
    widgetTyped.layout = layout;
    if (layout == 'Flow') {
      addTabIn(ctx.rowTab, lw);
    } else if (layout == 'Tab') {
      ctx.rowTab.add(widgetTyped);
      return null;
    } else if (layout == 'OtherTab') {
      addTabIn(ctx.rowTab, lw);
      ctx.rowTab.add(widgetTyped);
      return null;
    }
    lw.add(wid);

    return widgetTyped;
  }

  WidgetContentArray getArrayWidget(
    PanInfoObject panInfo,
    List<Widget> listWidget,
    UIParamContext ctx,
  ) {
    var path = ctx.path;

    WidgetContentArray wid = WidgetContentArray(
      ctx: ctx,
      info:
          WidgetConfigInfo(name: ctx.attrName, json2ui: this)
            ..setPathValue(ctx.path)
            ..setPathData(ctx.pathData)
            ..panInfo = panInfo,
      // ..onTapSetting = () async {
      //   if (await showSettingArrayDialog(
      //     context!,
      //     ctx.path,
      //     ctx.layoutArray!,
      //   )) {
      //     // ignore: invalid_use_of_protected_member
      //     state.setState(() {
      //       // change config
      //     });
      //   }
      // }
      children: (pathData) {
        // mode template sans données
        listWidget.clear();
        var lwt = <WidgetTyped>[];

        for (int i = 0; i < (ctx.data as List).length; i++) {
          var row = getWidget(panInfo.children[0], WidgetType.list, pathData);
          if (row != null) {
            lwt.add(row);
          }
        }

        for (int i = 0; i < lwt.length; i++) {
          listWidget.add(
            getArrayItemAction(i, lwt[i].widget, ctx.data[i], null, () {}),
          );
        }

        return listWidget;
      },
      getRow: (pathDataRow, rowData, i, k, onDelete) {
        var infoTemplate = getInfoTemplate(
          WidgetConfigInfo(json2ui: this, name: ctx.attrName)
            ..panInfo = panInfo,
          pathDataRow,
          false,
        );

        UIParamContext ctxRow =
            UIParamContext(
                pathData: pathDataRow,
                path: path,
                attrName: ctx.attrName,
                parentType: ctx.parentType,
                rowTab: ctx.rowTab,
              )
              ..data = rowData
              ..infoTemplate = infoTemplate
              ..layoutConfiguration = ctx.layoutConfiguration;

        if (ctx.layoutArray!.listOfRow) {
          // mode ligne par tableau
          Widget wid = WidgetContentRow(
            ctxRow: ctxRow,
            rowIdx: i,
            info:
                WidgetConfigInfo(json2ui: this, name: ctx.attrName)
                  ..setPathValue('$path[$i]')
                  ..setPathData('$path[$i]'),
          );

          return getArrayItemAction(i, wid, rowData, k, onDelete);
        } else {
          // mode ligne de formulaire
          bool anyOfItem = infoTemplate.anyOf;
          Widget wid = getFormOfRow(anyOfItem, i, ctxRow, panInfo);

          return getArrayItemAction(i, wid, rowData, k, onDelete);
        }
      },
    );

    if (modeTemplate) {
      // charge les templates mais ne les affiche pas
      wid.children(ctx.pathData);
      listWidget.clear();
    }
    return wid;
  }

  WidgetContentForm _getPanForm(
    PanInfoObject panInfo,
    UIParamContext ctx,
    String pathJson,
  ) {
    List<WidgetTyped> listContentBlocForConfig = [];

    print(
      ' panInfo.type = ${panInfo.type}   pathJson= $pathJson   attrName= ${panInfo.attrName}',
    );

    WidgetContentForm wid = WidgetContentForm(
      ctx: ctx,
      info:
          WidgetConfigInfo(name: ctx.attrName, json2ui: this)
            ..setPathValue(
              panInfo.type != 'Row'
                  ? '$pathJson/${panInfo.attrName}'
                  : pathJson,
            )
            ..setPathData(pathJson)
            ..panInfo = panInfo,
      // ..onTapSetting = () async {
      //   if (await showSettingFormDialog(
      //     context!,
      //     ctx.path,
      //     listContentBlocForConfig,
      //   )) {
      //     // ignore: invalid_use_of_protected_member
      //     state.setState(() {
      //       // change config
      //     });
      //   }
      // }
      children: (pathDataComp) {
        listContentBlocForConfig.clear();
        var ctxClone = ctx.clone(aPathData: pathJson);
        return getContentForm(panInfo, ctxClone, listContentBlocForConfig);
      },
    );

    if (modeTemplate) {
      wid.children(ctx.pathData);
    }
    return wid;
  }

  List<Widget> getContentForm(
    PanInfoObject panInfo,
    UIParamContext ctx,
    List<WidgetTyped> listContentBloc,
  ) {
    var lwt = <WidgetTyped>[];

    if (modeTemplate) {
      stateMgr.stateTemplate[ctx.path] ??=
          StateContainerObject()..jsonTemplate = ctx.data;
    }

    for (var panInfoChild in panInfo.children) {
      if (panInfoChild.type == 'Bloc') {
        // ajout les input du bloc
        for (var input in (panInfoChild as PanInfoObject).children) {
          lwt.add(getWidget(input, WidgetType.form, ctx.path)!);
        }
      } else {
        var w = getWidget(
          panInfoChild,
          panInfo.type == 'Row' ? WidgetType.list : WidgetType.form,
          ctx.path,
        );
        if (w != null) {
          if (panInfoChild.type == 'Bloc') {
            w.layout = 'Flow';
            w.forceLayout = true;
          }

          lwt.add(w);
        }
      }
    }

    var lw = <Widget>[];
    var rowInput = <Widget>[];
    const margeHoriz = 20.0;
    bool prevIsContainerTab = false;
    var rowTab = ctx.rowTab;

    for (var i = 0; i < lwt.length; i++) {
      // type list ou form
      if (lwt[i].type != WidgetType.input) {
        // cherche la configuration de mise en page
        var confLayout =
            ctx.layoutConfiguration?.firstWhereOrNull((element) {
                  return (element as ConfigFormContainer).name == lwt[i].name;
                })
                as ConfigFormContainer?;

        lwt[i].height = confLayout?.height ?? -1;

        bool nextIsContainer = false;
        if (i < lwt.length - 1) {
          if (lwt[i + 1].type != WidgetType.input) {
            nextIsContainer = true;
          }
        }

        String layout =
            (((ctx.pathData == '' && i == 0) || !nextIsContainer) &&
                    !prevIsContainerTab)
                ? 'Flow'
                : 'Tab';

        if (confLayout != null) {
          layout = confLayout.layout;
        }

        if (rowInput.isNotEmpty) {
          // ajouter les inputs
          lw.add(Row(spacing: margeHoriz, children: rowInput));
          rowInput = [];
        }

        if (lwt[i].forceLayout) {
          layout = lwt[i].layout;
        } else {
          lwt[i].layout = layout;
        }

        if (layout == 'Flow') {
          addTabIn(rowTab, lw);
          lw.add(lwt[i].widget);
        } else if (layout == 'Tab') {
          rowTab.add(lwt[i]);
        } else if (layout == 'OtherTab') {
          addTabIn(rowTab, lw);
          rowTab.add(lwt[i]);
        }

        listContentBloc.add(lwt[i]);
        prevIsContainerTab = layout == 'Tab';
      } else {
        // gestion des input par 3
        prevIsContainerTab = false;
        addTabIn(rowTab, lw);
        if (rowInput.length < 4) {
          addInputFlow(rowInput, lwt, i);
        } else {
          lw.add(Row(spacing: margeHoriz, children: rowInput));
          rowInput = [];
          addInputFlow(rowInput, lwt, i);
        }
      }
    }

    addTabIn(rowTab, lw);
    if (rowInput.isNotEmpty) {
      int l = rowInput.length;
      // ajout la derniére ligne d'input
      for (var i = l; i < 4; i++) {
        rowInput.add(Flexible(child: Container()));
      }
      lw.add(Row(spacing: margeHoriz, children: rowInput));
      rowInput = [];
    }
    return lw;
  }

  void addInputFlow(List<Widget> rowInput, List<WidgetTyped> lwt, int i) {
    if (rowInput.isEmpty) rowInput.add(SizedBox(height: 1));
    var widget2 = Flexible(child: lwt[i].widget);
    rowInput.add(widget2);
  }

  void addTabIn(List<WidgetTyped> rowTab, List<Widget> dest) {
    if (rowTab.isNotEmpty) {
      List<Widget> tabs = [];
      List<Widget> contents = [];

      for (var element in rowTab) {
        tabs.add(Tab(text: element.name));
        contents.add(element.widget);
      }
      dest.add(
        WidgetTab(
          listTab: tabs,
          listTabCont: contents,
          heightTab: 30,
          heightContent: true,
        ),
      );
      rowTab.clear();
    }
  }

  // dynamic getValueFromPath(
  //   Map<String, dynamic> map,
  //   String path, {
  //   String separator = '/',
  // }) {
  //   final keys = path.split(separator);
  //   dynamic current = map;

  //   for (final key in keys) {
  //     if (key == '') continue;
  //     if (current is Map<String, dynamic> && current.containsKey(key)) {
  //       current = current[key];
  //     } else {
  //       return null; // clé introuvable ou structure non conforme
  //     }
  //   }

  //   return current;
  // }

  dynamic getValueFromPath(Map<String, dynamic> json, String path) {
    final regex = RegExp(r'([^/\[\]]+)|\[(\d+)\]');
    dynamic current = json;

    for (final match in regex.allMatches(path)) {
      final key = match.group(1);
      final index = match.group(2);

      if (key != null) {
        if (current is Map) {
          current = current[key];
        } else {
          throw Exception('Clé "$key" introuvable dans un objet non-map');
        }
      } else if (index != null) {
        final i = int.parse(index);
        if (current is List) {
          current = current[i];
        } else {
          throw Exception('Index [$i] utilisé sur un objet non-liste');
        }
      }
    }

    return current;
  }

  @override
  Widget getFormOfRow(
    bool anyOfItem,
    int i,
    UIParamContext ctx,
    PanInfo? panInfo,
  ) {
    Widget wid;

    var path = ctx.path;
    if (anyOfItem) {
      wid = WidgetContentObjectAnyOf(
        children: (pathDataRow, data2, panInfoChoised) {
          List<WidgetTyped> listContentBloc = [];
          var cloneCtx = ctx.clone(aPath: '$path[$i]', aPathData: pathDataRow);
          return getContentForm(panInfoChoised!, cloneCtx, listContentBloc);
        },
        info:
            WidgetConfigInfo(json2ui: this, name: "choise items")
              ..inArrayValue = ctx.data
              ..setPathValue('$path[$i]')
              ..setPathData('$path[$i]')
              ..panInfo = panInfo,
      );
    } else {
      // ligne normale
      panInfo as PanInfoObject;
      panInfo.children[0].attrName = '$i'; // force le nom de paneau
      var row = getWidget(
        panInfo.children[0],
        WidgetType.list,
        '${ctx.pathData}[$i]',
      );
      if (row == null) {
        wid = SizedBox();
      } else {
        wid = row.widget;
      }
    }
    return wid;
  }

  @override
  Future<bool> showConfigPanDialog(BuildContext ctx) {
    throw UnimplementedError();
  }
}

class ArrayInfo {
  ArrayInfo({required this.path, required this.index});

  String path;
  int index;
}
