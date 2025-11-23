import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/core/export/export2ui.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/util.dart';
import 'package:jsonschema/feature/content/pan_browser.dart';
import 'package:jsonschema/feature/content/json_to_ui.dart';
import 'package:jsonschema/feature/content/pan_setting_array.dart';
import 'package:jsonschema/feature/content/pan_setting_form.dart';
import 'package:jsonschema/feature/content/pan_setting_page.dart';
import 'package:jsonschema/feature/content/state_manager.dart';
import 'package:jsonschema/feature/content/widget/widget_content_array.dart';
import 'package:jsonschema/feature/content/widget/widget_content_form.dart';
import 'package:jsonschema/feature/content/widget/widget_content_helper.dart';
import 'package:jsonschema/feature/content/widget/widget_content_object_anyof.dart';
import 'package:jsonschema/feature/content/widget/widget_content_row.dart';
import 'package:jsonschema/widget/widget_tab.dart';

class PanToUi
    with WidgetUIHelper, StateManagerMixin, NameMixin
    implements GenericToUi {
  PanToUi({required this.state, required this.withScroll});

  bool withScroll;
  String labelRoot = 'root';

  BuildContext? context;
  final State state;

  ModelSchema? model;
  ModelSchema? saveOnModel;
  bool saveUIOnModel = false;

  @override
  Export2UI? aExport;

  @override
  void loadData(dynamic data) {
    stateMgr.data = data;
    stateMgr.statesTreeData.clear();
    stateMgr.loadDataInContainer(data);
  }

  WidgetTyped? getWidgetTyped(
    PanInfo panInfo,
    WidgetType parentType,
    String pathJson,
    List<WidgetTyped> rowTab, // list des tabs en cours
  ) {
    // print(
    //   " getWidget for path: $pathJson  template : ${panInfo.pathDataInTemplate}  attr : ${panInfo.attrName} ",
    // );

    if (panInfo.isInvisible) {
      // pas d'enfant selectionné pour etre visible et pas visible
      return null;
    }

    if (pathJson.endsWith('/')) {
      pathJson = pathJson.substring(0, pathJson.length - 1);
    }

    List<ConfigContainer>? layoutConfiguration =
        stateMgr.configLayout[replaceAllIndexes(panInfo.pathDataInTemplate)];

    UIParamContext ctx =
        UIParamContext(
            pathData: pathJson,
            path:
                (panInfo.type != 'Row' &&
                        panInfo.type != 'Bloc' &&
                        parentType != WidgetType.list)
                    ? '$pathJson/${panInfo.attrName}'
                    : pathJson,
            attrName: panInfo.panName ?? panInfo.attrName,
            parentType: parentType,
            rowTab: rowTab,
          )
          ..data = getValueFromPath(stateMgr.data ?? {}, pathJson)
          ..layoutConfiguration = layoutConfiguration;

    if (panInfo is PanInfoObject) {
      if (panInfo.type == 'Array' || panInfo.type == 'PrimitiveArray') {
        return _getPanArray(panInfo, ctx);
      } else {
        return _getPanForm(panInfo, ctx, pathJson);
      }
    } else if (panInfo is PanInfoInput) {
      if (panInfo.pathPanVisible != null) {
        return getObjectInput(this, panInfo, ctx);
      }
    }

    return null;
  }

  WidgetTyped _getWidgetTypedForm(
    Widget wid,
    UIParamContext ctx,
    PanInfoObject panInfo,
    bool withBorder,
  ) {
    return WidgetTyped(
      height: -1,
      name: ctx.attrName,
      content: ctx.data,
      type: WidgetType.form,
      widget:
          withBorder
              ? Container(
                //key: ObjectKey(data),
                margin: EdgeInsets.all(5),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade700, width: 1),
                ),
                child: wid,
              )
              : wid,
    )..messageTooltip = getMessageTooltip(panInfo);
  }

  String? getMessageTooltip(PanInfoObject panInfo) {
    String? messageTooltip;
    var template = panInfo.dataJsonSchema;
    if (template is List && template.first[cstPropLabel] != null) {
      AttributInfo propAttribut = template.first[cstPropLabel];
      StringBuffer msg = getMessage(propAttribut);
      messageTooltip = msg.toString();
    } else if (template is Map && template[cstPropLabel] != null) {
      AttributInfo propAttribut = template[cstPropLabel];
      StringBuffer msg = getMessage(propAttribut);
      messageTooltip = msg.toString();
    }

    return messageTooltip;
  }

  WidgetTyped _getWidgetTypedArray(
    Widget wid,
    UIParamContext ctx,
    bool withBorder,
  ) {
    return WidgetTyped(
      height: -1,
      name: ctx.attrName,
      content: ctx.data,
      type: WidgetType.list,
      widget:
          withBorder
              ? Container(
                margin: EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue, width: 1),
                ),
                child: wid,
              )
              : wid,
    );
  }

  WidgetTyped? _getPanArray(PanInfoObject panInfo, UIParamContext ctx) {
    if (panInfo.pathPanVisible == null) {
      int i = 0;
      var pathDataRow = ctx.path;

      var infoTemplate = getInfoTemplate(
        WidgetConfigInfo(json2ui: this, name: ctx.attrName)..panInfo = panInfo,
        pathDataRow,
        false,
      );

      UIParamContext ctxRow =
          UIParamContext(
              pathData: pathDataRow,
              path: ctx.path,
              attrName: ctx.attrName,
              parentType: ctx.parentType,
              rowTab: ctx.rowTab,
            )
            ..data = ctx.data
            ..infoTemplate = infoTemplate
            ..layoutConfiguration = ctx.layoutConfiguration;

      bool anyOfItem = infoTemplate.anyOf;
      Widget wid = getFormOfRow(anyOfItem, i, ctxRow, panInfo);

      return _getWidgetTypedForm(wid, ctx, panInfo, false);
    }

    var lw = <Widget>[];

    var p = replaceAllIndexes(ctx.path);

    var confLayoutArray = stateMgr.configArray[p];
    confLayoutArray ??= ConfigArrayContainer(name: p);
    ctx.layoutArray = confLayoutArray;

    Widget wid = getArrayWidget(panInfo, lw, ctx);
    var widgetTyped = _getWidgetTypedArray(wid, ctx, true);
    widgetTyped.messageTooltip = getMessageTooltip(panInfo);
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
            ..panInfo = panInfo
            ..onTapSetting = () async {
              if (await showSettingArrayDialog(
                context!,
                ctx.path,
                ctx.layoutArray!,
              )) {
                // ignore: invalid_use_of_protected_member
                state.setState(() {
                  // change config
                });
              }
            },
      children: (pathData) {
        // mode template sans données
        listWidget.clear();
        var lwt = <WidgetTyped>[];

        for (int i = 0; i < (ctx.data as List).length; i++) {
          var row = getWidgetTyped(
            panInfo.children[0],
            WidgetType.list,
            pathData,
            ctx.rowTab,
          );
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
                  ..setPathData('$path[$i]')
                  ..panInfo = panInfo,
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

  WidgetTyped _getPanForm(
    PanInfoObject panInfo,
    UIParamContext ctx,
    String pathJson,
  ) {
    List<WidgetTyped> listContentBlocForConfig = [];
    // print(
    //   ' panInfo.type = ${panInfo.type}   pathJson= $pathJson   attrName= ${panInfo.attrName}',
    // );

    if (panInfo.pathPanVisible == null) {
      var ctxClone = ctx.clone(aPathData: pathJson);
      List<Widget> child = getContentForm(
        panInfo,
        ctxClone,
        listContentBlocForConfig,
      );
      Widget wid = Column(children: child);
      if (panInfo.subtype == 'root' && withScroll) {
        wid = SingleChildScrollView(child: wid);
      }
      return _getWidgetTypedForm(wid, ctx, panInfo, false);
    }

    WidgetContentForm wid = WidgetContentForm(
      ctx: ctx,
      info:
          WidgetConfigInfo(
              name: panInfo.subtype == 'root' ? labelRoot : ctx.attrName,
              json2ui: this,
            )
            ..setPathValue(
              panInfo.type != 'Row'
                  ? '$pathJson/${panInfo.attrName}'
                  : pathJson,
            )
            ..setPathData(pathJson)
            ..panInfo = panInfo
            ..onTapSetting = () async {
              if (await showSettingFormDialog(
                context!,
                pathJson,
                listContentBlocForConfig,
              )) {
                // ignore: invalid_use_of_protected_member
                state.setState(() {
                  // change config
                });
              }
            },
      children: (pathDataComp) {
        listContentBlocForConfig.clear();
        var ctxClone = ctx.clone(aPathData: pathJson);
        return getContentForm(panInfo, ctxClone, listContentBlocForConfig);
      },
    );

    if (modeTemplate) {
      wid.children(ctx.pathData);
    }

    return _getWidgetTypedForm(wid, ctx, panInfo, true);
  }

  List<Widget> getContentForm(
    PanInfoObject panInfo,
    UIParamContext ctx,
    List<WidgetTyped> listContentBloc,
  ) {
    List<WidgetTyped> rowTab = [];

    var lwt = <WidgetTyped>[];

    if (modeTemplate) {
      stateMgr.stateTemplate[ctx.path] ??=
          StateContainerObject()..jsonTemplate = ctx.data;
    }

    for (var panInfoChild in panInfo.children) {
      if (panInfoChild.type == 'Bloc') {
        // ajout les input du bloc (mais sans bloc)
        for (var input in (panInfoChild as PanInfoObject).children) {
          var value = getWidgetTyped(input, WidgetType.form, ctx.path, rowTab);
          if (value != null) {
            // nul si input non affiché
            lwt.add(value);
          }
        }
      } else {
        var w = getWidgetTyped(
          panInfoChild,
          panInfo.type == 'Row' ? WidgetType.list : WidgetType.form,
          ctx.path,
          rowTab,
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

    List<Widget> lw = _doLayout(lwt, ctx, rowTab, listContentBloc);
    return lw;
  }

  List<Widget> _doLayout(
    List<WidgetTyped> lwt,
    UIParamContext ctx,
    List<WidgetTyped> rowTab,
    List<WidgetTyped> listContentBloc,
  ) {
    var lw = <Widget>[];
    var rowInput = <Widget>[];
    const margeHoriz = 20.0;
    bool prevIsContainerTab = false;
    //var rowTab = ctx.rowTab;

    for (var i = 0; i < lwt.length; i++) {
      var aWidgetTypedChild = lwt[i];
      if (aWidgetTypedChild.type != WidgetType.input) {
        // type list ou form
        // cherche la configuration de mise en page
        var confLayout =
            ctx.layoutConfiguration?.firstWhereOrNull((element) {
                  return (element as ConfigFormContainer).name ==
                      aWidgetTypedChild.name;
                })
                as ConfigFormContainer?;

        aWidgetTypedChild.height = confLayout?.height ?? -1;

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

        if (aWidgetTypedChild.forceLayout) {
          layout = aWidgetTypedChild.layout;
        } else {
          aWidgetTypedChild.layout = layout;
        }

        // if ()

        if (layout == 'Flow') {
          addTabInProgressIfNeeded(rowTab, lw);
          lw.add(aWidgetTypedChild.widget);
        } else if (layout == 'Tab') {
          rowTab.add(aWidgetTypedChild);
        } else if (layout == 'OtherTab') {
          addTabInProgressIfNeeded(rowTab, lw);
          rowTab.add(aWidgetTypedChild);
        }

        listContentBloc.add(aWidgetTypedChild);
        prevIsContainerTab = layout == 'Tab';
      } else {
        // gestion des input par 3
        prevIsContainerTab = false;
        addTabInProgressIfNeeded(rowTab, lw);
        if (rowInput.length < 4) {
          addInputFlow(rowInput, lwt, i);
        } else {
          lw.add(Row(spacing: margeHoriz, children: rowInput));
          rowInput = [];
          addInputFlow(rowInput, lwt, i);
        }
      }
    }

    addTabInProgressIfNeeded(rowTab, lw);
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

  void addTabInProgressIfNeeded(List<WidgetTyped> rowTab, List<Widget> dest) {
    if (rowTab.isNotEmpty) {
      List<Widget> tabs = [];
      List<Widget> contents = [];

      for (var element in rowTab) {
        tabs.add(
          Tooltip(
            message: element.messageTooltip ?? '',
            child: Tab(text: camelCaseToWordsCapitalized(element.name)),
          ),
        );
        contents.add(element.widget);
      }
      dest.add(
        WidgetTab(
          listTab: tabs,
          listTabCont: contents,
          heightTab: 30,
          heightContent: true,
          onConfig: () {},
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
      panInfo.children[0].panName =
          '${panInfo.attrName} n°${i + 1}'; // force le nom de paneau
      var row = getWidgetTyped(
        panInfo.children[0],
        WidgetType.list,
        '${ctx.pathData}[$i]',
        ctx.rowTab,
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
  Future<bool> showConfigPanDialog(BuildContext ctx) async {
    var result = false;

    await showDialog<void>(
      context: ctx,
      barrierDismissible: true, // user must tap button!
      builder: (BuildContext context) {
        Size size = MediaQuery.of(ctx).size;
        double width = size.width * 0.9;
        double height = size.height * 0.8;
        return AlertDialog(
          content: SizedBox(
            width: width,
            height: height,
            child: PanSettingPage(state: stateMgr),
          ),
          actions: [
            TextButton(
              child: const Text('cancel'),
              onPressed: () {
                result = false;
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('change layout'),
              onPressed: () {
                result = true;
                Navigator.of(context).pop();
                // ignore: invalid_use_of_protected_member
                state.setState(() {});
              },
            ),
          ],
        );
      },
    );

    return result;
  }

  Future<bool> showSettingArrayDialog(
    BuildContext ctx,
    String path,
    ConfigArrayContainer data,
  ) async {
    var setting = PanSettingArray(config: data);

    var result = false;

    await showDialog<void>(
      context: ctx,
      barrierDismissible: true, // user must tap button!
      builder: (BuildContext context) {
        Size size = MediaQuery.of(ctx).size;
        double width = size.width * 0.9;
        double height = size.height * 0.8;
        return AlertDialog(
          content: SizedBox(width: width, height: height, child: setting),
          actions: [
            //cancel
            TextButton(
              child: const Text('cancel'),
              onPressed: () {
                result = false;
                Navigator.of(context).pop();
              },
            ),

            TextButton(
              child: const Text('change layout'),
              onPressed: () {
                result = true;
                Navigator.of(context).pop();
                stateMgr.configArray[replaceAllIndexes(path)] = data;

                if (saveUIOnModel) {
                  stateMgr.storeConfigLayout(model!);
                } else if (saveOnModel != null) {
                  stateMgr.storeConfigLayout(saveOnModel!);
                }
              },
            ),
          ],
        );
      },
    );

    return result;
  }

  Future<bool> showSettingFormDialog(
    BuildContext ctx,
    String path,
    List<WidgetTyped> data,
  ) async {
    var setting = PanSettingForm(data: data);

    var result = false;

    await showDialog<void>(
      context: ctx,
      barrierDismissible: true, // user must tap button!
      builder: (BuildContext context) {
        Size size = MediaQuery.of(ctx).size;
        double width = size.width * 0.9;
        double height = size.height * 0.8;
        return AlertDialog(
          content: SizedBox(width: width, height: height, child: setting),
          actions: [
            TextButton(
              child: const Text('cancel'),
              onPressed: () {
                result = false;
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('change layout'),
              onPressed: () {
                result = true;
                Navigator.of(context).pop();
                List<ConfigFormContainer> confs = [];
                for (var i = 0; i < data.length; i++) {
                  confs.add(
                    ConfigFormContainer(
                      height: data[i].height,
                      pos: i,
                      name: data[i].name,
                      layout: data[i].layout,
                    ),
                  );
                }
                stateMgr.configLayout[replaceAllIndexes(path)] = confs;

                if (saveUIOnModel) {
                  stateMgr.storeConfigLayout(model!);
                } else if (saveOnModel != null) {
                  stateMgr.storeConfigLayout(saveOnModel!);
                }
              },
            ),
          ],
        );
      },
    );

    return result;
  }
}

class ArrayInfo {
  ArrayInfo({required this.path, required this.index});

  String path;
  int index;
}
