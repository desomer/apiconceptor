import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/json_browser/browse_glossary.dart';

class CompanyModelSchema {
  bool isInit = false;
  List<String> log = [];

  late ModelSchema listEnv;
  late ModelSchema listDomain;
  ModelSchema? listPage;

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
  String userId = 'gdesomer';
  
  String get currentNameSpace {
    if (isInit && listDomain.selectedAttr != null) {
      return listDomain.selectedAttr!.info.masterID!;
    }
    return 'default';
  }


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
  variable,
}
