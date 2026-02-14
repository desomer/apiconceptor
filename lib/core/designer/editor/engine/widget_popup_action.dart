import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_drag_utils.dart';
import 'package:jsonschema/core/designer/editor/engine/widget_selectable.dart';
import 'package:jsonschema/core/designer/editor/engine/overlay_action.dart';

class WidgetPopupAction extends StatefulWidget {
  const WidgetPopupAction({super.key});

  @override
  State<WidgetPopupAction> createState() => WidgetPopupActionState();
}

class WidgetPopupActionState extends State<WidgetPopupAction> {
  CWRec? event;

  void open(CWRec e) {
    setState(() {
      event = e;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (event != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _showActions(event!, context);
        event = null;
      });
    }
    return Container();
  }

  void _showActions(CWRec e, BuildContext context2) {
    //double width = MediaQuery.of(context).size.width;

    double t = e.top;
    double? l = e.left;
    double? r;

    showDialog(
      barrierColor: Colors.transparent,
      context: context2,
      builder: (BuildContext context) {
        List<Widget> listActionWidget = [];
        //          var app = CWApplication.of();

        listActionWidget.add(
          getMenu('Change populate...', () {
            // openPopulateDialog(context);
          }),
        );
        listActionWidget.add(
          getMenu('Wrap with...', () {
            openDialogSurround(context);
          }),
        );
        listActionWidget.add(
          SizedBox(
            width: 200,
            child: Divider(height: 1, thickness: 1, color: Colors.white24),
          ),
        );
        listActionWidget.add(
          getMenu('Copy', () {
            Navigator.pop(context);
          }),
        );

        listActionWidget.add(
          getMenu('Paste', () {
            // var widgetSelector = CoreDesigner.of().widgetSelector;
            // var w = widgetSelector.getSelectedWidget();
            // var slot = widgetSelector.getSelectedSlotContext();
            // if (w == null) {
            //   final CoreDataCtx ctx = CoreDataCtx();
            //   ctx.browseHandler = WidgetCopyEventHandler()..setSlot(slot!.xid);
            //   app.loaderCopy?.pagesEntity
            //       .browse(app.loaderDesigner.collectionWidget, ctx);
            //   var designView = CoreDesigner.of().designView;
            //   app.prepareReBuild();
            //   app.repaintAll();
            //   designView.selectRoot();
            // }
            Navigator.pop(context);
          }),
        );
        listActionWidget.add(
          SizedBox(
            width: 200,
            child: Divider(height: 1, thickness: 1, color: Colors.white24),
          ),
        );
        listActionWidget.add(
          getMenu('Delete...', () {
            CwFactoryAction(
              ctx: currentSelectorManager.lastSelectedCtx!,
            ).delete();

            Navigator.pop(context);
          }),
        );

        return Stack(
          children: [
            Positioned(
              left: l,
              top: t,
              right: r,
              child: Material(
                elevation: 10,
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10.0),
                child: Column(children: listActionWidget),
              ),
            ),
          ],
        );
      },
    );
  }

  SizedBox getMenu(String label, GestureTapCallback? call) {
    return SizedBox(
      height: 40,
      width: 200,
      child: InkWell(
        onTap: call,
        child: Padding(padding: EdgeInsets.all(10), child: Text(label)),
      ),
    );
  }

  void openDialogSurround(BuildContext context2) {
    showDialog(
      barrierColor: Colors.transparent,
      context: context2,
      builder: (BuildContext context) {
        return Material(
          elevation: 10,
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10.0),
          child: AlertDialog(
            backgroundColor: Colors.black87,
            content: IntrinsicHeight(
              child: Column(
                children: [
                  getWrapItem(context, context2, 'Tab', 'bar', 'tabview_0', {
                    'bottomView': true,
                  }, Icons.tab),
                  getWrapItem(
                    context,
                    context2,
                    'Row',
                    'CWRow',
                    'Cont0',
                    {},
                    Icons.view_week,
                  ),
                  getWrapItem(
                    context,
                    context2,
                    'Column',
                    'CWColumn',
                    'Cont0',
                    {},
                    Icons.table_rows_rounded,
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  SizedBox getWrapItem(
    BuildContext context,
    BuildContext context2,
    String text,
    String type,
    String slot,
    Map<String, dynamic> props,
    IconData icon,
  ) {
    return SizedBox(
      height: 40,
      width: 200,
      child: InkWell(
        onTap: () {
          var ctx = currentSelectorManager.lastSelectedCtx!;

          var drop = DropCtx(
            parentData: ctx.parentCtx?.dataWidget,
            childData: {cwImplement: type, cwProps: props},
            componentId: type,
          );

          // appel de la config de drop si existante
          ctx.aFactory.builderDragConfig[type]?.call(ctx, drop);

          var actMgr = CwFactoryAction(ctx: ctx);
          actMgr.surround(ctx.slotId, slot, drop.childData!);
          SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
            ctx.parentCtx!.repaint();
            ctx.selectParentOnDesigner();
          });

          Navigator.pop(context);
          Navigator.pop(context2);
        },
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Padding(padding: const EdgeInsets.all(10), child: Text(text)),
          ],
        ),
      ),
    );
  }
}
