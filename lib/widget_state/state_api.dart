import 'package:flutter/material.dart';
import 'package:jsonschema/widget/json_editor/widget_json_tree.dart';

var stateApi = StateAPI();

class StateAPI {
  GlobalKey keyListAPIYaml = GlobalKey();
  GlobalKey<JsonListEditorState> keyListAPIInfo = GlobalKey();


  GlobalKey keyTab = GlobalKey();
  Set<int> tabDisable = {1, 2};

  GlobalKey keyBreadcrumb = GlobalKey();
  List<String> path = ["API", "Select or create API"];
  List<String> urlParam = [];

  late TabController tabApi;
  late TabController tabSubApi;

  GlobalKey keyResponseStatus = GlobalKey();


  void repaintListAPI() {
    // ignore: invalid_use_of_protected_member
    keyListAPIYaml.currentState?.setState(() {});
    // ignore: invalid_use_of_protected_member
    keyListAPIInfo.currentState?.setState(() {});
  }
}
