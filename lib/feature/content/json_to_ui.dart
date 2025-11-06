import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/core/export/export2ui.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/content/browser_pan.dart';
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

enum WidgetType { root, form, list, input }

class WidgetTyped {
  final String name;
  final Widget widget;
  final WidgetType type;

  final dynamic content;
  int height;

  String layout = 'Flow';
  bool forceLayout = false;

  WidgetTyped({
    required this.height,
    required this.name,
    required this.content,
    required this.type,
    required this.widget,
  });
}

class UIParamContext {
  dynamic data;
  final String pathData;
  final String path;
  final String attrName;
  final WidgetType parentType;
  final List<WidgetTyped> rowTab;

  List<ConfigContainer>? layoutConfiguration;
  ConfigArrayContainer? layoutArray;
  InfoTemplate? infoTemplate;

  UIParamContext({
    required this.pathData,
    required this.path,
    required this.attrName,
    required this.parentType,
    required this.rowTab,
  });

  //clone
  UIParamContext clone({String? aPath, String? aPathData, String? aAttrName}) {
    return UIParamContext(
        pathData: aPathData ?? pathData,
        path: aPath ?? path,
        attrName: aAttrName ?? attrName,
        parentType: parentType,
        rowTab: rowTab,
      )
      ..layoutConfiguration = layoutConfiguration
      ..layoutArray = layoutArray
      ..infoTemplate = infoTemplate
      ..data = data;
  }
}

abstract class GenericToUi with WidgetUIHelper {
  Future<bool> showConfigPanDialog(BuildContext ctx);
  Widget getFormOfRow(
    bool anyOfItem,
    int i,
    UIParamContext ctx,
    PanInfo? panInfo,
  );
  void loadData(dynamic data);
}

