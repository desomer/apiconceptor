import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/api/pan_api_editor.dart';
import 'package:jsonschema/json_browser/browse_glossary.dart';

class CompanyModelSchema {
  late ModelSchema listModel;
  late ModelSchema listComponent;
  late ModelSchema listRequest;

  ModelSchema? currentModel;
  NodeAttribut? currentModelSel;
  String? currentType;

  late ModelSchema listAPI;
  ModelSchema? currentAPIResquest;
  ModelSchema? currentAPIResponse;
  APICallInfo? apiCallInfo;

  late ModelSchema listGlossary;
  late ModelSchema listGlossarySuffixPrefix;

  GlossaryManager glossaryManager = GlossaryManager();

  String companyId = 'test';
  String userId = 'gdesomer';
}

///////////////////////////////////////////////////////////////////
///
enum ChangeOpe { change, clear, rename, path, move, add, remove }

enum YamlType { allModel, model, selector, allApi, api, allGlossary }
