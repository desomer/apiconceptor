import 'package:flutter/material.dart';
import 'package:jsonschema/feature/model/pan_model_selector.dart';

var stateModel = StateModel();

class StateModel {
  PanModelSelector? panModelSelector;

  // WidgetModelSelector modelSelector = WidgetModelSelector(
  //   listModel: currentCompany.listModel,
  //   typeModel: TypeModelBreadcrumb.businessmodel,
  // );

  // PanModelSelector panComponentSelector = PanModelSelector(
  //   getSchemaFct: () {
  //     currentCompany.listComponent.typeBreabcrumb =
  //         TypeModelBreadcrumb.component;
  //     return currentCompany.listComponent;
  //   },
  // );

  // PanModelSelector panDtoSelector = PanModelSelector(
  //   getSchemaFct: () {
  //     currentCompany.listRequest.typeBreabcrumb = TypeModelBreadcrumb.request;
  //     return currentCompany.listRequest;
  //   },
  // );

  // WidgetModelSelector componentSelector = WidgetModelSelector(
  //   listModel: currentCompany.listComponent,
  //   typeModel: TypeModelBreadcrumb.component,
  // );

  // WidgetModelSelector requestSelector = WidgetModelSelector(
  //   listModel: currentCompany.listRequest,
  //   typeModel: TypeModelBreadcrumb.request,
  // );

  GlobalKey keyModelYamlEditor = GlobalKey();
  GlobalKey keyModelEditor = GlobalKey();

  GlobalKey keyTab = GlobalKey();
  Set<int> tabDisable = {1, 2};

  GlobalKey keyBreadcrumb = GlobalKey();
  List<String> path = ["Business Model", "Select or create a model"];

  late TabController tabModel;
  late TabController tabSubModel;

  void setTab() {
    if (tabModel.index == 0) {
      switch (tabSubModel.index) {
        //  case 0:
        //    stateOpenFactor?.setList(modelSelector.keyListModelInfo.currentState);
        //    break;
        //  case 1:
        //    stateOpenFactor?.setList(componentSelector.keyListModelInfo.currentState);
        //    break;
        //  case 2:
        //    stateOpenFactor?.setList(requestSelector.keyListModelInfo.currentState);
        //    break;
        default:
      }
    }
  }
}
