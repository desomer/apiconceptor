import 'package:flutter/material.dart';
import 'package:jsonschema/core/api/call_api_manager.dart';
import 'package:jsonschema/core/api/sessionStorage.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/core/designer/core/cw_repository.dart';
import 'package:jsonschema/core/designer/core/cw_widget.dart';
import 'package:jsonschema/core/export/export2json_fake.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/core/util.dart';
import 'package:jsonschema/json_browser/browse_model.dart';
import 'package:jsonschema/pages/router_layout.dart';
import 'package:jsonschema/start_core.dart';

class CwRepositoryAction {
  final CwWidgetCtx ctx;
  final CwRepository repo;

  CwRepositoryAction({required this.ctx, required this.repo});

  void doNextPage(Map info, int max) {
    var criteria = repo.criteriaState.data;
    var paginationVariable = repo.ds.configApp.criteria.paginationVariable!;

    var page = findValueByKey(criteria, paginationVariable);
    dynamic numpage = 0;
    if (page is String) {
      numpage = int.tryParse(page) ?? 0;
      numpage = numpage + 1;
      if (numpage >= max) numpage = max;
      numpage = "$numpage";
    } else {
      numpage = page;
      numpage = numpage + 1;
      if (numpage >= max) numpage = max;
    }

    findValueByKey(criteria, paginationVariable, valueToSet: numpage);
    repo.criteriaState.loadDataInContainer(criteria);
  }

  void doPrevPage(Map info, int min) {
    var criteria = repo.criteriaState.data;
    var paginationVariable = repo.ds.configApp.criteria.paginationVariable!;
    var page = findValueByKey(criteria, paginationVariable);
    dynamic numpage = 0;
    if (page is String) {
      numpage = int.tryParse(page) ?? 0;
      numpage = numpage - 1;
      if (numpage <= min) numpage = min;
      numpage = "$numpage";
    } else {
      numpage = page;
      numpage = numpage - 1;
      if (numpage <= min) numpage = min;
    }

    findValueByKey(criteria, paginationVariable, valueToSet: numpage);
    repo.criteriaState.loadDataInContainer(criteria);
  }

  void loadCriteria(Map info) async {
    APICallManager apiCallInfo = repo.ds.helper!.apiCallInfo;
    AttributInfo? element = repo.ds.exampleData?.firstWhere(
      (e) => e.masterID == info['idParam'],
    );
    if (element == null) return;

    apiCallInfo.selectedExample = element;
    var jsonParam = await bddStorage.getAPIParam(
      apiCallInfo.currentAPIRequest!,
      element.masterID!,
    );

    apiCallInfo.clearRequest();

    if (jsonParam != null) {
      apiCallInfo.initWithParamJson(jsonParam);
      var data = repo.criteriaState.data;
      for (var element in apiCallInfo.params) {
        if (element.toSend) {
          data[element.type][element.name] = element.value;
        } else {
          data[element.type][element.name] =
              repo.criteriaState.dataEmpty[element.type][element.name];
        }
      }
      if (data != null) {
        // recharge les bonnes datas
        repo.criteriaState.loadDataInContainer(data);
      }
    }
  }

  void loadData(BuildContext context, {String? paramSessionId}) async {
    var h = repo.ds.helper!;
    repo.dataState.clearDisplayedData();

    if (paramSessionId != null) {
      // affecte la session du parent
      h.apiCallInfo.parentData = sessionStorage.get(paramSessionId);
    }

    if (dataProviderMode.value == 'mock') {
      var browserEmpty = Export2FakeJson(
        modeArray: ModeArrayEnum.randomInstance,
        mode: ModeEnum.fake,
      );
      await browserEmpty.browseSync(repo.dataState.schema!, false, 0);
      var data = browserEmpty.json;
      repo.dataState.data = data;
      repo.dataState.loadDataInContainer(data);
      return;
    }

    // ignore: use_build_context_synchronously
    h.startCancellableSearch(
      context,
      repo.criteriaState.data,
      () {
        var data = h.apiCallInfo.aResponse?.reponse?.data;
        repo.dataState.data = data;
        repo.dataState.loadDataInContainer(data);
      },
      onRequestError: () async {
        var browserEmpty = Export2FakeJson(
          modeArray: ModeArrayEnum.randomInstance,
          mode: ModeEnum.fake,
        );
        await browserEmpty.browseSync(repo.dataState.schema!, false, 0);
        var data = browserEmpty.json;
        repo.dataState.data = data;
        repo.dataState.loadDataInContainer(data);
      },
    );
  }

  Future<String?> getLinkDataInSession(Map<String, dynamic> link) async {
    var pages = await loadDataSource("all", false);
    BrowseSingle().browse(pages, false);
    String toDatasrc = link['linkTo'];
    String pathValue = link['onPath'];
    var attr = pages.mapInfoByName[toDatasrc];
    if (attr?.isNotEmpty ?? false) {
      var pth = pathValue.replaceAll("[*]", "[]");

      String pathSelected;
      (_, pathSelected) = repo.dataState.getStateContainer(pth);

      PageData pageData = PageData(
        data: repo.dataState.data,
        path: pathSelected,
      );

      print(
        'assign link data to session ${pageData.hashCode}, path=$pathSelected',
      );
      var key = '${pageData.hashCode}';
      sessionStorage.put(key, pageData);
      return key;
    }
    return null;
  }

  void goToPage(BuildContext context, int page) {
    var criteria = repo.criteriaState.data;
    var paginationVariable = repo.ds.configApp.criteria.paginationVariable!;

    findValueByKey(criteria, paginationVariable, valueToSet: page);
    repo.criteriaState.loadDataInContainer(criteria);
    loadData(context);
  }
}
