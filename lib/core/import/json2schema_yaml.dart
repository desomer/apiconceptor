import 'dart:convert';

class JsonToSchemaYaml {
  String rawJson = '';

  ImportData doImportJSON() {
    var exp = RegExp(r'\,(?=\s*?[\}\]])');
    rawJson = rawJson.replaceAll('\n', '');
    rawJson = rawJson.replaceAll(exp, '');
    rawJson = rawJson.trim();
    ImportData data = ImportData();
    if (rawJson.isNotEmpty) {
      dynamic root = jsonDecode(rawJson);
      doAttr(null, root, data);
    }
    return data;
  }

  void doAttr(String? name, dynamic value, ImportData data) {
    if (value is List) {
      data.addTab();
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
        data.addTab();
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
      data.addTab();
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
  List<String> path = [];

  void addObj(String name) {
    yaml.writeln('$name :');
  }

  void addAttr(String name, dynamic value) {
    yaml.writeln('$name : $value');
  }

  void addTab() {
    for (var i = 0; i < level; i++) {
      yaml.write('   ');
    }
  }
}
