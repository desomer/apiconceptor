import 'package:flutter/material.dart';

class AnimatedZoneRow extends StatelessWidget {
  const AnimatedZoneRow({
    super.key,
    required this.modeNotifier,
    required this.child,
    required this.height,
  });
  final ValueNotifier<int> modeNotifier;
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: modeNotifier,
      builder: (context, value, achild) {
        return Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: modeNotifier.value == 1 ? 200 : 0,
              height: height,
              decoration:
                  modeNotifier.value == 1
                      ? BoxDecoration(border: Border.all(color: Colors.blue))
                      : null,
            ),
            Expanded(
              child: Stack(
                children: [
                  child,
                  Positioned.fill(
                    child: Container(
                      decoration:
                          modeNotifier.value != 0
                              ? BoxDecoration(
                                border: Border.all(color: Colors.amberAccent),
                                borderRadius: BorderRadius.circular(8),
                              )
                              : null,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: modeNotifier.value == 3 ? 200 : 0,
              height: height,
              decoration:
                  modeNotifier.value == 3
                      ? BoxDecoration(border: Border.all(color: Colors.blue))
                      : null,
            ),
          ],
        );
      },
    );
  }
}
