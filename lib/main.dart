import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/router_config.dart';
import 'package:fleather/fleather.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

late SharedPreferences prefs;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  prefs = await SharedPreferences.getInstance();

  debugPaintSizeEnabled = false;
  debugPaintBaselinesEnabled = false;
  debugPaintPointersEnabled = false;

  //await startCore();

  //   CoreExpression run = CoreExpression();
  //   run.init('''
  //   // var a = getVar('e');
  //   // var b = a['z'];
  //   // setVar('z', {'r': b+1});
  //   // var z = getVar('z');
  //   // var e = z['r'];
  //   // print("toto \$e");

  //   // var req = await getApi('example', 'get dog');
  //   // print(req);
  //   // var result = await send(req);
  //   // var result = await sendApi('example', 'getDog');
  //   // var s = search(result, 'data[*].attributes.name');
  //   // print("r= \$s");

  //   \$.var['page'] = 12;
  //   \$.api.example.getDog.load();
  //   \$.api.send();
  //   \$.var['listname'] = \$.api.response.jmes['data[*].attributes.name'];

  //   print(\$.var['listname']);

  //   const req2 = {
  //   'headers': {
  //     'authorization': 'Bearer <token>',
  //     'content-type': 'application/json',
  //     'accept': 'application/json',
  //   },
  //   'method': 'GET',
  //   'url': '{{base.url}}/users/2?queryTest=queryResult',
  //   'vars': {}
  // };

  //     ''');

  // try {
  //   var r = await run.eval(
  //     variables: {
  //       'e': {'z': 155},
  //     },
  //   );
  //   print(r);
  // } catch (e) {
  //   print(e);
  // }

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
          FleatherLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
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
