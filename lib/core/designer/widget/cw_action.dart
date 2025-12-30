import 'package:flutter/material.dart';
import 'package:flutter_iconpicker/flutter_iconpicker.dart';
import 'package:jsonschema/core/designer/component/helper/helper_editor.dart';
import 'package:jsonschema/core/designer/cw_factory.dart';
import 'package:jsonschema/core/designer/cw_repository.dart';
import 'package:jsonschema/core/designer/cw_widget.dart';

class CwAction extends CwWidget {
  const CwAction({super.key, required super.ctx});

  @override
  State<CwAction> createState() => _CwInputState();

  static void initFactory(WidgetFactory factory) {
    final List listButtonType = [
      {'icon': Icons.text_fields, 'value': 'text'},
      {'icon': Icons.smart_button, 'value': 'elevated'}, // elevated button
      {'icon': Icons.crop_square, 'value': 'outlined'}, // outlined button
      {'icon': Icons.touch_app, 'value': 'icon'},
      {'icon': Icons.list, 'value': 'listTile'},
    ];

    factory.register(
      id: 'action',
      build: (ctx) => CwAction(ctx: ctx),
      config: (ctx) {
        return CwWidgetConfig()
            .addProp(
              CwWidgetProperties(id: 'type', name: 'type')
                ..isToogle(ctx, listButtonType),
            )
            .addProp(
              CwWidgetProperties(id: 'label', name: 'label')..isText(ctx),
            )
            .addProp(CwWidgetProperties(id: 'icon', name: 'icon')..isIcon(ctx));
      },
      populateOnDrag: (ctx, drag) {
        drag.childData![cwProps]['label'] = 'Action';
      },
    );
  }
}

class _CwInputState extends CwWidgetState<CwAction> with HelperEditor {
  @override
  Widget build(BuildContext context) {
    return buildWidget(false, (ctx, constraints) {
      Widget button;
      String? style = getStringProp(widget.ctx, 'type');
      String? label = getStringProp(widget.ctx, 'label') ?? '';
      Map<String, dynamic>? iconProp = getObjProp(widget.ctx, 'icon');
      Icon? icon;
      if (iconProp != null) {
        var iconDes = deserializeIcon(iconProp);
        if (iconDes != null) {
          icon = Icon(iconDes.data);
        }
      }

      void onPressed() async {
        var v = widget.ctx.dataWidget![cwProps]['onPressed'];
        if (v != null && v['type'] == 'repository') {
          CwRepository? repo =
              widget.ctx.aFactory.mapRepositories['rp_${v['repository']}'];
          if (repo != null) {
            if (v['operation'] == 'load') {
              if (ctx.aFactory.isModeDesigner()) {
                return;
              }

              var h = repo.ds.helper!;
              
              repo.dataState.clear();

              // ignore: use_build_context_synchronously
              h.startCancellableSearch(context, repo.criteriaState.data, () {
                var data = h.apiCallInfo.aResponse?.reponse?.data;
                repo.dataState.data = data;
                repo.dataState.loadDataInContainer(data);
              });
            }
          }
        }
      }

      switch (style) {
        case 'elevated':
          if (icon != null) {
            button = ElevatedButton.icon(
              onPressed: onPressed,
              icon: icon,
              label: Text(label),
            );
          } else {
            button = ElevatedButton(onPressed: onPressed, child: Text(label));
          }
          break;
        case 'outlined':
          if (icon != null) {
            button = OutlinedButton.icon(
              onPressed: onPressed,
              icon: icon,
              label: Text(label),
            );
          } else {
            button = OutlinedButton(onPressed: onPressed, child: Text(label));
          }
          break;
        case 'icon':
          button = IconButton(
            onPressed: onPressed,
            icon: icon ?? const Icon(Icons.help),
            tooltip: label,
          );
          break;
        case 'listTile':
          button = ListTile(
            leading: icon,
            dense: true,
            title: Text(label),
            onTap: onPressed,
          );
          break;
        case 'text':
        default:
          if (icon != null) {
            button = TextButton.icon(
              onPressed: onPressed,
              icon: icon,
              label: Text(label),
            );
          } else {
            button = TextButton(onPressed: onPressed, child: Text(label));
          }
      }

      return button;
    });
  }
}
