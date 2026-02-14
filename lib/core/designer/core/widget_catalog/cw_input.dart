import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/editor/view/prop_editor/helper_editor.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';
import 'package:jsonschema/feature/content/state_manager.dart';

class CwInput extends CwWidget {
  const CwInput({super.key, required super.ctx, required super.cacheWidget});

  @override
  State<CwInput> createState() => _CwInputState();

  static void initFactory(WidgetFactory factory) {
    List visualStyle = [
      {
        'icon': Icons.tablet_outlined,
        'value': 'border',
      }, // border standard d'un formulaire
      {'icon': Icons.rectangle_rounded, 'value': 'fill'},
      {'icon': Icons.horizontal_rule, 'value': 'under'},
      {
        'icon': Icons.deselect,
        'value': 'custom',
      }, // dans un list avec un separateur
    ];

    factory.register(
      id: 'input',
      build:
          (ctx) =>
              CwInput(key: ctx.getKey(), ctx: ctx, cacheWidget: CachedWidget()),
      config: (ctx) {
        return CwWidgetConfig()
            .addProp(
              CwWidgetProperties(id: 'type', name: 'view type')..isToogle(ctx, [
                {'icon': Icons.label, 'value': 'label'},
                {'icon': Icons.text_fields, 'value': 'textfield'},
                {'icon': Icons.check_box, 'value': 'checkbox'},
              ], defaultValue: 'label'),
            )
            .addProp(
              CwWidgetProperties(id: 'label', name: 'label')..isText(ctx),
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
              CwWidgetProperties(id: 'icon', name: 'icon')..isIcon(ctx),
            );
      },
      populateOnDrag: (ctx, drag) {
        drag.childData![cwProps]['label'] ??= 'Title';
      },
    );
  }
}

class _CwInputState extends CwWidgetStateBindJson<CwInput> with HelperEditor {
  @override
  void setBindJsonValue(value) {
    if (widget.ctx.aFactory.isModeViewer()) {
      ctrlInput?.text = value?.toString() ?? '';
      widget.ctx.repaint(); // pour les text widget
    } else {
      ctrlInput?.text = pathData;
    }
  }

  TextEditingController? ctrlInput;
  FocusNode? focusNode;

