import 'package:flutter/material.dart';
import 'package:jsonschema/widget/tree_editor/widget_json_tree.dart';

var stateApi = StateAPI();

class StateAPI {
  GlobalKey keyListAPIYaml = GlobalKey();
  GlobalKey<JsonListEditorState> keyListAPIInfo = GlobalKey();


  GlobalKey keyTab = GlobalKey();
  Set<int> tabDisable = {1};


  List<String> urlParam = [];

  TabController? tabApi;
  TabController? tabSubApi;

  GlobalKey keyResponseStatus = GlobalKey();


  void repaintListAPI() {
    // ignore: invalid_use_of_protected_member
    keyListAPIYaml.currentState?.setState(() {});
    // ignore: invalid_use_of_protected_member
    keyListAPIInfo.currentState?.setState(() {});
  }
}
