import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jsonschema/core/api/call_ds_manager.dart';
import 'package:jsonschema/core/designer/component/pages_datasource.dart';
import 'package:jsonschema/core/designer/component/pages_viewer.dart';
import 'package:jsonschema/core/designer/core/widget_event_bus.dart';
import 'package:jsonschema/core/designer/core/widget_selectable.dart';
import 'package:jsonschema/core/designer/cw_factory.dart';
import 'package:jsonschema/core/designer/cw_factory_bloc.dart';
import 'package:jsonschema/core/designer/cw_widget.dart';

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
  final CwWidgetCtx source;
  DragComponentCtx(this.source);

  @override
  void doDropOn(WidgetSelectableState state, BuildContext context) {
    var ctxOn = state.widget.slotConfig!.ctx;
    if (source == ctxOn ||
        source.parentCtx == ctxOn || // prevent drop on own parent
        source.dataWidget == null ||
        source.dataWidget?[cwType] == null) {
      return;
    }

    // var drop = DropCtx(
    //   parentData: ctxOn.parentCtx?.dataWidget,
    //   childData: source.dataWidget,
    //   source: source,
    // );

    source.parentCtx!.dataWidget![cwSlots]?.remove(source.id);

    ctxOn.aFactory.addInSlot(
      ctxOn.parentCtx!.dataWidget!,
      ctxOn.id,
      source.dataWidget!,
    );
    // ignore: invalid_use_of_protected_member
    ctxOn.parentCtx!.state?.setState(() {});
    // ignore: invalid_use_of_protected_member
    source.parentCtx!.state?.setState(() {});

    ctxOn.selectOnDesigner();

    // state.widget.slotConfig!.ctx.aFactory.builderDragConfig[idComponent]?.call(
    //   ctx,
    //   drop,
    // );
  }
}

class DragNewComponentCtx extends DragCtx {
  final String idComponent;
  final Map config;
  DragNewComponentCtx({required this.idComponent, required this.config});

  @override
  void doDropOn(WidgetSelectableState state, BuildContext context) {
    var ctx = state.widget.slotConfig!.ctx;
    var param = <String, dynamic>{
      cwType: idComponent,
      cwProps: <String, dynamic>{},
    };

    if (config['type'] == 'datasource') {
      showConfigDataSrc(ctx, idComponent, context, config).then((changed) {
        if (changed != null) {
          param = changed;
          doActionDrop(ctx, param, state);
        }
      });
    } else if (config['type'] == 'repository') {
      var dsId = config['ds'];
      showConfigDataSrc(ctx, dsId, context, config).then((changed) {
        if (changed != null) {
          param = changed;
          doActionDrop(ctx, param, state);
        }
      });
    } else {
      doActionDrop(ctx, param, state);
    }
  }

  void doActionDrop(
    CwWidgetCtx ctx,
    Map<String, dynamic> param,
    WidgetSelectableState state,
  ) {
    var drop = DropCtx(
      parentData: ctx.parentCtx?.dataWidget,
      childData: param,
      componentId: idComponent,
    );

    // appel de la config de drop si existante
    state.widget.slotConfig!.ctx.aFactory.builderDragConfig[idComponent]?.call(
      ctx,
      drop,
    );

    // appel de onDrop des slot parent
    drop.setConfigOnly(ctx);

    if (ctx.slotProps?.onDrop != null) {
      ctx.slotProps!.onDrop!(ctx, drop);
    }
    ctx.aFactory.addInSlot(ctx.parentCtx!.dataWidget!, ctx.id, drop.childData!);

    drop.afterAdded?.call();

    // ignore: invalid_use_of_protected_member
    ctx.parentCtx!.state?.setState(() {});

    ctx.selectOnDesigner();
  }

  Future<Map<String, dynamic>?> showConfigDataSrc(
    CwWidgetCtx ctx,
    String dataSourceId,
    BuildContext bctx,
    Map config,
  ) async {
    CallerDatasource ds = CallerDatasource();
    await ds.loadDs(dataSourceId, null);

    if (ds.modelHttp200 == null) {
      print('No response model for 200');
    }

    Map<String, dynamic>? ret;

    await showDialog<void>(
      context: designerKey.currentContext!,
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
                Navigator.of(context).pop();
                emitLater(CDDesignEvent.reselect, null, multiple: true);
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
      color: Colors.black45,
      child: imageCmp ?? const Text('vide'),
    );
  }
}
