import 'package:flutter/material.dart';
import 'info.dart';


final deviceS20 = DeviceInfo(
  identifier: const DeviceIdentifier(
    TargetPlatform.android,
    DeviceType.phone,
    'samsung-galaxy-s20',
  ),
  name: 'Samsung Galaxy S20',
  pixelRatio: 4.0,
  safeAreas: const EdgeInsets.only(
    left: 0.0,
    top: 32.0,
    right: 0.0,
    bottom: 32.0,
  ),
  rotatedSafeAreas: const EdgeInsets.only(
    left: 32.0,
    top: 24.0,
    right: 32.0,
    bottom: 0.0,
  ),
  framePainter: const _FramePainter(),
  screenPath: _screenPath,
  frameSize: const Size(856.54, 1899.0),
  screenSize: const Size(360.0, 800.0),
);

class _FramePainter extends CustomPainter {
  const _FramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path_0 = Path();
    path_0.moveTo(858.755, 345.272);
    path_0.lineTo(860.968, 345.272);
    path_0.cubicTo(863.413, 345.272, 865.395, 347.325, 865.395, 349.857);
    path_0.lineTo(865.395, 577.509);
    path_0.cubicTo(865.395, 580.041, 863.413, 582.094, 860.968, 582.094);
    path_0.lineTo(858.755, 582.094);
    path_0.lineTo(858.755, 345.272);
    path_0.close();

    final paint0Fill = Paint()..style = PaintingStyle.fill;
    paint0Fill.color = const Color(0xff121515);
    canvas.drawPath(path_0, paint0Fill);

    final path_1 = Path();
    path_1.moveTo(858.755, 710.465);
    path_1.lineTo(860.968, 710.465);
    path_1.cubicTo(863.413, 710.465, 865.395, 712.517, 865.395, 715.05);
    path_1.lineTo(865.395, 829.824);
    path_1.cubicTo(865.395, 832.356, 863.413, 834.409, 860.968, 834.409);
    path_1.lineTo(858.755, 834.409);
    path_1.lineTo(858.755, 710.465);
    path_1.close();

    final paint1Fill = Paint()..style = PaintingStyle.fill;
    paint1Fill.color = const Color(0xff121515);
    canvas.drawPath(path_1, paint1Fill);

    final path_2 = Path();
    path_2.moveTo(0, 193.441);
    path_2.cubicTo(0, 107.314, 0, 64.2511, 24.3934, 35.6901);
    path_2.cubicTo(27.8572, 31.6344, 31.6344, 27.8572, 35.6901, 24.3934);
    path_2.cubicTo(64.2511, 0, 107.314, 0, 193.441, 0);
    path_2.lineTo(665.314, 0);
    path_2.cubicTo(751.441, 0, 794.504, 0, 823.065, 24.3934);
    path_2.cubicTo(827.121, 27.8572, 830.898, 31.6344, 834.362, 35.6901);
    path_2.cubicTo(858.755, 64.2511, 858.755, 107.314, 858.755, 193.441);
    path_2.lineTo(858.755, 1705.56);
    path_2.cubicTo(858.755, 1791.69, 858.755, 1834.75, 834.362, 1863.31);
    path_2.cubicTo(830.898, 1867.37, 827.121, 1871.14, 823.065, 1874.61);
    path_2.cubicTo(794.504, 1899, 751.441, 1899, 665.314, 1899);
    path_2.lineTo(193.441, 1899);
    path_2.cubicTo(107.314, 1899, 64.2511, 1899, 35.6901, 1874.61);
    path_2.cubicTo(31.6344, 1871.14, 27.8572, 1867.37, 24.3934, 1863.31);
    path_2.cubicTo(0, 1834.75, 0, 1791.69, 0, 1705.56);
    path_2.lineTo(0, 193.441);
    path_2.close();

    final paint2Fill = Paint()..style = PaintingStyle.fill;
    paint2Fill.color = const Color(0xff3A4245);
    canvas.drawPath(path_2, paint2Fill);

