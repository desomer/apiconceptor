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

  GlobalKey keyModelYamlEditor = GlobalKey();
  GlobalKey keyModelEditor = GlobalKey();

  GlobalKey keyTab = GlobalKey();
  Set<int> tabDisable = {1, 2};

  GlobalKey keyBreadcrumb = GlobalKey();
  List<String> path = ["Business Model", "Select or create a model"];

  late TabController tabModel;
}
