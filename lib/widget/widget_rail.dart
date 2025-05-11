import 'package:flutter/material.dart';

// ignore: must_be_immutable
class WidgetRail extends StatefulWidget {
  WidgetRail({
    required this.listTab,
    required this.listTabCont,
    required this.heightTab,
    this.onInitController,
    super.key,
    this.heightContent,
  });

  final List<NavigationRailDestination> listTab;
  final List<Widget> listTabCont;
  final double heightTab;
  final Function? onInitController;
  final bool? heightContent;

  int saveTabIndex = 0;

  @override
  State<WidgetRail> createState() {
    return _WidgetRailState();
  }
}

class _WidgetRailState extends State<WidgetRail>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;

  @override
  void initState() {
    _pageController = PageController(
      initialPage: 0,
      viewportFraction: 1,
      keepPage: true,
    );
    super.initState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _selectedIndex = 0;
  NavigationRailLabelType labelType = NavigationRailLabelType.all;
  double groupAlignment = -1.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints viewportConstraints) {
        return Row(
          children: <Widget>[
            NavigationRail(
              selectedIndex: _selectedIndex,
              groupAlignment: groupAlignment,
              onDestinationSelected: (int index) {
                setState(() {
                  _selectedIndex = index;
                  _pageController.jumpToPage(index);
                });
              },
              labelType: labelType,
              destinations: widget.listTab,
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: PageView(
                controller: _pageController,
                children: widget.listTabCont,
              ),
            ),
          ],
        );
      },
    );
  }
}
