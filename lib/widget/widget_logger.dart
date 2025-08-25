import 'package:flutter/material.dart';

class LogViewer extends StatelessWidget {
  final Function fct;
  final ValueNotifier<int> change;

  const LogViewer({super.key, required this.fct, required this.change});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: ValueListenableBuilder(
        valueListenable: change,
        builder: (context, value, child) {
          List<String> logs = fct();

          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 2.0,
                  horizontal: 8.0,
                ),
                child: Text(
                  logs[index],
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
