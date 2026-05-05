import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/json_browser/browse_glossary.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/pages/content/content_map_page_detail.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_md_doc.dart';
import 'package:supabase/supabase.dart';
import 'package:collection/collection.dart';

class CompanyModelSchema {
  bool isInit = false;
  //List<String> log = [];

  ModelSchema? listEnv;
  ModelSchema? listDomain;
  ModelSchema? listDataSrc;

  ModelSchema? listModel;
  ModelSchema? currentModel;
  NodeAttribut? currentModelSel;
  String? currentType;

  ModelSchema? listAPI;
  ModelSchema? currentAPIResquest;
  ModelSchema? currentAPIResponse;

  ModelSchema? currentDataSource;
  ModelSchema? currentDataMap;
  NodeAttribut? currentDataMapSel;

  late ModelSchema listGlossary;
  late ModelSchema listGlossarySuffixPrefix;
  ModelSchema? currentApps;

  MappingEngineConfig? currentMapEngine;
  GlossaryManager glossaryManager = GlossaryManager();

  String companyId = 'test2';
  String shortUserId = '?';

  User? user;
  Map? userProfil;
  Map userAuth = {};

  Map? getRule(String category, String authId) {
    return userAuth[category]?[authId];
  }

  String get currentNameSpace {
    if (isInit && listDomain?.selectedAttr != null) {
      return listDomain!.selectedAttr!.info.masterID!;
    }
    return 'default';
  }

  Future<ModelSchema?> getModelByMasterId(
    String idDomain,
    String idModel,
  ) async {
    var listModel = await loadSchema(
      TypeMD.listmodel,
      'model',
      'Business models',
      TypeModelBreadcrumb.businessmodel,
      namespace: idDomain,
      config: BrowserConfig(),
    );
    var m = listModel.getNodeByMasterIdPath(idModel);
    if (m != null) {
      var aModel = ModelSchema(
        category: Category.model,
        infoManager: InfoManagerModel(typeMD: TypeMD.model),
        headerName: m.info.name,
        id: idModel,
        refDomain: listModel,
      );
      aModel.namespace = idDomain;
      await aModel.loadYamlAndProperties(cache: false, withProperties: true);
      //print(m);
      return aModel;
    }

    return null;
  }

  Future<ModelSchema?> getModelByName(String idDomain, String idModel) async {
    var aDomain = currentCompany.listDomain?.mapInfoByName[idDomain];
    var attr = aDomain?.firstOrNull;
    if (attr != null) {
      var listModel = await loadSchema(
        TypeMD.listmodel,
        'model',
        'Business models',
        TypeModelBreadcrumb.businessmodel,
        namespace: attr.masterID!,
        config: BrowserConfig(),
      );
      var m = listModel.mapInfoByName[idModel]?.first;
      if (m != null) {
        var aModel = ModelSchema(
          category: Category.model,
          infoManager: InfoManagerModel(typeMD: TypeMD.model),
          headerName: m.name,
          id: m.masterID!,
          refDomain: listModel,
        );
        aModel.namespace = attr.masterID!;
        await aModel.loadYamlAndProperties(cache: false, withProperties: true);
        //print(m);
        return aModel;
      }
    }

    return null;
  }

  void setDomainByMasterID(String? currentDomain, {BrowseSingle? browser}) {
    if (browser == null) {
      browser = BrowseSingle(config: BrowserConfig());
      browser.browse(currentCompany.listDomain!, false);
    }

    if (currentDomain == null) {
      currentCompany.listDomain?.setCurrentAttr(browser.root.first.info);
      prefs.setString("currentDomain", browser.root.first.info.masterID!);
    } else {
      var cur = browser.root.firstWhereOrNull(
        (element) => element.info.masterID == currentDomain,
      );
      if (cur == null) {
        currentCompany.listDomain?.setCurrentAttr(browser.root.first.info);
      } else {
        currentCompany.listDomain?.setCurrentAttr(cur.info);
      }
    }
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
  dataMap,
  apps,
}