class JsonToUi with WidgetUIHelper implements GenericToUi {
  JsonToUi({required this.state});

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
    print("data loaded");
  }

  WidgetTyped? browseJsonToWidget(
    String attrName,
    dynamic data, {
    required String path,
    required String pathData,
    required WidgetType parentType,
  }) {
    List<ConfigContainer>? layoutConfiguration =
        stateMgr.configLayout[replaceAllIndexes(path)];
    var rowTab = <WidgetTyped>[];

    UIParamContext ctx =
        UIParamContext(
            pathData: pathData,
            path: path,
            attrName: attrName,
            parentType: parentType,
            rowTab: rowTab,
          )
          ..data = data
          ..layoutConfiguration = layoutConfiguration;

    if (data is Map) {
      return _doObjectMap(ctx);
    } else if (data is List) {
      return _getObjectArray(ctx);
    } else {
      return getObjectInput(this, null, ctx);
    }
  }

  WidgetTyped? _getObjectArray(UIParamContext ctx) {
    var lw = <Widget>[];

    var p = replaceAllIndexes(ctx.path);

    var confLayoutArray = stateMgr.configArray[p];
    confLayoutArray ??= ConfigArrayContainer(name: p);
    ctx.layoutArray = confLayoutArray;

    Widget wid = getArrayOfForm(lw, ctx);

    var widgetTyped = WidgetTyped(
      height: -1,
      name: ctx.attrName,
      content: ctx.data,
      type: WidgetType.list,
      widget: Container(
        //key: ObjectKey(data),
        margin: EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue, width: 1),
        ),
        child: Column(children: lw),
      ),
    );

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

  WidgetContentArray getArrayOfForm(
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
        for (int i = 0; i < ctx.data.length; i++) {
          var row = browseJsonToWidget(
            'row $i',
            ctx.data[i],
            path: '$path[$i]',
            pathData: pathData,
            parentType: WidgetType.list,
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
          WidgetConfigInfo(json2ui: this, name: ctx.attrName),
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
          bool anyOfItem = infoTemplate.anyOf;

          Widget wid = getFormOfRow(anyOfItem, i, ctxRow, null);

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
          return getTemplateObject(cloneCtx, listContentBloc);
        },
        info:
            WidgetConfigInfo(json2ui: this, name: "choise items")
              ..inArrayValue = ctx.data
              ..setPathValue('$path[$i]')
              ..setPathData('$path[$i]'),
      );
    } else {
      var row = browseJsonToWidget(
        '$i',
        ctx.data,
        path: '$path[$i]',
        pathData: ctx.pathData,
        parentType: WidgetType.list,
      );
      if (row == null) {
        wid = SizedBox();
      } else {
        wid = row.widget;
      }
    }
    return wid;
  }

  // String _cleanPath(String path) {
  //   var path2 = path.replaceAll('\$\$__ref__>', '');
  //   path2 = path2.replaceAll('\$\$__anyof__>', '');
  //   return path2;
  // }

  WidgetTyped? _doObjectMap(UIParamContext ctx) {
    var data = ctx.data;
    if (data[cstType] != null && data[cstContent] != null) {
      // gestion des type array ou input ou any
      var listData = data[cstContent];

      if (data[cstType] == 'array' && modeTemplate) {
        stateMgr.stateTemplate[ctx.path] ??=
            StateContainerArray()..jsonTemplate = listData;
      } else if (data[cstType] == 'arrayAnyOf') {
        // print("arrayAnyOf");
      } else if (data[cstType] == 'objectAnyOf') {
        return _doObjectAnyOf(ctx, listData);
      }

      WidgetTyped? wid = browseJsonToWidget(
        path: ctx.path,
        pathData: ctx.pathData,
        ctx.attrName,
        listData,
        parentType: ctx.parentType,
      );

      return wid;
    }

    Widget wid = _getContentMap(ctx);

    return WidgetTyped(
      height: -1,
      name: ctx.attrName,
      content: data,
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

  WidgetContentForm _getContentMap(UIParamContext ctx) {
    List<WidgetTyped> listContentBlocForConfig = [];

    WidgetContentForm wid = WidgetContentForm(
      ctx: ctx,
      info:
          WidgetConfigInfo(name: ctx.attrName, json2ui: this)
            ..setPathValue(ctx.path)
            ..setPathData(ctx.pathData)
            ..onTapSetting = () async {
              if (await showSettingFormDialog(
                context!,
                ctx.path,
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
        var ctxClone = ctx.clone(aPathData: pathDataComp);

        return getTemplateObject(ctxClone, listContentBlocForConfig);
      },
    );

    if (modeTemplate) {
      wid.children(ctx.pathData);
    }
    return wid;
  }

  WidgetTyped _doObjectAnyOf(UIParamContext ctx, dynamic listTemplate) {
    if (modeTemplate) {
      var replaceAll = ctx.path.replaceAll("/$cstAnyChoice", '');
      stateMgr.stateTemplate[replaceAll] =
          StateContainerObjectAny()..jsonTemplate = listTemplate;
    }

    WidgetContentObjectAnyOf wid = _getWidgetObjectAnyOf(ctx, listTemplate);

    if (modeTemplate) {
      wid.children(ctx.pathData, null, null);
    }

    return WidgetTyped(
      height: -1,
      name: ctx.attrName,
      content: ctx.data,
      type: WidgetType.form,
      widget: wid,
    );
  }

  WidgetContentObjectAnyOf _getWidgetObjectAnyOf(
    UIParamContext ctx,
    dynamic listTemplateModel,
  ) {
    var wid = WidgetContentObjectAnyOf(
      //key: ObjectKey(listData),
      info:
          WidgetConfigInfo(name: ctx.attrName, json2ui: this)
            ..setPathValue(ctx.path.replaceAll("/$cstAnyChoice", ''))
            ..setPathData(ctx.pathData),
      children: (pathDataComp, data, panInfoChoised) {
        List<WidgetTyped> listContentBloc = [];
        if (data == null && modeTemplate) {
          //charge les templates
          List<Widget> ret = [];
          List listTemplate = (listTemplateModel as Map).values.toList();
          var pathTemplate = ctx.path.replaceAll("/$cstAnyChoice", '');
          for (var i = 0; i < listTemplate.length; i++) {
            var ctx2 = ctx.clone(
              aPath: '$pathTemplate[$i]',
              aPathData: pathDataComp,
            )..data = listTemplate[i];
            var r = getTemplateObject(ctx2, listContentBloc);
            ret.addAll(r);
          }
          return ret;
        } else if (data != null) {
          var ctx2 = ctx.clone(aPathData: pathDataComp);
          return getTemplateObject(ctx2, listContentBloc);
        } else {
          return [Text('Empty')];
        }
      },
    );
    return wid;
  }

  List<Widget> getTemplateObject(
    UIParamContext ctx,
    List<WidgetTyped> listContentBloc,
  ) {
    var lwt = <WidgetTyped>[];

    if (modeTemplate) {
      stateMgr.stateTemplate[ctx.path] ??=
          StateContainerObject()..jsonTemplate = ctx.data;
    }

    ctx.data.forEach((key, value) {
      if (key == cstProp) {
        // gestion prop du formulaire
      } else {
        var w = browseJsonToWidget(
          key,
          value,
          path: '${ctx.path}/$key',
          pathData: ctx.pathData,
          parentType: WidgetType.form,
        );
        if (w != null) {
          lwt.add(w);
        }
      }
    });

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

        lwt[i].layout = layout;
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
          addInput(rowInput, lwt, i);
        } else {
          lw.add(Row(spacing: margeHoriz, children: rowInput));
          rowInput = [];
          addInput(rowInput, lwt, i);
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

  void addInput(List<Widget> rowInput, List<WidgetTyped> lwt, int i) {
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
          //key: GlobalKey(),
          listTab: tabs,
          listTabCont: contents,
          heightTab: 30,
          heightContent: true,
        ),
      );
      rowTab.clear();
    }
  }

  // Widget getExpansible(
  //   List<Widget> headers,
  //   Widget child, {
  //   required Color color,
  // }) {
  //   final controller = ExpansibleController();
  //   controller.expand();

  //   return Expansible(
  //     //key: GlobalKey(),
  //     controller: controller,
  //     headerBuilder:
  //         (_, animation) => GestureDetector(
  //           onTap: () {
  //             controller.isExpanded
  //                 ? controller.collapse()
  //                 : controller.expand();
  //           },
  //           child: Container(
  //             //padding: EdgeInsets.symmetric(horizontal: 10),
  //             //width: double.infinity,
  //             decoration: BoxDecoration(
  //               color: color,
  //               //border: Border.all(color: Colors.white54, width: 1),
  //             ),
  //             child: Row(
  //               spacing: 10,
  //               children: [
  //                 Icon(Icons.arrow_circle_down_sharp),
  //                 ...headers,
  //                 //Spacer(),
  //               ],
  //             ),
  //           ),
  //         ),
  //     bodyBuilder:
  //         (_, animation) => FadeTransition(opacity: animation, child: child),
  //     expansibleBuilder:
  //         (_, header, body, _) => Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           mainAxisAlignment: MainAxisAlignment.start,
  //           children: [header, body],
  //         ),
  //   );
  // }

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
            TextButton(child: const Text('change layout'), onPressed: () {}),
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
}
