import 'dart:convert';

class JsonToSchemaYaml {
  String rawJson = '';

  ImportData doImportJSON() {
    var exp = RegExp(r'\,(?=\s*?[\}\]])');
    rawJson = rawJson.replaceAll('\n', '');
    rawJson = rawJson.replaceAll(exp, '');

    dynamic root = jsonDecode(rawJson);
    ImportData data = ImportData();
    doAttr(null, root, data);
    print('${data.yaml}');
    return data;
  }

  void doAttr(String? name, dynamic value, ImportData data) {
    if (value is List) {
      for (var i = 0; i < data.level; i++) {
        data.yaml.write(' ');
      }
      if (name != null) {
        data.yaml.write(name);
        data.yaml.write('[]');
        data.yaml.writeln(' : ');
      }
      data.level++;
      if (value.isNotEmpty) {
        doAttr(null, value[0], data);
      }
      //}
      data.level--;
    } else if (value is Map) {
      if (name != null) {
        for (var i = 0; i < data.level; i++) {
          data.yaml.write('   ');
        }
        data.yaml.write(name);
        data.yaml.writeln(' : ');
        data.level++;
      }
      for (var element in value.entries) {
        doAttr(element.key, element.value, data);
      }
      if (name != null) {
        data.level--;
      }
    } else {
      // si attribut
      for (var i = 0; i < data.level; i++) {
        data.yaml.write('   ');
      }
      data.yaml.write(name);
      data.yaml.write(' : ');
      data.yaml.writeln(getType(value));
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

class ImportData {
  final StringBuffer yaml = StringBuffer();
  int level = 0;
}
