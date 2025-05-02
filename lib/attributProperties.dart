import 'package:flutter/material.dart';
import 'package:jsonschema/widget_tab.dart';

class AttributProperties extends StatelessWidget {
  const AttributProperties({super.key});

  @override
  Widget build(BuildContext context) {
    return WidgetTab(listTab: [
       Tab(text: 'Detail'),
       Tab(text: 'Example'),
       Tab(text: 'Validator'), 
       Tab(text: 'Tag'),  
    ], listTabCont: [
       Container(),
       Container(),
       Container(),
       Container(),
    ], heightTab: 40);
  }
}
