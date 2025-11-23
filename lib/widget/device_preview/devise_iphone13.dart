
import 'package:flutter/material.dart';
import 'package:jsonschema/widget/device_preview/info.dart';


final deviceIphone = DeviceInfo(
  identifier: const DeviceIdentifier(
    TargetPlatform.iOS,
    DeviceType.phone,
    'iphone-13',
  ),
  name: 'iPhone 13',
  pixelRatio: 3.0,
  frameSize: const Size(873.0, 1771.0),
  screenSize: const Size(390.0, 844.0),
  safeAreas: const EdgeInsets.only(
    left: 0.0,
    top: 30.0,
    right: 0.0,
    bottom: 34.0,
  ),
  rotatedSafeAreas: const EdgeInsets.only(
    left: 47.0,
    top: 0.0,
    right: 47.0,
    bottom: 21.0,
  ),
  framePainter: const _FramePainter(),
  screenPath: _screenPath,
);

class _FramePainter extends CustomPainter {
  const _FramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path_0 = Path();
    path_0.moveTo(866.809, 454.042);
    path_0.lineTo(869.904, 454.042);
    path_0.cubicTo(871.614, 454.042, 873, 455.428, 873, 457.138);
    path_0.lineTo(873, 659.394);
    path_0.cubicTo(873, 661.103, 871.614, 662.489, 869.904, 662.489);
    path_0.lineTo(866.809, 662.489);
    path_0.lineTo(866.809, 454.042);
    path_0.close();

    final paint0Fill = Paint()..style = PaintingStyle.fill;
    paint0Fill.color = const Color(0xff1C3343);
    canvas.drawPath(path_0, paint0Fill);

    final path_1 = Path();
    path_1.moveTo(6.19141, 705.83);
    path_1.lineTo(3.09565, 705.83);
    path_1.cubicTo(1.38592, 705.83, 0, 704.444, 0, 702.734);
    path_1.lineTo(0, 580.968);
    path_1.cubicTo(0, 579.258, 1.38593, 577.872, 3.09566, 577.872);
    path_1.lineTo(6.19142, 577.872);
    path_1.lineTo(6.19141, 705.83);
    path_1.close();

    final paint1Fill = Paint()..style = PaintingStyle.fill;
    paint1Fill.color = const Color(0xff1C3343);
    canvas.drawPath(path_1, paint1Fill);

    final path_2 = Path();
    path_2.moveTo(6.19141, 536.596);
    path_2.lineTo(3.09565, 536.596);
    path_2.cubicTo(1.38592, 536.596, 0, 535.21, 0, 533.5);
    path_2.lineTo(0, 411.734);
    path_2.cubicTo(0, 410.024, 1.38593, 408.638, 3.09566, 408.638);
    path_2.lineTo(6.19142, 408.638);
    path_2.lineTo(6.19141, 536.596);
    path_2.close();

    final paint2Fill = Paint()..style = PaintingStyle.fill;
    paint2Fill.color = const Color(0xff213744);
    canvas.drawPath(path_2, paint2Fill);

    final path_3 = Path();
    path_3.moveTo(6.19141, 346.723);
    path_3.lineTo(3.09566, 346.723);
    path_3.cubicTo(1.38592, 346.723, 0, 345.337, 0, 343.628);
    path_3.lineTo(0, 283.777);
    path_3.cubicTo(0, 282.067, 1.38593, 280.681, 3.09566, 280.681);
    path_3.lineTo(6.19141, 280.681);
    path_3.lineTo(6.19141, 346.723);
    path_3.close();

    final paint3Fill = Paint()..style = PaintingStyle.fill;
    paint3Fill.color = const Color(0xff213744);
    canvas.drawPath(path_3, paint3Fill);

