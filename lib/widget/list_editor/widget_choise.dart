import 'package:flutter/material.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/json_browser/browse_model.dart';

class WidgetChoise extends StatefulWidget {
  final ModelSchema model;
  final Function onSelected;

  const WidgetChoise({
    super.key,
    required this.model,
    required this.onSelected,
  });

  @override
  State<WidgetChoise> createState() => _WidgetChoiseState();
}

class _WidgetChoiseState extends State<WidgetChoise> {
  @override
  Widget build(BuildContext context) {
    var browseSingle = BrowseSingle();
    browseSingle.browse(widget.model, true);

    return Wrap(
      children: [
        for (var e in widget.model.useAttributInfo)
          ChoiceChip(
            label: Text(e.name),
            selected: e.selected,
            onSelected: (value) {
              for (var element in browseSingle.root) {
                element.info.selected = element.info == e;
              }
              widget.onSelected(e);
            },
          ),
      ],
    );
  }
}
