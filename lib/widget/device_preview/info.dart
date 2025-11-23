import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

enum DeviceType {
  /// Unknown type
  unknown,

  /// Smartphone
  phone,

  /// Tablet
  tablet,

  /// TV
  tv,

  /// Desktop computer
  desktop,

  /// Laptop
  laptop,
}

/// Info about a device and its frame.

class DeviceIdentifier {
  /// The unique name of the device (preferably in snake case).
  final String name;

  /// The device form factor.
  final DeviceType type;

  /// The target platform supported by this device.
  final TargetPlatform platform;

  /// Private constructor.
  const DeviceIdentifier(
    this.platform,
    this.type,
    this.name,
  );

  @override
  // ignore: non_nullable_equals_parameter
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other is DeviceIdentifier &&
            other.name == name &&
            other.type == type &&
            other.platform == platform);
  }

  @override
  int get hashCode =>
      runtimeType.hashCode ^ name.hashCode ^ type.hashCode ^ platform.hashCode;

  @override
  String toString() {
    final platformKey =
        platform.toString().replaceAll('$TargetPlatform.', '').toLowerCase();
    final typeKey =
        type.toString().replaceAll('$DeviceType.', '').toLowerCase();
    return '${platformKey}_${typeKey}_$name';
  }
}

class DeviceInfo {
  /// Create a new device info.
  DeviceInfo({
    required this.identifier,
    required this.name,
    this.rotatedSafeAreas,
    required this.safeAreas,
    required this.screenPath,
    required this.pixelRatio,
    required this.framePainter,
    required this.frameSize,
    required this.screenSize,
  });

  DeviceIdentifier identifier;

  /// The display name of the device.
  String name;

  /// The safe areas when the device is in landscape orientation.
  EdgeInsets? rotatedSafeAreas;

  /// The safe areas when the device is in portrait orientation.
  EdgeInsets safeAreas;

  /// A shape representing the screen.
  Path screenPath;

  /// The screen pixel density of the device.
  double pixelRatio;

  /// The safe areas when the device is in portrait orientation.
  CustomPainter framePainter;

  /// The frame size in pixels.
  Size frameSize;

  /// The size in points of the screen content.
  Size screenSize;
}

extension DeviceInfoExtension on DeviceInfo {
  /// Indicates whether the device can rotate.
  bool get canRotate => true;

  /// Indicates whether the current device info should be in landscape.
  ///
  /// This is true only if the device can rotate.
  bool isLandscape(Orientation orientation) {
    return canRotate && orientation == Orientation.landscape;
  }
}