    final path_4 = Path();
    path_4.moveTo(6.19141, 187.809);
    path_4.cubicTo(6.19141, 137.871, 6.19141, 112.902, 12.7571, 92.6946);
    path_4.cubicTo(26.0269, 51.8546, 58.046, 19.8354, 98.886, 6.56572);
    path_4.cubicTo(119.093, 0, 144.062, 0, 194, 0);
    path_4.lineTo(679, 0);
    path_4.cubicTo(728.938, 0, 753.907, 0, 774.114, 6.56572);
    path_4.cubicTo(814.954, 19.8354, 846.973, 51.8546, 860.243, 92.6946);
    path_4.cubicTo(866.808, 112.902, 866.808, 137.871, 866.808, 187.809);
    path_4.lineTo(866.808, 1582.96);
    path_4.cubicTo(866.808, 1632.9, 866.808, 1657.86, 860.243, 1678.07);
    path_4.cubicTo(846.973, 1718.91, 814.954, 1750.93, 774.114, 1764.2);
    path_4.cubicTo(753.907, 1770.77, 728.938, 1770.77, 679, 1770.77);
    path_4.lineTo(194, 1770.77);
    path_4.cubicTo(144.062, 1770.77, 119.093, 1770.77, 98.886, 1764.2);
    path_4.cubicTo(58.046, 1750.93, 26.0269, 1718.91, 12.7571, 1678.07);
    path_4.cubicTo(6.19141, 1657.86, 6.19141, 1632.9, 6.19141, 1582.96);
    path_4.lineTo(6.19141, 187.809);
    path_4.close();

    final paint4Fill = Paint()..style = PaintingStyle.fill;
    paint4Fill.color = const Color(0xff213744);
    canvas.drawPath(path_4, paint4Fill);

    final path_5 = Path();
    path_5.moveTo(679.825, 4.12755);
    path_5.lineTo(193.174, 4.12755);
    path_5.cubicTo(143.844, 4.12755, 119.668, 4.15301, 100.161, 10.4912);
    path_5.cubicTo(60.5778, 23.3527, 29.5438, 54.3866, 16.6824, 93.97);
    path_5.cubicTo(10.3442, 113.477, 10.3187, 137.653, 10.3187, 186.983);
    path_5.lineTo(10.3187, 1583.78);
    path_5.cubicTo(10.3187, 1633.11, 10.3442, 1657.29, 16.6824, 1676.8);
    path_5.cubicTo(29.5438, 1716.38, 60.5778, 1747.41, 100.161, 1760.27);
    path_5.cubicTo(119.668, 1766.61, 143.844, 1766.64, 193.174, 1766.64);
    path_5.lineTo(679.825, 1766.64);
    path_5.cubicTo(729.155, 1766.64, 753.331, 1766.61, 772.838, 1760.27);
    path_5.cubicTo(812.421, 1747.41, 843.455, 1716.38, 856.317, 1676.8);
    path_5.cubicTo(862.655, 1657.29, 862.68, 1633.11, 862.68, 1583.78);
    path_5.lineTo(862.68, 186.983);
    path_5.cubicTo(862.68, 137.653, 862.655, 113.477, 856.317, 93.97);
    path_5.cubicTo(843.455, 54.3866, 812.421, 23.3527, 772.838, 10.4912);
    path_5.cubicTo(753.331, 4.15301, 729.155, 4.12755, 679.825, 4.12755);
    path_5.close();
    path_5.moveTo(14.7196, 93.3323);
    path_5.cubicTo(8.25488, 113.229, 8.25488, 137.813, 8.25488, 186.983);
    path_5.lineTo(8.25488, 1583.78);
    path_5.cubicTo(8.25488, 1632.95, 8.25488, 1657.54, 14.7196, 1677.43);
    path_5.cubicTo(27.7852, 1717.65, 59.3117, 1749.17, 99.5235, 1762.24);
    path_5.cubicTo(119.42, 1768.7, 144.005, 1768.7, 193.174, 1768.7);
    path_5.lineTo(679.825, 1768.7);
    path_5.cubicTo(728.995, 1768.7, 753.579, 1768.7, 773.476, 1762.24);
    path_5.cubicTo(813.687, 1749.17, 845.214, 1717.65, 858.28, 1677.43);
    path_5.cubicTo(864.744, 1657.54, 864.744, 1632.95, 864.744, 1583.78);
    path_5.lineTo(864.744, 186.983);
    path_5.cubicTo(864.744, 137.813, 864.744, 113.229, 858.28, 93.3323);
    path_5.cubicTo(845.214, 53.1206, 813.687, 21.594, 773.476, 8.52843);
    path_5.cubicTo(753.579, 2.06372, 728.995, 2.06372, 679.825, 2.06372);
    path_5.lineTo(193.174, 2.06372);
    path_5.cubicTo(144.005, 2.06372, 119.42, 2.06372, 99.5235, 8.52843);
    path_5.cubicTo(59.3117, 21.594, 27.7852, 53.1206, 14.7196, 93.3323);
    path_5.close();

