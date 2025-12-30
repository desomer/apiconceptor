import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/component/helper/helper_editor.dart';
import 'package:jsonschema/core/designer/cw_factory.dart';
import 'package:jsonschema/core/designer/cw_widget.dart';

class CwInput extends CwWidget {
  const CwInput({super.key, required super.ctx});

  @override
  State<CwInput> createState() => _CwInputState();

  static void initFactory(WidgetFactory factory) {
    factory.register(
      id: 'input',
      build: (ctx) => CwInput(ctx: ctx),
      config: (ctx) {
        return CwWidgetConfig()
            .addProp(
              CwWidgetProperties(id: 'type', name: 'type')..isToogle(ctx, [
                {'icon': Icons.label, 'value': 'label'},
                {'icon': Icons.text_fields, 'value': 'textfield'},
                {'icon': Icons.check_box, 'value': 'checkbox'},
              ], defaultValue: 'label'),
            )
            .addProp(
              CwWidgetProperties(id: 'label', name: 'label')..isText(ctx),
            );
      },
      populateOnDrag: (ctx, drag) {
        drag.childData![cwProps]['label'] = 'Title';
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
  final focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    initBind();
    var modeViewer = widget.ctx.aFactory.isModeViewer();
    if (stateRepository != null) {
      ctrlInput = TextEditingController(text: widget.ctx.aPath);
      if (modeViewer) {
        ctrlInput?.addListener(() {
          if (stateRepository != null) {
            String pathContainer;
            String attrName;
            (pathContainer, attrName) = stateRepository!.getPathInfo(pathData);
            var dataContainer = stateRepository!.getStateContainer(
              pathContainer,
            );
            if (dataContainer != null) {
              var value = ctrlInput!.text;
              dataContainer.jsonData[attrName] = value;
            }
          }
        });
      }
    }
  }

  @override
  void dispose() {
    stateRepository?.disposeInput(pathData, this);
    ctrlInput?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildWidget(false, (ctx, constraints) {
      var modeDesigner = widget.ctx.aFactory.isModeDesigner();
      if (stateRepository != null) {
        String? oldPathData = pathData;
        pathData = stateRepository!.getDataPath(
          context,
          attribut!.info,
          typeList: false,
        );
        if (oldPathData != '?' && oldPathData != pathData) {
          stateRepository!.disposeContainer(oldPathData);
        }
        stateRepository!.registerInput(pathData, this);

        String pathContainer;
        String attrName;
        (pathContainer, attrName) = stateRepository!.getPathInfo(pathData);
        var dataContainer = stateRepository!.getStateContainer(pathContainer);
        if (dataContainer != null) {
          dynamic val = dataContainer.jsonData[attrName];
          if (modeDesigner) {
            ctrlInput?.text = pathData;
          } else {
            ctrlInput?.text = val?.toString() ?? '';
          }
        }
      }
      // else if (modeDesigner) {
      //   ctrlInput?.text = ctx.aPath;
      // }

      String style = getStringProp(widget.ctx, 'type') ?? 'label';

      if (style == 'textfield') {
        focusNode.canRequestFocus = !modeDesigner;
        focusNode.skipTraversal = modeDesigner;

        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 300, maxHeight: 50),
          child: AbsorbPointer(
            absorbing: modeDesigner,
            child: TextField(
              focusNode: focusNode,
              //readOnly: modeDesigner ? true : false,
              //onTap: modeDesigner ? () {} : null,
              controller: ctrlInput,
              decoration: InputDecoration(
                labelText: getStringProp(widget.ctx, 'label') ?? '',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        );
      } else if (style == 'checkbox') {
        return Row(
          spacing: 8,
          children: [
            Text(getStringProp(widget.ctx, 'label') ?? ''),
            Checkbox(value: false, onChanged: (value) {}),
          ],
        );
      } else {
        return Text(getStringProp(widget.ctx, 'label') ?? '');
      }
    });
  }
}
