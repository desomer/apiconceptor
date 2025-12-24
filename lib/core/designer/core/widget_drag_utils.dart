import 'package:flutter/material.dart';
import 'package:jsonschema/core/api/call_ds_manager.dart';
import 'package:jsonschema/core/designer/component/pages_datasource.dart';
import 'package:jsonschema/core/designer/component/pages_viewer.dart';
import 'package:jsonschema/core/designer/core/widget_selectable.dart';
import 'package:jsonschema/core/designer/cw_factory.dart';
import 'package:jsonschema/core/designer/cw_widget.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/content/widget/widget_content_helper.dart';
import 'package:jsonschema/pages/router_config.dart';

class DropCtx {
  final Map<String, dynamic>? parentData;
  Map<String, dynamic>? childData;
  final String? componentId;
  final CwWidgetCtx? source;
  bool forConfigOnly =
      false; // demande juste la config sans ajout effectif pour typer par rapport au container parent

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

    ctxOn.selectParent();

    // state.widget.slotConfig!.ctx.aFactory.builderDragConfig[idComponent]?.call(
    //   ctx,
    //   drop,
    // );
  }
}

class DragNewComponentCtx extends DragCtx with NameMixin {
  final String idComponent;
  DragNewComponentCtx({required this.idComponent});

  @override
  void doDropOn(WidgetSelectableState state, BuildContext context) {
    var ctx = state.widget.slotConfig!.ctx;
    var param = <String, dynamic>{
      cwType: idComponent,
      cwProps: <String, dynamic>{},
    };

    if (idComponent.startsWith('ds_')) {
      showConfigDataSrc(ctx, idComponent, context).then((changed) {
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
  }

  Future<Map<String, dynamic>?> showConfigDataSrc(
    CwWidgetCtx ctx,
    String idComponent,
    BuildContext bctx,
  ) async {
    CallerDatasource ds = CallerDatasource();
    var datasourceId = idComponent.substring(3);
    await ds.loadConfig('all', datasourceId, null);
    var apiCallInfo = ds.helper!.apiCallInfo;

    apiCallInfo.currentAPIRequest ??= await GoTo().getApiRequestModel(
      apiCallInfo,
      apiCallInfo.namespace,
      apiCallInfo.attrApi.masterID!,
      withDelay: false,
    );

    apiCallInfo.currentAPIResponse ??= await GoTo().getApiResponseModel(
      apiCallInfo,
      apiCallInfo.namespace,
      apiCallInfo.attrApi.masterID!,
      withDelay: false,
    );

    ds.modelHttp200 = await apiCallInfo.currentAPIResponse!.getSubSchema(
      subNode: 200,
    );

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
              onPressed: () {
                Navigator.of(context).pop();

                var list = ds.selectionConfig;

                ret = {
                  cwType: 'container',
                  cwProps: <String, dynamic>{
                    'style': 'column',
                    'layout': 'flow',
                    'nbchild': list.length,
                  },
                };
                for (var i = 0; i < list.length; i++) {
                  ModelSchema? model;

                  if (list[i]['src'] == 'Criteria') {
                    model = ds.helper!.apiCallInfo.currentAPIRequest!;
                  } else if (list[i]['src'] == 'Data') {
                    model = ds.modelHttp200!;
                  }

                  var info = model!.nodeByMasterId[list[i]['id']]!.info;

                  ctx.aFactory.addInSlot(ret!, 'cell_$i', {
                    cwType: 'input',
                    cwProps: <String, dynamic>{'label': camelCaseToWords(info.name)},
                  });
                }
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
  const CWSlotImage({super.key});

  @override
  CWSlotImageState createState() => CWSlotImageState();
}

class CWSlotImageState extends State<CWSlotImage> {
  static Widget? imageCmp;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black45,
      child: imageCmp ?? const Text('vide'),
    );
  }
}