    final paint5Fill = Paint()..style = PaintingStyle.fill;
    paint5Fill.color = const Color(0xff8EADC1);
    canvas.drawPath(path_5, paint5Fill);

    final path_6 = Path();
    path_6.moveTo(16.5107, 183.681);
    path_6.cubicTo(16.5107, 137.584, 16.5107, 114.536, 22.5714, 95.8834);
    path_6.cubicTo(34.8204, 58.1849, 64.3765, 28.6287, 102.075, 16.3798);
    path_6.cubicTo(120.728, 10.3191, 143.776, 10.3191, 189.872, 10.3191);
    path_6.lineTo(683.128, 10.3191);
    path_6.cubicTo(729.224, 10.3191, 752.272, 10.3191, 770.925, 16.3798);
    path_6.cubicTo(808.624, 28.6287, 838.18, 58.1849, 850.429, 95.8834);
    path_6.cubicTo(856.49, 114.536, 856.49, 137.584, 856.49, 183.681);
    path_6.lineTo(856.49, 1587.09);
    path_6.cubicTo(856.49, 1633.18, 856.49, 1656.23, 850.429, 1674.88);
    path_6.cubicTo(838.18, 1712.58, 808.624, 1742.14, 770.925, 1754.39);
    path_6.cubicTo(752.272, 1760.45, 729.224, 1760.45, 683.128, 1760.45);
    path_6.lineTo(189.872, 1760.45);
    path_6.cubicTo(143.776, 1760.45, 120.728, 1760.45, 102.075, 1754.39);
    path_6.cubicTo(64.3765, 1742.14, 34.8204, 1712.58, 22.5714, 1674.88);
    path_6.cubicTo(16.5107, 1656.23, 16.5107, 1633.18, 16.5107, 1587.09);
    path_6.lineTo(16.5107, 183.681);
    path_6.close();

    final paint6Fill = Paint()..style = PaintingStyle.fill;
    paint6Fill.color = const Color(0xff121515);
    canvas.drawPath(path_6, paint6Fill);

    final path_7 = Path();
    path_7.moveTo(365, 10);
    path_7.lineTo(506, 10);
    path_7.lineTo(506, 14);
    path_7.cubicTo(506, 18.4183, 502.418, 22, 498, 22);
    path_7.lineTo(373, 22);
    path_7.cubicTo(368.582, 22, 365, 18.4183, 365, 14);
    path_7.lineTo(365, 10);
    path_7.close();

    final paint7Fill = Paint()..style = PaintingStyle.fill;
    paint7Fill.color = const Color(0xff262C2D);
    canvas.drawPath(path_7, paint7Fill);

    final paint8Fill = Paint()..style = PaintingStyle.fill;
    paint8Fill.color = const Color(0xff36454C);
    canvas.drawRect(
        Rect.fromLTWH(size.width * 0.7825063, 0, size.width * 0.01418442,
            size.height * 0.005826708),
        paint8Fill);

    final paint9Fill = Paint()..style = PaintingStyle.fill;
    paint9Fill.color = const Color(0xff36454C);
    canvas.drawRect(
        Rect.fromLTWH(size.width * 0.9810871, size.height * 0.1002196,
            size.width * 0.01182027, size.height * 0.006992095),
        paint9Fill);

    final paint10Fill = Paint()..style = PaintingStyle.fill;
    paint10Fill.color = const Color(0xff36454C);
    canvas.drawRect(
        Rect.fromLTWH(size.width * 0.007092108, size.height * 0.1002196,
            size.width * 0.01182027, size.height * 0.006992095),
        paint10Fill);

    final paint11Fill = Paint()..style = PaintingStyle.fill;
    paint11Fill.color = const Color(0xff36454C);
    canvas.drawRect(
        Rect.fromLTWH(size.width * 0.007092108, size.height * 0.8926539,
            size.width * 0.01182027, size.height * 0.006992095),
        paint11Fill);

