import 'package:flutter/material.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/core/designer/core/widget_catalog/cw_mask_helper.dart';
import 'package:jsonschema/core/designer/editor/view/prop_editor/helper_editor.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';

class CwInputSearch extends CwWidget {
  const CwInputSearch({
    super.key,
    required super.ctx,
    required super.cacheWidget,
  });

  @override
  State<CwInputSearch> createState() => _CwInputSearchState();

  static void initFactory(WidgetFactory factory) {
    List visualStyle = [
      {
        'icon': Icons.tablet_outlined,
        'value': 'border',
      }, // border standard d'un formulaire
      {'icon': Icons.rectangle_rounded, 'value': 'fill'},
      {'icon': Icons.horizontal_rule, 'value': 'under'},
      {'icon': Icons.deselect, 'value': 'custom'},
      // dans un list avec un separateur
    ];

    factory.registerComponent(
      id: 'inputSearch',
      build:
          (ctx) => CwInputSearch(
            key: ctx.getKey(),
            ctx: ctx,
            cacheWidget: CachedWidget(),
          ),
      config: (ctx) {
        return CwWidgetConfig()
            .addStyle(
              CwWidgetProperties(id: 'type', name: 'view type')..isToogle(ctx, [
                {'icon': Icons.text_fields, 'value': 'textfield'},
                {'icon': Icons.check_box, 'value': 'checkbox'},
                {'icon': Icons.add_reaction, 'value': 'icon'},
              ], defaultValue: 'textfield'),
            )
            .addProp(
              CwWidgetProperties(id: 'label', name: 'label')..isText(ctx),
            )
            .addStyle(
              CwWidgetProperties(id: 'tooltip', name: 'tooltip')..isText(ctx),
            )
            .addProp(CwWidgetProperties(id: 'size', name: 'size')..isSize(ctx))
            .addStyle(
              CwWidgetProperties(id: 'appearance', name: 'appearance')
                ..isToogle(
                  ctx,
                  visualStyle,
                  defaultValue: 'border',
                  path: [cwStyle],
                ),
            )
            .addStyle(
              CwWidgetProperties(id: 'dense', name: 'dense')..isBool(ctx),
            )
            .addStyle(
              CwWidgetProperties(id: 'icon', name: 'icon')..isIcon(ctx),
            );
      },
      populateOnDrag: (ctx, drag) {
        drag.childData![cwProps]['label'] ??= 'Title';
      },
    );
  }
}

