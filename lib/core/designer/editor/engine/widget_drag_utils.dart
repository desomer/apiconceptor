import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jsonschema/core/api/call_ds_manager.dart';
import 'package:jsonschema/core/designer/editor/engine/behavior_manager.dart';
import 'package:jsonschema/core/designer/editor/engine/overlay_action.dart';
import 'package:jsonschema/core/designer/editor/engine/undo_manager.dart';
import 'package:jsonschema/core/designer/editor/view/pages_datasource.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_event_bus.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_selectable.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/core/cw_factory_bloc.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';
import 'package:shortid/shortid.dart';

class DropCtx {
  final Map<String, dynamic>? parentData;
  Map<String, dynamic>? childData;
  final String? componentId;
  final CwWidgetCtx? source;
  // demande juste la config sans ajout effectif pour typer par rapport au container parent
  bool forConfigOnly = false;

  Function? afterAdded;

  DropCtx({
    required this.parentData,
    required this.childData,
    this.componentId,
    this.source,
  });

  void setConfigOnly(CwWidgetCtx ctx) {
    CwWidgetCtx? ctxP = ctx;
    while (ctxP != null) {
      forConfigOnly = true;
      ctxP.slotProps?.onDrop?.call(ctxP, this);
      if (forConfigOnly == false) {
        break;
      }
      ctxP = ctxP.parentCtx;
    }
    forConfigOnly = false;
  }
}

class DragCtx {
  void doDropOn(WidgetSelectableState state, BuildContext context) {}
}

class DragComponentCtx extends DragCtx {
  final CwWidgetCtx sourceCtx;
  DragComponentCtx(this.sourceCtx);

  @override
  void doDropOn(WidgetSelectableState state, BuildContext context) {
    var ctxOn = state.widget.slotConfig!.ctx;
    if (sourceCtx == ctxOn ||
        sourceCtx.parentCtx == ctxOn || // prevent drop on own parent
        sourceCtx.dataWidget == null ||
        sourceCtx.dataWidget?[cwImplement] == null) {
      return;
    }

    globalUndoManager.execute(
      UndoAction(
        doAction: () {
          onDragAndDopImpl(ctxOn, sourceCtx);
        },
        undoAction: () {
          onDragAndDopImpl(sourceCtx, ctxOn);
        },
      ),
    );
  }

  void onDragAndDopImpl(CwWidgetCtx ctxOn, CwWidgetCtx ctxSource) {
    ctxSource.parentCtx!.dataWidget![cwSlots]?.remove(ctxSource.slotId);
    ctxOn.aFactory.addInSlot(
      ctxOn.parentCtx!.dataWidget!,
      ctxOn.slotId,
      ctxSource.dataWidget!,
    );
    ctxOn.parentCtx!.repaint();
    ctxSource.parentCtx!.repaint();

    ctxOn.selectOnDesigner();
  }
}

class DragNewComponentCtx extends DragCtx {
  String idComponent;
  final Map config;
  DragNewComponentCtx({required this.idComponent, required this.config});

  @override
  void doDropOn(WidgetSelectableState state, BuildContext context) {
    var ctx = state.widget.slotConfig!.ctx;
    var param = <String, dynamic>{
      cwImplement: idComponent,
      cwProps: <String, dynamic>{},
      cwBehaviors: <Map<String, dynamic>>[],
    };

    if (config[cwType] == 'datasource') {
      showDataSource(ctx, idComponent, context, config).then((changed) {
        if (changed != null) {
          param = changed;
          doActionDropNewCmp(ctx, param);
        }
      });
    } else if (config[cwType] == 'repository') {
      var dsId = config['ds'];
      showDataSource(ctx, dsId, context, config).then((changed) {
        if (changed != null) {
          param = changed;
          doActionDropNewCmp(ctx, param);
        }
      });
    } else if (config['type'] == 'route') {
      var dragRouteData = config['data'];
      var pageId = dragRouteData[cwRouteId];

      if (pageId == null) {
        //creation de la route dans le factory si besoin
        doActionDropNewPage(ctx, dragRouteData);
      }

      BehaviorManager.addBehavior(
        param,
        type: 'navigate',
        data: {
          'routeId': dragRouteData[cwRouteId],
          'routeUrl': dragRouteData[cwRoutePath],
        },
      );

      param[cwProps]['label'] = dragRouteData[cwRouteName];
      doActionDropNewCmp(ctx, param);
    } else {
      doActionDropNewCmp(ctx, param);
    }
  }

