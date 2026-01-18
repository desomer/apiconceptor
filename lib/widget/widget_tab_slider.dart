import 'package:custom_sliding_segmented_control/custom_sliding_segmented_control.dart';
import 'package:flutter/material.dart';

class WidgetTabSlider extends StatefulWidget {
  const WidgetTabSlider({
    super.key,
    this.onInitController,
    required this.listTab,
    required this.listTabCont,
  });
  final Function? onInitController;
  final List<Widget> listTab;
  final List<Widget> listTabCont;

  @override
  State<WidgetTabSlider> createState() => _WidgetTabSliderState();
}

class _WidgetTabSliderState extends State<WidgetTabSlider> {
  late CustomSegmentedController<int> controllerSlider;
  late PageController pageController;

  @override
  void initState() {
    super.initState();
    controllerSlider = CustomSegmentedController();
    pageController = PageController();

    if (widget.onInitController != null) {
      widget.onInitController?.call(controllerSlider);
    }

    controllerSlider.addListener(() {
      pageController.animateToPage(
        controllerSlider.value ?? 0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    super.dispose();
    controllerSlider.dispose();
    pageController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Map<int, Widget> tabs = {};
    for (var i = 0; i < widget.listTab.length; i++) {
      tabs[i] = widget.listTab[i];
    }
    return Column(
      children: [
        getCustomSlidingSegmentedControl(tabs, widget.listTabCont, context),
        Expanded(
          child: PageView(
            controller: pageController,
            children: widget.listTabCont,
          ),
        ),
      ],
    );
  }

  Widget getCustomSlidingSegmentedControl(
    Map<int, Widget> tabs,
    List<Widget> tabsView,
    BuildContext context,
  ) {
    return CustomSlidingSegmentedControl<int>(
      //initialValue: 2,
      children: tabs,
      innerPadding: EdgeInsets.all(2),
      controller: controllerSlider,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Theme.of(context).colorScheme.secondaryContainer, width: 2),
      ),
      thumbDecoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 4.0,
            spreadRadius: 1.0,
            offset: Offset(0.0, 2.0),
          ),
        ],
      ),
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInToLinear,
      onValueChanged: (v) {},
    );
  }
}