  @override
  void dispose() {
    stateRepository?.disposeInput(pathData, this);
    ctrlInput?.dispose();
    focusNode?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    initBind();
    var modeViewer = widget.ctx.aFactory.isModeViewer();
    if (stateRepository != null) {
      ctrlInput = TextEditingController(text: '');
      focusNode = FocusNode();
      if (modeViewer) {
        ctrlInput?.addListener(() {
          if (stateRepository != null &&
              attribut != null &&
              isPrimitiveArrayValue == false) {
            String pathContainer;
            String attrName;
            (pathContainer, attrName) = stateRepository!.getPathInfo(pathData);
            StateContainer? dataContainer;
            (dataContainer, _) = stateRepository!.getStateContainer(
              pathContainer,
              context: context,
              pathWidgetRepos: widget.ctx.parentCtx!.aWidgetPath,
              //onIndexChange: (int idx) {},
            );
            if (dataContainer != null) {
              var value = ctrlInput!.text;
              dataContainer.jsonData[attrName] = value;
            }
          }
        });

        focusNode?.addListener(() {
          if (focusNode!.hasFocus) {
            doChangeRow(pathWidgetRepos: widget.ctx.parentCtx!.aWidgetPath);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String widgetType = getStringProp(widget.ctx, 'type') ?? 'label';

    return buildWidget(
      widgetType != 'textfield',
      ModeBuilderWidget.noConstraint,
      (ctx, constraints, _) {
        bool inTable = ctx.isParentOfType('table');
        bool inArray = widget.ctx.parentCtx?.isType(['list', 'table']) ?? false;

        var modeDesigner = ctx.aFactory.isModeDesigner();
        if (stateRepository != null && attribut != null) {
          initCtrlValue(context, ctx, inArray, modeDesigner);
        } else if (stateRepository != null && eval != null) {
          var r = eval!.eval(
            variables: {
              '\$\$__ctx__\$\$': ctx,
              '\$\$__buildctx__\$\$': context,
            },
            logs: [],
          );
          if (r is Future) {
            r.then((value) {
              if (value != null) {
                ctrlInput?.text = value.toString();
                //widget.ctx.repaint();
              }
            });
          } else {
            ctrlInput?.text = r?.toString() ?? '';
          }
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

        var appearance = styleFactory.getStyleString("appearance", "border");
        InputDecoration decoration = InputDecoration(
          isDense: inTable,
          filled:
              styleFactory.config.decoration?.color != null ||
              appearance == 'fill',
          fillColor: styleFactory.config.decoration?.color,
          labelText: inTable ? null : getStringProp(ctx, 'label') ?? '',
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
        } else if (widgetType == 'checkbox') {
          widgetInput = Row(
            spacing: 8,
            children: [
              Text(
                style: styleFactory.getTextStyle(null),
                getStringProp(widget.ctx, 'label') ?? '',
              ),
              Checkbox(value: false, onChanged: (value) {}),
            ],
          );
        } else {
          var data =
              ctrlInput?.text ?? getStringProp(widget.ctx, 'label') ?? '';
          return addIcon(
            Text(maxLines: 1, style: styleFactory.getTextStyle(null), data),
          );
        }

        return widgetInput;
      },
    );
  }

  void initCtrlValue(
    BuildContext context,
    CwWidgetCtx ctx,
    bool inArray,
    bool modeDesigner,
  ) {
    String? oldPathData = pathData;

    pathData = stateRepository!.getDataPath(
      context,
      isPrimitiveArrayValue ? '${attribut!.info.path}>*' : attribut!.info.path,
      typeListContainer: false,
      widgetPath: ctx.aWidgetPath,
      inArray: inArray,
      state: this,
    );

    if (isPrimitiveArrayValue) {
      // bind sur un tableau de string ou nombre
      int i = pathData.lastIndexOf('[');
      int i2 = pathData.lastIndexOf(']');
      var substring = pathData.substring(i + 1, i2);
      pathData = pathData.substring(0, i);
      int idx = int.tryParse(substring) ?? 0;
      StateContainer? dataContainer;
      (dataContainer, _) = stateRepository!.getStateContainer(
        pathData,
        context: context,
        pathWidgetRepos: ctx.aWidgetPath,
      );
      //print('object $pathData => ${dataContainer?.jsonData} + $idx');
      dynamic val = dataContainer!.jsonData[idx];
      ctrlInput?.text = val?.toString() ?? '';
    } else {
      if (oldPathData != '?' && oldPathData != pathData) {
        stateRepository!.disposeInput(oldPathData, this);
      }
      stateRepository!.registerInput(pathData, this);

      String pathContainer;
      String attrName;
      (pathContainer, attrName) = stateRepository!.getPathInfo(pathData);

      StateContainer? dataContainer;
      (dataContainer, _) = stateRepository!.getStateContainer(
        pathContainer,
        context: context,
        pathWidgetRepos: widget.ctx.parentCtx!.aWidgetPath,
      );
      if (dataContainer != null) {
        dynamic val = dataContainer.jsonData[attrName];
        if (modeDesigner) {
          ctrlInput?.text = pathData;
        } else {
          ctrlInput?.text = val?.toString() ?? '';
        }
      }
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

      // inputDecoration = InputDecoration(
      //     suffixIcon: info.suffixIcon,
      //     hintStyle: TextStyle(fontSize: 12),
      //     hintText: info.hint,
      //     error: _errorWidget,
      //     labelText: labelWidget == null ? info.label : null,
      //     label: labelWidget,
      //     border: InputBorder.none,
      //     isDense: true,
      //     contentPadding: EdgeInsets.fromLTRB(5, margeTop, 5, 0));