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
                child: Text('COMPLIANT MODEL'),
              ),
            ),
          );
        }
        return isError
            ? SizedBox(
              width: double.infinity,
              child: Card(
                color: Colors.red,
                child: getDoubleScroll(
                  IntrinsicWidth(
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 15),
                        child: SelectableText(value),
                      ),
                    ),
                  ),
                ),
              ),
            )
            : Container();
      },
    );
  }

  final ScrollController _horizontal = ScrollController(),
      _vertical = ScrollController();

  Widget getDoubleScroll(Widget child) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: 200, minHeight: 100),
      child: Scrollbar(
        controller: _vertical,
        thumbVisibility: true,
        trackVisibility: true,
        child: Scrollbar(
          controller: _horizontal,
          thumbVisibility: true,
          trackVisibility: true,
          notificationPredicate: (notif) => notif.depth == 1,
          child: SingleChildScrollView(
            controller: _vertical,
            child: SingleChildScrollView(
              controller: _horizontal,
              scrollDirection: Axis.horizontal,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