    final path_3 = Path();
    path_3.moveTo(4.42676, 178.944);
    path_3.cubicTo(4.42676, 106.544, 4.42676, 70.3436, 23.9081, 45.6316);
    path_3.cubicTo(28.3256, 40.0281, 33.3885, 34.9652, 38.992, 30.5478);
    path_3.cubicTo(63.704, 11.0664, 99.9042, 11.0664, 172.305, 11.0664);
    path_3.lineTo(686.451, 11.0664);
    path_3.cubicTo(758.851, 11.0664, 795.052, 11.0664, 819.764, 30.5478);
    path_3.cubicTo(825.367, 34.9652, 830.43, 40.0281, 834.847, 45.6316);
    path_3.cubicTo(854.329, 70.3436, 854.329, 106.544, 854.329, 178.944);
    path_3.lineTo(854.329, 1720.06);
    path_3.cubicTo(854.329, 1792.46, 854.329, 1828.66, 834.847, 1853.37);
    path_3.cubicTo(830.43, 1858.97, 825.367, 1864.03, 819.764, 1868.45);
    path_3.cubicTo(795.052, 1887.93, 758.851, 1887.93, 686.451, 1887.93);
    path_3.lineTo(172.305, 1887.93);
    path_3.cubicTo(99.9042, 1887.93, 63.704, 1887.93, 38.992, 1868.45);
    path_3.cubicTo(33.3885, 1864.03, 28.3256, 1858.97, 23.9081, 1853.37);
    path_3.cubicTo(4.42676, 1828.66, 4.42676, 1792.46, 4.42676, 1720.06);
    path_3.lineTo(4.42676, 178.944);
    path_3.close();

    final paint3Fill = Paint()..style = PaintingStyle.fill;
    paint3Fill.color = const Color(0xff121515);
    canvas.drawPath(path_3, paint3Fill);

    final path_4 = Path();
    path_4.moveTo(424.951, 90.7447);
    path_4.cubicTo(437.175, 90.7447, 447.084, 80.8355, 447.084, 68.6119);
    path_4.cubicTo(447.084, 56.3882, 437.175, 46.479, 424.951, 46.479);
    path_4.cubicTo(412.728, 46.479, 402.818, 56.3882, 402.818, 68.6119);
    path_4.cubicTo(402.818, 80.8355, 412.728, 90.7447, 424.951, 90.7447);
    path_4.close();

    final paint4Fill = Paint()..style = PaintingStyle.fill;
    paint4Fill.color = const Color(0xff262C2D);
    canvas.drawPath(path_4, paint4Fill);

    final path_5 = Path();
    path_5.moveTo(424.951, 82.4449);
    path_5.cubicTo(432.591, 82.4449, 438.784, 76.2516, 438.784, 68.6118);
    path_5.cubicTo(438.784, 60.9721, 432.591, 54.7788, 424.951, 54.7788);
    path_5.cubicTo(417.311, 54.7788, 411.118, 60.9721, 411.118, 68.6118);
    path_5.cubicTo(411.118, 76.2516, 417.311, 82.4449, 424.951, 82.4449);
    path_5.close();

    final paint5Fill = Paint()..style = PaintingStyle.fill;
    paint5Fill.color = const Color(0xff121515);
    canvas.drawPath(path_5, paint5Fill);

    final path_6 = Path();
    path_6.moveTo(424.951, 65.8452);
    path_6.cubicTo(426.479, 65.8452, 427.718, 64.6066, 427.718, 63.0786);
    path_6.cubicTo(427.718, 61.5507, 426.479, 60.312, 424.951, 60.312);
    path_6.cubicTo(423.423, 60.312, 422.185, 61.5507, 422.185, 63.0786);
    path_6.cubicTo(422.185, 64.6066, 423.423, 65.8452, 424.951, 65.8452);
    path_6.close();

    final paint6Fill = Paint()..style = PaintingStyle.fill;
    paint6Fill.color = const Color(0xff636F73);
    canvas.drawPath(path_6, paint6Fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

final _screenPath = Path()
  ..moveTo(19.9199, 110.664)
  ..cubicTo(19.9199, 67.8815, 54.6022, 33.1992, 97.385, 33.1992)
  ..lineTo(761.371, 33.1992)
  ..cubicTo(804.154, 33.1992, 838.836, 67.8815, 838.836, 110.664)
  ..lineTo(838.836, 1775.06)
  ..cubicTo(838.836, 1817.84, 804.154, 1852.52, 761.371, 1852.52)
  ..lineTo(97.385, 1852.52)
  ..cubicTo(54.6022, 1852.52, 19.9199, 1817.84, 19.9199, 1775.06)
  ..lineTo(19.9199, 110.664)
  ..close()
  ..moveTo(425.133, 91.2657)
  ..cubicTo(437.357, 91.2657, 447.266, 81.3565, 447.266, 69.1329)
  ..cubicTo(447.266, 56.9092, 437.357, 47, 425.133, 47)
  ..cubicTo(412.909, 47, 403, 56.9092, 403, 69.1329)
  ..cubicTo(403, 81.3565, 412.909, 91.2657, 425.133, 91.2657)
  ..close()
  ..fillType = PathFillType.evenOdd;