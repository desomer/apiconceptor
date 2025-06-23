import 'package:jsonschema/core/import/json2schema_yaml.dart';
import 'package:yaml/yaml.dart';

class Swagger2Schema {
  Future<void> import() async {
    String swagger = """
openapi: 3.0.4
info:
  title: Sample API
  description: Optional multiline or single-line description in [CommonMark](http://commonmark.org/help/) or HTML.
  version: 0.1.9

servers:
  - url: http://api.example.com/v1
    description: Optional server description, e.g. Main (production) server

paths:
  /users:
    get:
      summary: Returns a list of users.
      description: Optional extended description in CommonMark or HTML.
      responses:
        "200": # status code
          description: A JSON array of user names
          content:
            application/json:
              schema:
                type: array
                items:
                  type: string
  """;

    var root = loadYaml(swagger);

    ImportData data = ImportData();
    doAttr(null, root, data);
    //print('${data.yaml}');
    //return data;
  }

  void doAttr(String? name, dynamic value, ImportData data) {
    if (value is List) {
      data.level++;
      if (value.isNotEmpty) {
        for (var i = 0; i < value.length; i++) {
          data.path.add('$name[$i]');
          doAttr(null, value[i], data);
          data.path.removeLast();
        }
      }
      data.level--;
    } else if (value is Map) {
      if (name != null) {
        data.level++;
        data.path.add(name);
      }
      for (var element in value.entries) {
        doAttr(element.key, element.value, data);
      }
      if (name != null) {
        data.level--;
        data.path.removeLast();
      }
    } else {
      print('$name = $value level=${data.level} path=${data.path}');
      // data.yaml.write(name);
      // data.yaml.write(' : ');
      // data.yaml.writeln(getType(value));
    }
  }

  String getType(dynamic v) {
    if (v is num) {
      return 'number';
    } else if (v is bool) {
      return 'boolean';
    }
    return 'string';
  }
}


