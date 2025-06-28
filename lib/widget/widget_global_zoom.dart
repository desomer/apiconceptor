import 'package:cart_stepper/cart_stepper.dart';
import 'package:flutter/material.dart';
import 'package:jsonschema/main.dart';

class WidgetGlobalZoom extends StatefulWidget {
  const WidgetGlobalZoom({super.key});

  @override
  State<WidgetGlobalZoom> createState() => _WidgetGlobalZoomState();
}

class _WidgetGlobalZoomState extends State<WidgetGlobalZoom> {

  @override
  Widget build(BuildContext context) {
    return CartStepperInt(
      value: zoom.value,
      size: 20,
      stepper: 2,

      style: CartStepperTheme.of(context).copyWith(
        activeForegroundColor: Colors.white,
        activeBackgroundColor: Colors.blueGrey,
      ),
      didChangeCount: (count) {
        if (count < 80 || count > 130) return;
        setState(() {
          zoom.value = count;
          timezoom = DateTime.now().millisecondsSinceEpoch;
        });
      },
    );
  }
}
