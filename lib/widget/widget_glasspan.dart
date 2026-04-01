import 'package:flutter/material.dart';

mixin GlassPaneMixin {
  OverlayEntry? blocker;

  void showGlassPane(BuildContext context) {
    blocker = OverlayEntry(
      builder:
          (_) => Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: Container(
                color: Colors.black.withAlpha(150), // effet verre
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
    );

    Overlay.of(context).insert(blocker!);
  }

  void hideGlassPane() {
    blocker?.remove();
    blocker = null;
  }
}
