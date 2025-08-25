import 'package:flutter/material.dart';

void showFloatingNotification(
  BuildContext context,
  Offset position,
  Size size,
  Widget content,
) {
  OverlayState overlayState = Overlay.of(context);
  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) {
      return Positioned(
        left: position.dx,
        top: position.dy,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: Colors.grey, width: 1),
          ),
          width: size.width,
          height: size.height,
          child: Column(
            children: [
              GestureDetector(
                onPanUpdate: (details) {
                  position += details.delta;
                  overlayEntry.markNeedsBuild(); // Met à jour la position
                },
                child: Container(
                  height: 30,
                  color: Colors.blue,
                  child: Row(
                    children: [
                      Icon(Icons.drag_indicator, color: Colors.white),
                      Spacer(),
                      InkWell(
                        child: Icon(Icons.close, color: Colors.white),
                        onTap: () {
                          overlayEntry.remove();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(child: content),
            ],
          ),
        ),
      );
    },
  );

  overlayState.insert(overlayEntry);

  // Retirer automatiquement après 5 secondes (optionnel)
  // Future.delayed(Duration(seconds: 5), () {
  //   if (overlayEntry.mounted) overlayEntry.remove();
  // });
}
