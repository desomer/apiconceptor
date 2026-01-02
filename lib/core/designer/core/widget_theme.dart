import 'dart:convert';
import 'package:flutter/material.dart';

class MaterialThemeModel {
  final Map<String, dynamic> schemes;

  MaterialThemeModel({required this.schemes});

  factory MaterialThemeModel.fromJson(Map<String, dynamic> json) {
    return MaterialThemeModel(schemes: json['schemes'] as Map<String, dynamic>);
  }

  static Future<MaterialThemeModel> loadFromAsset(String data) async {
    return MaterialThemeModel.fromJson(jsonDecode(data));
  }

  ColorScheme toColorScheme(String schemeName) {
    if (!schemes.containsKey(schemeName)) {
      throw Exception("Scheme '$schemeName' not found in JSON");
    }

    final scheme = schemes[schemeName] as Map<String, dynamic>;

    Color parse(String hex) =>
        Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);

    return ColorScheme(
      brightness:
          schemeName.contains("dark") ? Brightness.dark : Brightness.light,
      primary: parse(scheme["primary"]),
      onPrimary: parse(scheme["onPrimary"]),
      primaryContainer: parse(scheme["primaryContainer"]),
      onPrimaryContainer: parse(scheme["onPrimaryContainer"]),
      secondary: parse(scheme["secondary"]),
      onSecondary: parse(scheme["onSecondary"]),
      secondaryContainer: parse(scheme["secondaryContainer"]),
      onSecondaryContainer: parse(scheme["onSecondaryContainer"]),
      tertiary: parse(scheme["tertiary"]),
      onTertiary: parse(scheme["onTertiary"]),
      tertiaryContainer: parse(scheme["tertiaryContainer"]),
      onTertiaryContainer: parse(scheme["onTertiaryContainer"]),
      error: parse(scheme["error"]),
      onError: parse(scheme["onError"]),
      errorContainer: parse(scheme["errorContainer"]),
      onErrorContainer: parse(scheme["onErrorContainer"]),
      //background: parse(scheme["background"]),
      //onBackground: parse(scheme["onBackground"]),
      surface: parse(scheme["surface"]),
      onSurface: parse(scheme["onSurface"]),
      surfaceContainerHighest: parse(scheme["surfaceVariant"]),
      onSurfaceVariant: parse(scheme["onSurfaceVariant"]),
      outline: parse(scheme["outline"]),
      outlineVariant: parse(scheme["outlineVariant"]),
      shadow: parse(scheme["shadow"]),
      scrim: parse(scheme["scrim"]),
      inverseSurface: parse(scheme["inverseSurface"]),
      onInverseSurface: parse(scheme["inverseOnSurface"]),
      inversePrimary: parse(scheme["inversePrimary"]),
      surfaceTint: parse(scheme["surfaceTint"]),
    );
  }
}

class ThemeController extends ChangeNotifier {
  ThemeData _theme = ThemeData(useMaterial3: true);
  
  void setDefaultTheme(ThemeData them) {
    _theme = them;
    //notifyListeners();
  }

  ThemeData get theme => _theme;

  Future<void> loadFromJsonFile(String data, String schemeName) async {
    final model = await MaterialThemeModel.loadFromAsset(data);
    final colorScheme = model.toColorScheme(schemeName);

    _theme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
    );

    notifyListeners();
  }
}