    final paint12Fill = Paint()..style = PaintingStyle.fill;
    paint12Fill.color = const Color(0xff36454C);
    canvas.drawRect(
        Rect.fromLTWH(size.width * 0.9810871, size.height * 0.8926539,
            size.width * 0.01182027, size.height * 0.006992095),
        paint12Fill);

    final paint13Fill = Paint()..style = PaintingStyle.fill;
    paint13Fill.color = const Color(0xff36454C);
    canvas.drawRect(
        Rect.fromLTWH(size.width * 0.2033093, size.height * 0.9940429,
            size.width * 0.01418442, size.height * 0.005826708),
        paint13Fill);

    final path_14 = Path();
    path_14.moveTo(328.511, 77.0213);
    path_14.cubicTo(337.629, 77.0213, 345.021, 69.6292, 345.021, 60.5106);
    path_14.cubicTo(345.021, 51.3921, 337.629, 44, 328.511, 44);
    path_14.cubicTo(319.392, 44, 312, 51.3921, 312, 60.5106);
    path_14.cubicTo(312, 69.6292, 319.392, 77.0213, 328.511, 77.0213);
    path_14.close();

    final paint14Fill = Paint()..style = PaintingStyle.fill;
    paint14Fill.color = const Color(0xff262C2D);
    canvas.drawPath(path_14, paint14Fill);

    final path_15 = Path();
    path_15.moveTo(328.511, 70.8297);
    path_15.cubicTo(334.21, 70.8297, 338.83, 66.2097, 338.83, 60.5106);
    path_15.cubicTo(338.83, 54.8114, 334.21, 50.1914, 328.511, 50.1914);
    path_15.cubicTo(322.811, 50.1914, 318.191, 54.8114, 318.191, 60.5106);
    path_15.cubicTo(318.191, 66.2097, 322.811, 70.8297, 328.511, 70.8297);
    path_15.close();

    final paint15Fill = Paint()..style = PaintingStyle.fill;
    paint15Fill.color = const Color(0xff121515);
    canvas.drawPath(path_15, paint15Fill);

    final path_16 = Path();
    path_16.moveTo(328.511, 58.4468);
    path_16.cubicTo(329.651, 58.4468, 330.575, 57.5227, 330.575, 56.3829);
    path_16.cubicTo(330.575, 55.2431, 329.651, 54.3191, 328.511, 54.3191);
    path_16.cubicTo(327.371, 54.3191, 326.447, 55.2431, 326.447, 56.3829);
    path_16.cubicTo(326.447, 57.5227, 327.371, 58.4468, 328.511, 58.4468);
    path_16.close();

    final paint16Fill = Paint()..style = PaintingStyle.fill;
    paint16Fill.color = const Color(0xff636F73);
    canvas.drawPath(path_16, paint16Fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

final _screenPath = Path()
  ..moveTo(45.1305, 129.973)
  ..cubicTo(45.0439, 131.645, 45, 133.329, 45, 135.022)
  ..lineTo(45, 1637.98)
  ..cubicTo(45, 1691.01, 88.002, 1734, 141.048, 1734)
  ..lineTo(731.952, 1734)
  ..cubicTo(784.998, 1734, 828, 1691.01, 828, 1637.98)
  ..lineTo(828, 135.022)
  ..cubicTo(828, 134.815, 827.999, 134.608, 827.998, 134.401)
  ..cubicTo(827.664, 81.6555, 784.791, 39, 731.952, 39)
  ..lineTo(596.761, 39)
  ..cubicTo(589.566, 41.5313, 584.408, 48.3863, 584.408, 56.4451)
  ..cubicTo(584.408, 81.9729, 563.708, 102.667, 538.174, 102.667)
  ..lineTo(332.826, 102.667)
  ..cubicTo(307.292, 102.667, 286.592, 81.9729, 286.592, 56.4451)
  ..cubicTo(286.592, 48.3863, 281.434, 41.5313, 274.239, 39)
  ..lineTo(141.048, 39)
  ..cubicTo(117.114, 39, 95.2253, 47.7516, 78.408, 62.2285)
  ..cubicTo(71.9295, 67.8055, 66.2036, 74.2321, 61.4035, 81.3353)
  ..cubicTo(51.9291, 95.3554, 46.0612, 112.011, 45.1305, 129.973)
  ..close()
  ..fillType = PathFillType.evenOdd;