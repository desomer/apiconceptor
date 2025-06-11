import 'package:jsonschema/company_model.dart';
import 'package:jsonschema/import/json2schema_yaml.dart';
import 'package:jsonschema/core/yaml_browser.dart';
import 'package:yaml/yaml.dart';

class Url2Api {
  String raw = '';

  ImportData doImportJSON(ModelSchemaDetail api) {
    ImportData data = ImportData();

    YamlDocument doc = loadYamlDocument(api.modelYaml);

    YamlDoc docYaml = YamlDoc();
    docYaml.indexBy = ['\$server'];
    docYaml.doAnalyse(doc, api.modelYaml);

    var lines = raw.split('\n');
    for (var urll in lines) {
      var u = urll.split('?');
      var svr = u[0];
      // var param = u.length == 2 ? u[1] : [];
      var s = svr.split('/');
      if (s.length > 2) {
        var serveur = '${s[0]}//${s[2]}';
        var existServeur = docYaml.index['\$server']?.value[serveur];
        YamlLine row;
        if (existServeur == null) {
          row = docYaml.addAtEnd(s[2], '');
          docYaml.addChild(row, '\$server', serveur);
        } else {
          row = existServeur.first.parent!;
        }
        for (var i = 3; i < s.length; i++) {
          row = docYaml.addChild(row, s[i], '');
        }
        docYaml.addChild(row, 'get', 'ope');
      }
    }

    data.yaml.write(docYaml.getDoc());

    return data;
  }
}


