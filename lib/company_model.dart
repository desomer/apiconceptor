import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/json_browser/browse_glossary.dart';

class CompanyModelSchema {
  bool isInit = false;

  late ModelSchema listEnv;
  late ModelSchema listDomain;
  // late ModelSchema listComponent;
  // late ModelSchema listRequest;

  ModelSchema? listModel;
  ModelSchema? currentModel;
  NodeAttribut? currentModelSel;
  String? currentType;

  ModelSchema? listAPI;
  ModelSchema? currentAPIResquest;
  ModelSchema? currentAPIResponse;
  //APICallInfo? currentAPICallInfo;

  late ModelSchema listGlossary;
  late ModelSchema listGlossarySuffixPrefix;

  GlossaryManager glossaryManager = GlossaryManager();

  String companyId = 'test2';
  String get currentNameSpace {
    if (isInit && listDomain.selectedAttr != null) {
      return listDomain.selectedAttr!.info.masterID!;
    }
    return 'default';
  }

  String userId = 'gdesomer';
}

///////////////////////////////////////////////////////////////////
///
enum ChangeOpe { change, clear, rename, path, move, add, remove }

enum Category {
  allModel,
  model,
  selector,
  allApi,
  api,
  allGlossary,
  exampleApi,
  env,
  domain,
}
