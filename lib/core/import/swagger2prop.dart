import 'dart:convert';

class JsonSchemaPath {
  final String pathJson;
  final String type;
  final Map<String, dynamic> properties;

  JsonSchemaPath({
    required this.pathJson,
    required this.type,
    required this.properties,
  });

  @override
  String toString() =>
      'JsonSchemaPath(pathJson: $pathJson, type: $type, properties: $properties)';
}

class JsonSchemaParser {
  List<JsonSchemaPath> parse(String jsonSchemaString) {
    final Map<String, dynamic> schema = jsonDecode(jsonSchemaString);
    final List<JsonSchemaPath> results = [];

    _walkSchema(schema, currentPath: "", collector: results);

    return results;
  }

  static const listProperties = [
    "format",
    "enum",
    "description",
    "title",
    "default",
    "example",
    "minLength",
    "maxLength",
    "minimum",
    "exclusiveMinimum",
    "maximum",
    "exclusiveMaximum",
    "pattern",
    "items",
    "properties",
    "oneOf",
    "anyOf",
    "allOf",
    "additionalProperties",
    "const",
    "uniqueItems",
    "minItems",
    "maxItems",
    "multipleOf",
    'minProperties',
    'maxProperties',
    "dependentRequired",
    "contentEncoding",
    "contentMediaType",
    "readOnly",
    "writeOnly",
    "deprecated",
    r"$comment",
  ];

  void _walkSchema(
    Map<String, dynamic> node, {
    required String currentPath,
    required List<JsonSchemaPath> collector,
  }) {
    final type = _schemaType(node["type"]);

    var requiredProperties = node['required'];
    //TODO: handle required properties if needed

    // Ajoute le noeud courant
    collector.add(
      JsonSchemaPath(
        pathJson: currentPath.isEmpty ? "<root>" : "root>$currentPath",
        type: type,
        properties: {for (var key in listProperties) key: node[key]}
          ..removeWhere((key, value) => value == null),
      ),
    );

    // --- OBJECT ---
    if (type == "object" && node["properties"] is Map<String, dynamic>) {
      final props = node["properties"] as Map<String, dynamic>;

      for (final entry in props.entries) {
        final newPath = currentPath.isEmpty
            ? entry.key
            : "$currentPath>${entry.key}";
        _walkSchema(
          entry.value as Map<String, dynamic>,
          currentPath: newPath,
          collector: collector,
        );
      }
    }

    // --- ARRAY ---
    if (type == "array" && node["items"] is Map<String, dynamic>) {
      final items = node["items"] as Map<String, dynamic>;
      final newPath = "$currentPath[]";
      _walkSchema(items, currentPath: newPath, collector: collector);
    }

    // --- COMPOSITIONS ---
    _handleComposition("oneOf", node, currentPath, collector);
    _handleComposition("anyOf", node, currentPath, collector);
    _handleComposition("allOf", node, currentPath, collector);
  }

  void _handleComposition(
    String key,
    Map<String, dynamic> node,
    String currentPath,
    List<JsonSchemaPath> collector,
  ) {
    if (node[key] is List) {
      final List<dynamic> list = node[key];

      for (int i = 0; i < list.length; i++) {
        final subSchema = list[i] as Map<String, dynamic>;
        final compPath = "$currentPath>$key[$i]";

        collector.add(
          JsonSchemaPath(
            pathJson: compPath,
            type: _schemaType(subSchema["type"]),
            properties: {"compositionType": key},
          ),
        );

        _walkSchema(subSchema, currentPath: compPath, collector: collector);
      }
    }
  }

  String _schemaType(dynamic rawType) {
    if (rawType is String) {
      return rawType;
    }

    if (rawType is List) {
      if (rawType.last == "null") {
        return "${rawType.first}";
      }
      return rawType.map((value) => value.toString()).join(" | ");
    }

    if (rawType == null) {
      return "unknown";
    }

    return rawType.toString();
  }

  String getTreeYaml(List<JsonSchemaPath> paths) {
    final Map<String, dynamic> tree = {};

    for (final p in paths) {
      if (p.pathJson == "<root>") continue;

      final segments = p.pathJson.split('>');
      Map<String, dynamic> current = tree;

      for (int i = 1; i < segments.length; i++) {
        final seg = segments[i];

        final isLast = i == segments.length - 1;

        if (isLast) {
          // Dernier segment → assigner le type
          final existing = current[seg];
          if (existing is Map<String, dynamic>) {
            existing["type"] = p.type;
          } else {
            current[seg] = p.type;
          }
        } else {
          // Segment intermédiaire → créer un sous-objet si absent
          final existing = current[seg];
          if (existing is Map<String, dynamic>) {
            current = existing;
          } else {
            final next = <String, dynamic>{};
            if (existing != null) {
              next["type"] = existing;
            }
            current[seg] = next;
            current = next;
          }
        }
      }
    }

    return _toYaml(tree, indent: 0);
  }

  String _toYaml(Map<String, dynamic> node, {required int indent}) {
    final StringBuffer buffer = StringBuffer();
    final String prefix = '   ' * indent;

    node.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        buffer.writeln('$prefix$key:');
        buffer.write(_toYaml(value, indent: indent + 2));
      } else {
        buffer.writeln('$prefix$key: $value');
      }
    });

    return buffer.toString();
  }
}
