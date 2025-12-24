import 'package:flutter/material.dart';
import 'package:flutter_iconpicker/Models/configuration.dart';
import 'package:jsonschema/core/designer/component/helper/helper_editor.dart';
import 'package:jsonschema/core/designer/component/prop_editor/generic_editor.dart';
import 'package:flutter_iconpicker/flutter_iconpicker.dart';

class IconEditor extends GenericEditor {
  const IconEditor({
    super.key,
    required super.json,
    required super.onJsonChanged,
    required super.config,
  });

  @override
  State<IconEditor> createState() => _IconEditorState();
}

class _IconEditorState extends State<IconEditor> with HelperEditor {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var mIcon = widget.json[widget.config.id];
    if (mIcon != null) {
      _icon = Icon(deserializeIcon(mIcon)!.data);
    }

    return Row(
      spacing: 10,
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        TextButton(onPressed: _pickIcon, child: const Text('select icon')),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _icon ?? Container(),
        ),
      ],
    );
  }

  Icon? _icon;

  Future<IconPickerIcon?> _pickIcon() async {
    IconPickerIcon? icon = await showIconPicker(
      context,
      configuration: SinglePickerConfiguration(
        iconPackModes: [IconPack.material],
        showTooltips: true,
        searchComparator:
            (String search, IconPickerIcon icon) =>
                search.toLowerCase().contains(
                  icon.name.replaceAll('_', ' ').toLowerCase(),
                ) ||
                icon.name.toLowerCase().contains(search.toLowerCase()),
      ),
    );

    if (icon == null) {
      _icon = null;
      widget.json.remove(widget.config.id);
    } else {
      _icon = Icon(icon.data);
      Map<String, dynamic>? mapIcon = serializeIcon(icon);
      widget.json[widget.config.id] = mapIcon;
      widget.onJsonChanged?.call(widget.json);
    }
    setState(() {});
    return icon;
  }
}
