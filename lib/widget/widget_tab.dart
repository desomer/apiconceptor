import 'package:flutter/material.dart';
import 'package:jsonschema/main.dart';

// ignore: must_be_immutable
class WidgetTab extends StatefulWidget {
  WidgetTab({
    required this.listTab,
    required this.listTabCont,
    required this.heightTab,
    this.onInitController,
    super.key,
    this.heightContent,
    this.tabDisable
  });

  final List<Widget> listTab;
  final List<Widget> listTabCont;
  final double heightTab;
  final Function? onInitController;
  final bool? heightContent;
  final Set<int>? tabDisable;

  int saveTabIndex = 0;

  @override
  State<WidgetTab> createState() {
    return _WidgetTabState();
  }
}

class _WidgetTabState extends State<WidgetTab>
    with SingleTickerProviderStateMixin {
  late TabController controllerTab;

  @override
  void initState() {
    super.initState();
    controllerTab = TabController(
      vsync: this,
      length: widget.listTab.length,
      animationDuration: const Duration(milliseconds: 200),
    );

    controllerTab.index = widget.saveTabIndex;

    if (widget.onInitController != null) {
      widget.onInitController?.call(controllerTab);
    }

    controllerTab.addListener(() {
      if (widget.heightContent == true) setState(() {});
      widget.saveTabIndex = controllerTab.index;
    });
  }



  @override
  void dispose() {
    super.dispose();
    controllerTab.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints viewportConstraints) {
        double heightTab = widget.heightTab * (zoom.value / 100);
        if (widget.heightContent == true) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              getTabActionLayout(widget.listTab, heightTab),
              widget.listTabCont[controllerTab.index],
            ],
          );
        } else {
          var heightContent = viewportConstraints.maxHeight - heightTab - 2;

          return Column(
            children: <Widget>[
              getTabActionLayout(widget.listTab, heightTab),
              Container(
                padding: const EdgeInsets.all(0.0),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).secondaryHeaderColor,
                  ),
                ),
                height: heightContent,
                child: TabBarView(
                  controller: controllerTab,
                  children: widget.listTabCont,
                ),
              ),
            ],
          );
        }
      },
    );
  }

  bool isDisable(int idx) {
    return widget.tabDisable?.contains(idx) ?? false;
  }

  Widget getTabActionLayout(List<Widget> listTab, double heightTab) {
    var listT = <Widget>[];

    int i = 0;
    for (var element in listTab) {
      if (isDisable(i)) {
        listT.add(
          Container(
            child: DefaultTextStyle.merge(
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
              child: element,
            ),
          ),
        );
      } else {
        listT.add(element);
      }
      i++;
    }

    return SizedBox(
      height: heightTab,
      child: ColoredBox(
        color: Colors.transparent,
        child: Align(
          alignment: Alignment.centerLeft,
          child: TabBar(
            onTap: (value) {
              if (isDisable(value)) {
                setState(() {
                  controllerTab.index = controllerTab.previousIndex;
                });
              }
            },
            // indicatorSize: TabBarIndicatorSize.label,
            controller: controllerTab,
            indicator: const UnderlineTabIndicator(
              borderSide: BorderSide(width: 4, color: Colors.blue),
              insets: EdgeInsets.only(left: 0, right: 0, bottom: 0),
            ),
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelPadding: const EdgeInsets.only(left: 10, right: 10),
            tabs: listT,
          ),
        ),
      ),
    );
  }
}