class _CwInputSearchState extends CwWidgetState<CwInputSearch>
    with HelperEditor {
  @override
  void setBindJsonValue(value) {}

  TextEditingController? ctrlInput;
  FocusNode? focusNode;

  @override
  void dispose() {
    ctrlInput?.dispose();
    focusNode?.dispose();
    super.dispose();
  }

  var debouncer = Debouncer(milliseconds: 500);

  @override
  void initState() {
    super.initState();

    var modeViewer = widget.ctx.aFactory.isModeViewer();
    ctrlInput = TextEditingController(text: '');
    focusNode = FocusNode();
    if (modeViewer) {
      ctrlInput?.addListener(() {
        //debounce la recherche pour éviter de faire trop de requêtes
        debouncer.run(() {
          print('input search value=${ctrlInput?.text}');
          listCell = arrayCtx?.getAllCellsCtx();
          if (listCell != null && arrayCtx != null) {
            (arrayCtx!.widgetState as CwWidgetStateBindJson).setFilterValue(ctrlInput?.text, listCell!);
          }
        });
      });

      focusNode?.addListener(() {
        if (focusNode!.hasFocus) {}
      });
    }
  }

  FormatterTextfield? formatter;
  List<CwWidgetCtx>? listCell;
  CwWidgetCtx? arrayCtx;

  @override
  Widget build(BuildContext context) {
    String widgetType = getStringProp(widget.ctx, 'type') ?? 'textfield';

    return buildWidget(
      widgetType != 'textfield',
      ModeBuilderWidget.noConstraint,
      (ctx, constraints, _) {
        bool isDense =
            getBoolProp(ctx, 'dense') ?? ctx.hasParentOfType(['table']);
        // bool inListOrArray = widget.ctx.hasParentOfType(['list', 'table']);

        TextfieldBuilderInfo info = TextfieldBuilderInfo(
          label: isDense ? null : getStringProp(ctx, 'label') ?? '',
          bindType: getStringProp(ctx, 'dataType') ?? 'TEXT',
          editable: true,
          enable: true,
        );

        arrayCtx = ctx.findParentArrayContainer();
        if (arrayCtx != null) {
          listCell = arrayCtx!.getAllCellsCtx();
        }

        formatter = FormatterTextfield(info);
        formatter?.initMaskAndValidatorInfo(null);

        var modeDesigner = ctx.aFactory.isModeDesigner();

        var appearance = styleFactory.getStyleString("appearance", "border");
        if (appearance == 'border' &&
            !styleFactory.styleExist(['bSize', 'bColor'])) {
          styleFactory.config.side = BorderSide(
            width: 1,
            //color FFBDBDBD
            color: Color(0xFFBDBDBD),
          );
          styleFactory.config.hBorder = 1 * 2;
        }

        var appearanceBorder = {
          "border": OutlineInputBorder(
            borderSide: styleFactory.config.side ?? const BorderSide(),
            borderRadius:
                styleFactory.config.borderRadius ??
                const BorderRadius.all(Radius.circular(4.0)),
          ),
          "fill": UnderlineInputBorder(
            borderSide: styleFactory.config.side ?? const BorderSide(),
            borderRadius:
                styleFactory.config.borderRadius ??
                const BorderRadius.only(
                  topLeft: Radius.circular(4.0),
                  topRight: Radius.circular(4.0),
                ),
          ),
          "under": UnderlineInputBorder(
            borderSide: styleFactory.config.side ?? const BorderSide(),
            borderRadius:
                styleFactory.config.borderRadius ??
                const BorderRadius.only(
                  topLeft: Radius.circular(4.0),
                  topRight: Radius.circular(4.0),
                ),
          ),
          "custom": InputBorder.none,
        };

        InputDecoration decoration = InputDecoration(
          isDense: isDense,
          filled:
              styleFactory.config.decoration?.color != null ||
              appearance == 'fill',
          fillColor: styleFactory.config.decoration?.color,
          labelText: info.label,
          enabledBorder: appearanceBorder[appearance],
          focusedBorder: appearanceBorder[appearance],
          contentPadding: styleFactory.config.edgePadding,
        );

        Widget widgetInput;

        if (widgetType == 'textfield') {
          focusNode?.canRequestFocus = !modeDesigner;
          focusNode?.skipTraversal = modeDesigner;
          var isSizeDefined = styleFactory.isSizeDefined();

          widgetInput = ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isSizeDefined ? double.infinity : 300,
              maxHeight: isSizeDefined ? double.infinity : 50,
            ),
            child: AbsorbPointer(
              absorbing: modeDesigner,
              child: TextField(
                style: styleFactory.getTextStyle(null),
                focusNode: focusNode,
                //readOnly: modeDesigner ? true : false,
                //onTap: modeDesigner ? () {} : null,
                controller: ctrlInput,
                decoration: decoration,
              ),
            ),
          );

          var elevation = styleFactory.getElevation();
          if (elevation != null && elevation > 0) {
            widgetInput = Material(
              elevation: elevation,
              borderRadius: styleFactory.config.borderRadius,
              child: widgetInput,
            );
          }
        } else {
          if (ctrlInput != null && widgetType == 'checkbox') {
            // gestion asynchrone des valeur computed en asynchrone
            widgetInput = ValueListenableBuilder(
              valueListenable: ctrlInput!,
              builder: (context, value, child) {
                return getWidgetText(widgetType, modeDesigner);
              },
            );
          } else {
            widgetInput = getWidgetText(widgetType, modeDesigner);
          }
        }

        return widgetInput;
      },
    );
  }

  Widget getWidgetText(String widgetType, bool modeDesigner) {
    var data = ctrlInput?.text ?? getStringProp(widget.ctx, 'label') ?? '';
    // if (modeDesigner && bindInfo.computedInfo != null) {
    //   data = '#{${bindInfo.computedInfo!['name']}}';
    // }
    if (widgetType == 'checkbox') {
      return addTooltip(
        Row(
          spacing: 8,
          children: [
            Text(
              style: styleFactory.getTextStyle(null),
              overflow: TextOverflow.ellipsis,
              getStringProp(widget.ctx, 'label') ?? '',
            ),
            Checkbox(
              value: data == 'true',
              onChanged: (value) {
                ctrlInput?.text = value.toString();
              },
            ),
          ],
        ),
      );
    } else if (widgetType == 'icon') {
      Icon iconData = getIconProp(widget.ctx, 'icon') ?? Icon(Icons.check);
      if (data == 'true' || modeDesigner) {
        return addTooltip(iconData);
      } else {
        return const SizedBox();
      }
    } else {
      return addIcon(
        addTooltip(
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) {},
            child: SelectableRegion(
              selectionControls: materialTextSelectionControls,
              child: Text(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: styleFactory.getTextStyle(16),
                data,
              ),
            ),
          ),
        ),
      );
    }
  }

  Widget addTooltip(Widget child) {
    String? tooltip = getStringProp(widget.ctx, 'tooltip');
    if (tooltip != null && tooltip.isNotEmpty) {
      return Tooltip(message: tooltip, child: child);
    } else {
      return child;
    }
  }

  Widget addIcon(Widget child) {
    Icon? icon = getIconProp(widget.ctx, 'icon');
    if (icon != null) {
      return Row(
        spacing: 5,
        mainAxisSize: MainAxisSize.min,
        children: [icon, child],
      );
    } else {
      return child;
    }
  }
}
