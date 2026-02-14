import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/editor/engine/behavior_manager.dart';
import 'package:jsonschema/core/designer/editor/view/prop_editor/helper_editor.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';

class CwAction extends CwWidget {
  const CwAction({super.key, required super.ctx, required super.cacheWidget});

  @override
  State<CwAction> createState() => _CwInputState();

  static void initFactory(WidgetFactory factory) {
    final List listButtonType = [
      {'icon': Icons.smart_button, 'value': 'elevated'},
      {'icon': Icons.text_fields, 'value': 'text'}, // elevated button
      {'icon': Icons.crop_square, 'value': 'outlined'}, // outlined button
      {'icon': Icons.touch_app, 'value': 'icon'},
      {'icon': Icons.list, 'value': 'listTile'},
    ];

    factory.register(
      id: 'action',
      build:
          (ctx) => CwAction(
            key: ctx.getKey(),
            ctx: ctx,
            cacheWidget: CachedWidget(),
          ),
      config: (ctx) {
        return CwWidgetConfig()
            .addStyle(
              CwWidgetProperties(id: 'type', name: 'view type')
                ..isToogle(ctx, listButtonType, defaultValue: 'elevated'),
            )
            .addStyle(CwWidgetProperties(id: 'icon', name: 'icon')..isIcon(ctx))
            .addProp(
              CwWidgetProperties(id: 'label', name: 'label')..isText(ctx),
            )
            .addProp(CwWidgetProperties(id: 'size', name: 'size')..isSize(ctx));
      },
      populateOnDrag: (ctx, drag) {
        drag.childData![cwProps]['label'] ??= 'New Action';
      },
    );
  }
}

class _CwInputState extends CwWidgetStateBindJson<CwAction> with HelperEditor {
  @override
  void initState() {
    initBind();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return buildWidget(false, ModeBuilderWidget.noConstraint, (
      ctx,
      constraints,
      _,
    ) {
      Widget button;
      String? style = getStringProp(ctx, 'type');
      String? label = getStringProp(ctx, 'label');
      Icon? icon = getIconProp(ctx, 'icon');

      void onPressed() async {
        setSelectedRow(context);

        BehaviorManager.executeBehaviors(
          ctx,
          // ignore: use_build_context_synchronously
          context,
        );
      }

      var type = ctx.slotProps?.type;
      if (type == 'tab') {
        style = 'inner';
      } else if (type == 'tabslider') {
        style = 'inner';
      } else if (type == 'navigationdestination') {
        style = 'navigationdestination';
      }

      var styleText = styleFactory.getTextStyle(null);

      switch (style) {
        case 'navigationdestination':
          button = NavigationDestination(
            icon:
                icon ??
                Icon(Icons.help, color: styleFactory.getColor('fgColor')),
            label: label ?? '',
          );
          break;

        case 'inner':
          button = Row(
            spacing: 5,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) icon,
              if (label != null) Text(style: styleText, label),
            ],
          );

          break;

        case 'outlined':
          if (icon != null) {
            button = OutlinedButton.icon(
              onPressed: onPressed,
              icon: icon,
              label: Text(style: styleText, label ?? ''),
            );
          } else {
            button = OutlinedButton(
              onPressed: onPressed,
              child: Text(style: styleText, label ?? ''),
            );
          }
          break;
        case 'icon':
          button = IconButton(
            style: styleFactory.getButtonStyle(null, styleText),
            onPressed: onPressed,
            icon: icon ?? const Icon(Icons.help),
            tooltip: label,
          );
          break;
        case 'listTile':
          var isSizeDefined = styleFactory.isSizeDefined();
          button = styleFactory.getStyledContainer(
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isSizeDefined ? double.infinity : 300,
                maxHeight: isSizeDefined ? double.infinity : 50,
              ),
              child: ListTile(
                leading: icon,
                dense: true,
                title: Text(style: styleText, label ?? ''),
                onTap: onPressed,
              ),
            ),
            context,
          );
          break;
        case 'text':
          if (icon != null) {
            button = TextButton.icon(
              style: styleFactory.getButtonStyle(null, styleText),
              onPressed: onPressed,
              icon: icon,
              label: Text(style: styleText, label ?? ''),
            );
          } else {
            button = TextButton(
              style: styleFactory.getButtonStyle(null, styleText),
              onPressed: onPressed,
              child: Text(style: styleText, label ?? ''),
            );
          }

        case 'elevated':
        default:
          if (icon != null) {
            button = ElevatedButton.icon(
              style: styleFactory.getButtonStyle(null, styleText),
              onPressed: onPressed,
              icon: icon,
              label: Text(style: styleText, label ?? ''),
            );
          } else {
            button = ElevatedButton(
              style: styleFactory.getButtonStyle(null, styleText),
              onPressed: onPressed,
              child: Text(style: styleText, label ?? ''),
            );
          }
          break;
      }

      return button;
    });
  }
}
