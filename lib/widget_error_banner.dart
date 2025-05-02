import 'package:flutter/material.dart';

class WidgetErrorBanner extends StatefulWidget {
  const WidgetErrorBanner({super.key, required this.error});
  final ValueNotifier<String> error;

  @override
  State<WidgetErrorBanner> createState() => _WidgetErrorBannerState();
}

class _WidgetErrorBannerState extends State<WidgetErrorBanner> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      width: double.infinity,
      child: ValueListenableBuilder<String>(
        valueListenable: widget.error,
        builder: (BuildContext context, String value, child) {
          return  widget.error.value =='' ? Container() : Card(color: Colors.red, child: Text('error'));
        },
      ),
    );
  }
}
