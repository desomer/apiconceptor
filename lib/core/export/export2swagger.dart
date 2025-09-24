import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';

class ExportToSwagger<T extends List<Tag>> extends JsonBrowser {
  List<Tag> tags = [];

  @override
  List<Tag> getRoot(NodeAttribut node) {
    return tags as T;
  }

  @override
  dynamic getChild(
    ModelSchema model,
    NodeAttribut parentNode,
    NodeAttribut node,
    dynamic parent,
  ) {
    if (node.info.type == 'ope') {
      String tag = node.info.properties?['tag'] ?? 'default';
      var nodeTag = NodeTag(name: node.info.name, node: node);
      Tag tagObj = tags.firstWhere(
        (element) => element.name == tag,
        orElse: () {
          var newTag = Tag(name: tag);
          tags.add(newTag);
          return newTag;
        },
      );
      tagObj.apis.add(nodeTag);
    }

    return tags;
  }
}

class Tag {
  Tag({required this.name});
  List<NodeTag> apis = [];
  String name;
}

class NodeTag {
  NodeTag({required this.name, required this.node});
  NodeAttribut node;
  String name;
}
