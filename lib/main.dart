import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/router_config.dart';
// import 'package:fleather/fleather.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:timezone/data/latest.dart' as tz;

late SharedPreferences prefs;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  tz.initializeTimeZones();

  prefs = await SharedPreferences.getInstance();

  debugPaintSizeEnabled = false;
  debugPaintBaselinesEnabled = false;
  debugPaintPointersEnabled = false;

  runApp(const MyApp());
}

class ThemeHolder {
  static late ThemeData theme;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    var theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: Colors.blueGrey,
    );
    ThemeHolder.theme = theme;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      excludeSemantics: true,
      child: MaterialApp.router(
        title: 'API Architect',
        localizationsDelegates: [
          //FleatherLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          // GlobalCupertinoLocalizations.delegate,
          // GlobalWidgetsLocalizations.delegate,
          //FlutterQuillLocalizations.delegate,
        ],
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color.fromRGBO(86, 80, 14, 171),
        ),
        darkTheme: theme,
        themeMode: ThemeMode.dark,
        routerConfig: router,
      ),
    );
  }
}
