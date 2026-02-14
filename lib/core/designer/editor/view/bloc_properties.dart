import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/core/cw_factory_style.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/editor/engine/behavior_manager.dart';
import 'package:jsonschema/core/designer/editor/view/helper/widget_hover.dart';
import 'package:jsonschema/main.dart';

class WidgetFactoryProperty {
  final WidgetFactory cwFactory;

  List<Widget> listPropsEditor = [];

  List<Widget> listStyleEditor = [];
  List<Widget> listStyleSelectorEditor = [];
  CwWidgetCtx? ctxStyleSelected;

  List<Widget> listBehaviorEditor = [];

  final cwFactoryStyle = CWFactoryStyle();

  WidgetFactoryProperty({required this.cwFactory});

  void displayProps(CwWidgetCtx ctx) {
    listPropsEditor.clear();
    listStyleSelectorEditor.clear();

    var config = ctx.getConfig();

    CwWidgetCtx? aCtx = ctx;
    ctxStyleSelected = ctx;
    //int level = 0;
    while (aCtx != null) {
      bool isIterable = _addAllWidgetProps(
        aCtx,
        ctx == aCtx ? config : aCtx.getConfig(),
      );
      if (isIterable && listPropsEditor.length > 1) {
        _addIterrableBox(aCtx, ctx);
      }
      aCtx = aCtx.parentCtx;
    }

    if (cwFactory.keyPropsViewer.currentState?.mounted == true) {
      // ignore: invalid_use_of_protected_member
      cwFactory.keyPropsViewer.currentState?.setState(
        () {},
      ); // force refresh props viewer
    }

    // afficher les styles
    if (cwFactory.keyStyleSelectorViewer.currentState?.mounted == true) {
      // ignore: invalid_use_of_protected_member
      cwFactory.keyStyleSelectorViewer.currentState?.setState(
        () {},
      ); // force refresh props viewer
    }

    _doDisplayTabStyle(ctx, ctx);

    if (ctx.dataWidget != null) {
      _initBehavior(ctx);
    }
  }

  void _initStyle(CwWidgetCtx ctx) {
    // afficher les styles
    listStyleEditor.clear();
    var config = ctx.getConfig();

    List<Widget> aListStyleEditor = [];

    for (CwWidgetProperties prop in config?.style ?? const []) {
      aListStyleEditor.add(prop.input!);
    }

    var initAlignment = cwFactoryStyle.initAlignment(ctx);
    var initPadding = cwFactoryStyle.initPadding(ctx);
    var initBorder = cwFactoryStyle.initBorder(ctx);
    var initBackground = cwFactoryStyle.initBackground(ctx);
    var initMargin = cwFactoryStyle.initMargin(ctx);
    var initText = cwFactoryStyle.initText(ctx);

    _addAllStyleWidget(aListStyleEditor, initAlignment, 'Alignment');
    _addAllStyleWidget(aListStyleEditor, initPadding, 'Margin');
    _addAllStyleWidget(aListStyleEditor, initBorder, 'Border & Elevation');
    _addAllStyleWidget(aListStyleEditor, initBackground, 'Background');
    _addAllStyleWidget(aListStyleEditor, initMargin, 'Padding');
    _addAllStyleWidget(aListStyleEditor, initText, 'Text');

    listStyleEditor.add(
      WidgetHoverCmp(
        path: ctx,
        overMgr: HoverCmpManagerImpl(),
        child: Column(children: aListStyleEditor),
      ),
    );

    if (cwFactory.keyStyleViewer.currentState?.mounted == true) {
      // ignore: invalid_use_of_protected_member
      cwFactory.keyStyleViewer.currentState?.setState(
        () {},
      ); // force refresh props viewer
    }
  }

