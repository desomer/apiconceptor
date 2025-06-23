import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

List<String> startError = [];

class WidgetShowError extends StatelessWidget {
  const WidgetShowError({super.key});

  @override
  Widget build(BuildContext context) {
    if (startError.isNotEmpty) {
      SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: Duration(minutes: 1),
            backgroundColor: Colors.red,

            content: Text(
              'START ERROR ${startError.first}',
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
      });
    }

    return SizedBox(width: 20, height: 20);
  }
}
