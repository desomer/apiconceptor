import 'package:jsonschema/widget/tree_editor/pan_yaml_tree.dart';

// ignore: must_be_immutable
class PanApiDocResponse extends PanYamlTree {
  PanApiDocResponse({
    super.key,
    required super.getSchemaFct,
    required super.showable,
  });

  @override
  bool isReadOnly() {
    return true;
  }
}
