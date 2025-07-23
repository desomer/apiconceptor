import 'package:flutter/material.dart';
import 'package:jsonschema/core/model_schema.dart';
import 'package:jsonschema/feature/model/pan_model_selector.dart';
import 'package:jsonschema/main.dart';

var stateModel = StateModel();

class StateModel {
  WidgetModelSelector modelSelector = WidgetModelSelector(
    listModel: currentCompany.listModel,
    typeModel: TypeModelBreadcrumb.businessmodel,
  );

  WidgetModelSelector componentSelector = WidgetModelSelector(
    listModel: currentCompany.listComponent,
    typeModel: TypeModelBreadcrumb.component,
  );

  WidgetModelSelector requestSelector = WidgetModelSelector(
    listModel: currentCompany.listRequest,
    typeModel: TypeModelBreadcrumb.request,
  );

  GlobalKey keyModelYamlEditor = GlobalKey();
  GlobalKey keyModelEditor = GlobalKey();

  GlobalKey keyTab = GlobalKey();
  Set<int> tabDisable = {1, 2};

  GlobalKey keyBreadcrumb = GlobalKey();
  List<String> path = ["Business Model", "Select or create a model"];

  late TabController tabModel;
  late TabController tabSubModel;

  void setTab()
  {
     if (tabModel.index==0)
     {
       switch (tabSubModel.index) {
         case 0:
           stateOpenFactor?.setList(modelSelector.keyListModelInfo.currentState);
           break;
         case 1:
           stateOpenFactor?.setList(componentSelector.keyListModelInfo.currentState);
           break;
         case 2:
           stateOpenFactor?.setList(requestSelector.keyListModelInfo.currentState);
           break;                      
         default:
       }

     }      
  }
  

}