  void doActionDropNewPage(CwWidgetCtx ctx, dragRouteData) {
    String pageId = shortid.generate();
    var url = '/new_page_$pageId';
    ctx.aFactory.appData[cwApp]![cwSlots]![pageId] = <String, dynamic>{
      cwImplement: 'page',
      cwRouteId: pageId,
      cwRouteName: 'New Page',
      cwRoutePath: url,
      cwSlotId: '',
    };
    var routeData = ctx.aFactory.appData[cwApp]![cwSlots]![pageId];

    ctx.aFactory.initEmptyPageContent(routeData);

    dragRouteData[cwRouteId] = pageId;
    dragRouteData[cwRouteName] = 'New Page';
    dragRouteData[cwRoutePath] = '/new_page_$pageId';
    //dataRoute['icon'] = Icons.route;
    dragRouteData['status'] = 'R';
    int idcache = dragRouteData['intCache'] ?? 0;
    dragRouteData['intCache'] = idcache + 1;
    config[cwRoutePath] = url;
    // ignore: invalid_use_of_protected_member
    ctx.aFactory.keyPagesViewer.currentState?.setState(() {});

    int i = ctx.aFactory.listSlotsPageInRouter.length;
    ctx.aFactory.listSlotsPageInRouter.add(routeData);
    ctx.aFactory.mapPath2PathSlot[config[cwRoutePath]] = '/temp/page_slot_$i';
  }

  void doActionDropNewCmp(CwWidgetCtx ctx, Map<String, dynamic> childData) {
    globalUndoManager.execute(
      UndoAction(
        doAction: () {
          doActionDropNewCmpImpl(ctx, childData);
        },
        undoAction: () {
          CwFactoryAction(ctx: ctx).delete();
        },
      ),
    );
  }

  void doActionDropNewCmpImpl(CwWidgetCtx ctx, Map<String, dynamic> childData) {
    if (childData[cwSlots]?.length == 1) {
      bool notContainerIfSingle =
          ctx.isParentOfType('container', layout: 'form') ||
          ctx.slotProps?.id == 'rdrawer' ||
          ctx.slotProps?.type == 'cell' ||
          ctx.slotProps?.type == 'header';

      if (notContainerIfSingle) {
        childData = childData[cwSlots]['cell_0'];
        idComponent = childData[cwImplement];
      }
    }

    var drop = DropCtx(
      parentData: ctx.parentCtx?.dataWidget,
      childData: childData,
      componentId: idComponent,
    );

    // appel de la config de drop si existante
    ctx.aFactory.builderDragConfig[idComponent]?.call(ctx, drop);

    // appel de onDrop des slot parent
    drop.setConfigOnly(ctx);

    if (ctx.slotProps?.onDrop != null) {
      ctx.slotProps!.onDrop!(ctx, drop);
    }
    ctx.aFactory.addInSlot(
      ctx.parentCtx!.dataWidget!,
      ctx.slotId,
      drop.childData!,
    );

    drop.afterAdded?.call();
    ctx.repaint();
    ctx.parentCtx!.repaint();
    ctx.selectOnDesigner();
  }

  Future<Map<String, dynamic>?> showDataSource(
    CwWidgetCtx ctx,
    String dataSourceId,
    BuildContext bctx,
    Map config,
  ) async {
    BuildContext context2 = ctx.aFactory.designerKey.currentContext!;
    late BuildContext ctx2;

    showDialog(
      context: context2,
      barrierDismissible: false,
      builder: (ctx) {
        ctx2 = ctx;
        return const Center(child: CircularProgressIndicator());
      },
    );

    CallerDatasource ds = CallerDatasource();
    await ds.loadDs(dataSourceId, null);
    ds.config.aFactory = ctx.aFactory;
    if (config['type'] == 'repository') {
      ds.config.repositoryId = config['id'];
      ds.initComputedProps();
    }

    if (ds.modelHttp200 == null) {
      print('No response model for 200');
    }

    Map<String, dynamic>? ret;

    // Fermer le loader
    // ignore: use_build_context_synchronously
    Navigator.of(ctx2).pop();

    await showDialog<void>(
      // ignore: use_build_context_synchronously
      context: context2,
      barrierDismissible: true, // user must tap button!
      builder: (BuildContext context) {
        Size size = MediaQuery.of(bctx).size;
        double width = size.width * 0.9;
        double height = size.height * 0.8;
        return AlertDialog(
          content: SizedBox(
            width: width,
            height: height,
            child: PagesDatasource(dsCaller: ds),
          ),
          actions: [
            TextButton(
              child: const Text('cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('add data source'),
              onPressed: () async {
                ret = await CwFactoryBloc().doDataSrcBloc(config, ds, ctx);
                // ignore: use_build_context_synchronously
                emitLater(CDDesignEvent.reselect, null, multiple: true);
                // ignore: use_build_context_synchronously
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );

    return ret;
  }
}

//-----------------------------------------------------------

class CWSlotImage extends StatefulWidget {
  const CWSlotImage({super.key, this.selectableState});

  final WidgetSelectableState? selectableState;

  @override
  CWSlotImageState createState() => CWSlotImageState();
}

class CWSlotImageState extends State<CWSlotImage> {
  static Widget? imageCmp;
  static String? path;

  @override
  Widget build(BuildContext context) {
    if (imageCmp == null || path != widget.selectableState?.widget.getPath()) {
      SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
        widget.selectableState?.capturePng().then((image) {
          SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
            if (mounted) {
              // ignore: invalid_use_of_protected_member
              setState(() {
                imageCmp = image;
                path = widget.selectableState?.widget.getPath();
              });
            }
          });
        });
      });
    }

    return Container(
      color: Colors.orangeAccent.withAlpha(100),
      child: imageCmp ?? const Text('vide'),
    );
  }
}
