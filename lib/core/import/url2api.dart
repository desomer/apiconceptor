import 'package:jsonschema/core/import/json2schema_yaml.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/core/yaml_browser.dart';
import 'package:yaml/yaml.dart';

class Url2Api {
  String raw = '';
  List<ApiImportDesc> apiInfo = [];

  ImportData doImportJSON(ModelSchema api) {
    ImportData data = ImportData();

    YamlDocument doc = loadYamlDocument(api.modelYaml);

    YamlDoc docYaml = YamlDoc();
    docYaml.indexBy = ['\$server'];
    docYaml.doAnalyse(doc, api.modelYaml);

    var lines = raw.split('\n');
    for (var urll in lines) {
      var apiDesc = ApiImportDesc();

      var ope = 'get';

      var hasOpe = urll.split(' ');
      if (hasOpe.length == 2) {
        if ([
          'GET',
          'DELETE',
          'PATCH',
          'PUT',
          'POST',
        ].contains(hasOpe[0].toUpperCase())) {
          ope = hasOpe[0].toLowerCase();
        }
        urll = hasOpe[1];
      }

      var u = urll.split('?');
      var svr = u[0];
      var param = u.length == 2 ? u[1] : '';
      if (param.isNotEmpty) {
        var aParams = param.split('&');
        for (var element in aParams) {
          var keyVal = element.split('=');
          apiDesc.params[keyVal[0]] = keyVal[1];
        }
      }

      StringBuffer path = StringBuffer('root>');

      var s = svr.split('/');
      YamlLine row;
      int nb = 0;
      if (s.length > 1) {
        if (s[0].startsWith("http")) {
          nb = 3;
          var serveur = '${s[0]}//${s[2]}';
          var existServeur = docYaml.index['\$server']?.value[serveur];
          path.write(s[2]);

          if (existServeur == null) {
            row = docYaml.addAtEnd(s[2], '');
            docYaml.addChild(row, '\$server', serveur);
          } else {
            row = existServeur.first.parent!;
          }
        } else {
          nb = 1;
          row = docYaml.listRoot.firstWhere(
            (element) {
              return element.name == s[0];
            },
            orElse: () {
              return docYaml.addAtEnd(s[0], '');
            },
          );
        }

        for (var i = nb; i < s.length; i++) {
          path.write('>');
          path.write(s[i]);
          row = docYaml.addChild(row, s[i], '');
        }
        path.write('>$ope');
        docYaml.addChild(row, ope, 'ope');
      }

      apiDesc.path = path.toString();
      apiInfo.add(apiDesc);
    }

    data.yaml.write(docYaml.getDoc());

    return data;
  }
}

class ApiImportDesc {
  late String path;
  Map params = {};
}
