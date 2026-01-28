import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/editor/view/prop_editor/helper_editor.dart';
import 'package:jsonschema/core/designer/core/cw_widget_factory.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';
import 'package:jsonschema/feature/content/state_manager.dart';

class CwInput extends CwWidget {
  const CwInput({super.key, required super.ctx});

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
      build: (ctx) => CwInput(key: ctx.getKey(), ctx: ctx),
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
    }
  }

  TextEditingController? ctrlInput;
  FocusNode? focusNode;

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
          if (stateRepository != null && isPrimitiveArrayValue == false) {
            String pathContainer;
            String attrName;
            (pathContainer, attrName) = stateRepository!.getPathInfo(pathData);
            StateContainer? dataContainer;
            (dataContainer, _) = stateRepository!.getStateContainer(
              pathContainer,
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
            doChangeRow();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    stateRepository?.disposeInput(pathData, this);
    ctrlInput?.dispose();
    focusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String widgetType = getStringProp(widget.ctx, 'type') ?? 'label';

    return buildWidget(
      widgetType != 'textfield',
      ModeBuilderWidget.noConstraint,
      (ctx, constraints) {
        bool inTable = ctx.isParentOfType('table');
        bool inArray = widget.ctx.parentCtx?.isType(['list', 'table']) ?? false;

        var modeDesigner = ctx.aFactory.isModeDesigner();
        if (stateRepository != null && attribut != null) {
          String? oldPathData = pathData;

          pathData = stateRepository!.getDataPath(
            context,
            isPrimitiveArrayValue
                ? '${attribut!.info.path}>*'
                : attribut!.info.path,
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
            (dataContainer, _) = stateRepository!.getStateContainer(pathData);
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
          widgetInput = Text(
            style: styleFactory.getTextStyle(null),
            ctrlInput?.text ?? getStringProp(widget.ctx, 'label') ?? '',
          );
        }

        return widgetInput;
      },
    );
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