  void _addIterrableBox(CwWidgetCtx aCtx, CwWidgetCtx ctx) {
    var aIterable = listPropsEditor.removeLast();

    addOtherSlots(aCtx, ctx, (CwWidgetCtx rowCtx) {
      _addAllWidgetProps(rowCtx, rowCtx.getConfig());
    });

    var header = Container(
      margin: EdgeInsets.fromLTRB(10, 5, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: ThemeHolder.theme.colorScheme.primary,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(5),
            ),
            padding: EdgeInsets.all(1),
            child: Column(children: [...listPropsEditor]),
          ),
          Container(
            color: ThemeHolder.theme.colorScheme.primary,
            child: Icon(Icons.rotate_right, size: 17),
          ),
        ],
      ),
    );
    listPropsEditor.clear();
    listPropsEditor.add(header);
    listPropsEditor.add(aIterable);
  }

  void addOtherSlots(CwWidgetCtx aCtx, CwWidgetCtx ctx, Function onAddSlot) {
    if (aCtx.isType(['table']) && !ctx.isType(['row'])) {
      if (ctx.slotProps?.type == 'header') {
        aCtx.dataWidget![cwSlots]?['h-row'] ??= {
          cwImplement: 'row',
          cwProps: <String, dynamic>{},
        };
        CwWidgetCtx? rowHeaderCtx = aCtx.getSlotCtx('h-row', virtual: true);
        rowHeaderCtx.selectorCtxIfDesign?.inSlotName = 'header row';
        onAddSlot(rowHeaderCtx);
      } else {
        aCtx.dataWidget![cwSlots]?['d-row'] ??= {
          cwImplement: 'row',
          cwProps: <String, dynamic>{},
        };
        CwWidgetCtx? rowCtx = aCtx.getSlotCtx('d-row', virtual: true);
        rowCtx.selectorCtxIfDesign?.inSlotName = 'data row';
        onAddSlot(rowCtx);
      }
    }
  }

  void _addAllStyleWidget(
    List<Widget> aListStyleEditor,
    List<CwWidgetProperties> styles,
    String name,
  ) {
    if (styles.isNotEmpty) {
      aListStyleEditor.add(_getHeaderStyle(name));
      for (CwWidgetProperties prop in styles) {
        aListStyleEditor.add(prop.input!);
      }
    }
  }

  Widget _getSelectorStyle(
    CwWidgetCtx ctx,
    CwWidgetCtx aCtx2Display,
    int level,
  ) {
    int nbStyles = 0;
    List<CwWidgetProperties> allStyleAvalable = [];
    allStyleAvalable.addAll(aCtx2Display.getConfig()?.style ?? const []);
    cwFactoryStyle.withEditor = false;
    allStyleAvalable.addAll(cwFactoryStyle.initAlignment(aCtx2Display));
    allStyleAvalable.addAll(cwFactoryStyle.initPadding(aCtx2Display));
    allStyleAvalable.addAll(cwFactoryStyle.initBorder(aCtx2Display));
    allStyleAvalable.addAll(cwFactoryStyle.initBackground(aCtx2Display));
    allStyleAvalable.addAll(cwFactoryStyle.initMargin(aCtx2Display));
    allStyleAvalable.addAll(cwFactoryStyle.initText(aCtx2Display));
    cwFactoryStyle.withEditor = true;

    for (CwWidgetProperties prop in allStyleAvalable) {
      if (prop.json?[prop.id] != null) {
        nbStyles++;
      }
    }

    return WidgetHoverCmp(
      path: aCtx2Display,
      overMgr: HoverCmpManagerImpl(),
      child: InkWell(
        onTap: () {
          ctxStyleSelected = aCtx2Display;
          _doDisplayTabStyle(ctx, aCtx2Display);
        },
        child: Container(
          height: 25,
          margin: EdgeInsets.fromLTRB(0, 0, 10.0 * level, 2),
          width: double.infinity,
          //padding: const EdgeInsets.all(3),
          color:
              ctxStyleSelected == aCtx2Display
                  ? ThemeHolder.theme.colorScheme.primaryContainer
                  : ThemeHolder.theme.colorScheme.secondaryContainer,
          child: Row(
            children: [
              nbStyles == 0
                  ? const SizedBox.shrink()
                  : Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      shape: BoxShape.rectangle,
                    ),
                    child: Text(
                      '$nbStyles',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        // fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              Expanded(
                child: Center(
                  child: Text(
                    '${aCtx2Display.getData()?[cwImplement] ?? 'Empty'} [${aCtx2Display.selectorCtx.inSlotName}]',
                    style: TextStyle(
                      color:
                          ctxStyleSelected == aCtx2Display
                              ? Colors.white
                              : Colors.white60,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _doDisplayTabStyle(CwWidgetCtx ctx, CwWidgetCtx aCtx2Display) {
    int level = 0;
    CwWidgetCtx? aCtx = ctx;
    listStyleSelectorEditor.clear();
    while (aCtx != null) {
      addOtherSlots(aCtx, ctx, (CwWidgetCtx rowCtx) {
        listStyleSelectorEditor.insert(
          0,
          _getSelectorStyle(ctx, rowCtx, level),
        );
      });
      listStyleSelectorEditor.insert(0, _getSelectorStyle(ctx, aCtx, level));
      aCtx = aCtx.parentCtx;
      level++;
    }
    // ignore: invalid_use_of_protected_member
    cwFactory.keyStyleSelectorViewer.currentState?.setState(() {});
    _initStyle(aCtx2Display);
  }

  Widget _getHeaderStyle(String name) {
    return Container(
      margin: EdgeInsets.fromLTRB(0, 0, 0, 5),
      width: double.infinity,
      padding: const EdgeInsets.all(3),
      color: ThemeHolder.theme.colorScheme.secondaryContainer,
      child: Center(
        child: Text(
          name,
          style: TextStyle(color: Colors.white60, fontSize: 14),
        ),
      ),
    );
  }

  bool _addAllWidgetProps(CwWidgetCtx aCtx, CwWidgetConfig? config) {
    List<Widget> listPropsWidget = [];
    var name =
        '${aCtx.getData()?[cwImplement] ?? 'Empty'} [${aCtx.selectorCtx.inSlotName}]';

    listPropsWidget.add(_getHeaderProps(name, aCtx));

    for (CwWidgetProperties prop in config?.properties ?? const []) {
      listPropsWidget.add(prop.input!);
    }

    if (aCtx.slotProps?.slotConfig != null) {
      // le config du slot
      config = aCtx.slotProps!.slotConfig!(aCtx.cloneForSlot());

      for (CwWidgetProperties prop in config.properties) {
        listPropsWidget.add(prop.input!);
      }
    }

    listPropsEditor.add(
      WidgetHoverCmp(
        path: aCtx,
        overMgr: HoverCmpManagerImpl(),
        child: Column(children: listPropsWidget),
      ),
    );

    return aCtx.isType(['list', 'table']);
  }

  Widget _getHeaderProps(String name, CwWidgetCtx aCtx) {
    return GestureDetector(
      onTap: () {
        aCtx.selectOnDesigner();
      },
      child: Container(
        margin: EdgeInsets.fromLTRB(0, 0, 0, 5),
        width: double.infinity,
        padding: const EdgeInsets.all(3),
        color: ThemeHolder.theme.colorScheme.secondaryContainer,
        child: Row(
          children: [
            Expanded(
              child: Center(
                child: Text(
                  name,
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                aCtx.aFactory.controllerTabProps?.animateTo(1);
                aCtx.selectOnDesigner();
              },
              icon: Icon(Icons.style, size: 17),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }

  void _initBehavior(CwWidgetCtx ctx) {
    listBehaviorEditor.clear();

    BehaviorManager.getBehaviors(ctx.dataWidget!).forEach((behavior) {
      var desc = behavior.getWidgetDescription(ctx);

      listBehaviorEditor.add(
        Container(
          margin: EdgeInsets.fromLTRB(5, 0, 5, 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: ThemeHolder.theme.colorScheme.primaryContainer,
            border: Border.all(
              color: ThemeHolder.theme.colorScheme.primary,
              width: 1,
            ),
          ),
          width: double.infinity,
          padding: const EdgeInsets.all(3),
          child: desc,
        ),
      );
    });
    listBehaviorEditor.add(ElevatedButton.icon(
      onPressed: () {
        //cwFactory.keyBehaviorEditor.currentState?.openAddBehaviorDialog(ctx);
      },
      icon: const Icon(Icons.add),
      label: const Text('Add Behavior'),
    ));


    if (cwFactory.keyBehaviorViewer.currentState?.mounted == true) {
      // ignore: invalid_use_of_protected_member
      cwFactory.keyBehaviorViewer.currentState?.setState(
        () {},
      ); // force refresh props viewer
    }
  }
}
