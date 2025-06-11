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
    return ValueListenableBuilder<String>(
      valueListenable: widget.error,
      builder: (BuildContext context, String value, child) {
        bool isValid = widget.error.value == '_VALID_';
        bool isError = widget.error.value != '';
        if (isValid) {
          return SizedBox(
            height: 30,
            width: double.infinity,
            child: Card(
              color: Colors.green,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 15),
                child: Text('COMPLIANT JSON'),
              ),
            ),
          );
        }
        return isError
            ? SizedBox(
              width: double.infinity,
              child: IntrinsicHeight(
                child: Card(
                  color: Colors.red,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    child: Text(value),
                  ),
                ),
              ),
            )
            : Container();
      },
    );
  }
}
