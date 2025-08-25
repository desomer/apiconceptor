// import 'package:flutter/material.dart';

// import 'package:flutter/services.dart';
// import 'package:flutter_js/flutter_js.dart';
// import 'package:jsonschema/core/jsonata/jsonata.dart';

// void main() => runApp(MyApp());

// class MyApp extends StatefulWidget {
//   const MyApp({super.key});

//   @override
//   _MyAppState createState() => _MyAppState();
// }

// class _MyAppState extends State<MyApp> {
//   final String _jsResult = '';
//   late JavascriptRuntime flutterJs;

//   late Jsonata jsonata;
//   String _result = '';

//   @override
//   void initState() {
//     super.initState();

//     const data = r'''
//     {
//       "products": [
//         {
//           "name": "Product 1",
//           "price": 10.99,
//           "category": "Category A",
//           "quantity": 5
//         },
//         {
//           "name": "Product 2",
//           "price": 5.99,
//           "category": "Category B",
//           "quantity": 10
//         },
//         {
//           "name": "Product 3",
//           "price": 7.99,
//           "category": "Category A",
//           "quantity": 8
//         },
//         {
//           "name": "Product 4",
//           "price": 12.99,
//           "category": "Category C",
//           "quantity": 3
//         }
//       ]
//     }
//     ''';
//     jsonata = Jsonata(data: data);

//     flutterJs = getJavascriptRuntime();
//   }

//   Future<void> _evaluateExpression(String expression) async {
//     final result = await jsonata.evaluate(expression: expression);
//     //setState(() {
//     _result = result.isError ? 'Error: ${result.error}' : '${result.data}';
//     print("========> $_result");
//     //});
//   }

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: Scaffold(
//         appBar: AppBar(title: const Text('FlutterJS Example')),
//         body: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: <Widget>[
//               Text('JS Evaluate Result: $_jsResult\n'),
//               SizedBox(height: 20),
//               Padding(
//                 padding: EdgeInsets.all(10),
//                 child: Text(
//                   'Click on the big JS Yellow Button to evaluate the expression bellow using the flutter_js plugin',
//                 ),
//               ),
//               Padding(
//                 padding: const EdgeInsets.all(8.0),
//                 child: Text(
//                   "Math.trunc(Math.random() * 100).toString();",
//                   style: TextStyle(
//                     fontSize: 12,
//                     fontStyle: FontStyle.italic,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         floatingActionButton: FloatingActionButton(
//           backgroundColor: Colors.transparent,
//           onPressed: () async {
//             try {
//               // JsEvalResult jsResult = flutterJs.evaluate(
//               //   "Math.trunc(Math.random() * 100).toString();",
//               // );
//               // setState(() {
//               //   _jsResult = jsResult.stringResult;
//               // });

//               _evaluateExpression(r'$.products.(price * quantity)^(sum)');
//               //_evaluateExpression(r'$sum(products.(price * quantity))');
//               //_evaluateExpression(r'$.products.(price)');
//               // _evaluateExpression(r'$.products.price^(avg)');
//               _evaluateExpression(r'''$.products.name''');
//             } on PlatformException catch (e) {
//               print('ERRO: ${e.details}');
//             }
//           },
//         ),
//       ),
//     );
//   }
// }
