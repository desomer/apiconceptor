import 'package:flutter/material.dart';
import 'package:jsonschema/core/designer/cw_widget.dart';

abstract class GenericEditor extends StatefulWidget {
  const GenericEditor({
    super.key,
    required this.json,
    required this.config,
    this.onJsonChanged,
  });

  final Map json;
  final CwWidgetProperties config;
  final ValueChanged<Map>? onJsonChanged;

}
