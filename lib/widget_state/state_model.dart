import 'package:flutter/material.dart';

var stateModel = StateModel();

class StateModel {
  GlobalKey keyListModel = GlobalKey();
  GlobalKey keyListModelInfo = GlobalKey();
  GlobalKey keyModelYamlEditor = GlobalKey();
  GlobalKey keyTreeModelInfo = GlobalKey();

  GlobalKey keyTab = GlobalKey();
  Set<int> tabDisable = {1, 2};

  GlobalKey keyBreadcrumb = GlobalKey();
  List<String> path = ["Business Model", "Select or create a model"];

  late TabController tabModel;
}
