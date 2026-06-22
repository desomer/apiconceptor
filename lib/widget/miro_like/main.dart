import 'package:flutter/material.dart';
import 'package:jsonschema/widget/miro_like/widget_miro_like.dart';

void main() {
  runApp(const MiroLikeApp());
}

class MiroLikeApp extends StatelessWidget {
  const MiroLikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Miro Like',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        primaryColor: Colors.blue,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[900],
          foregroundColor: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.grey[900],
      ),
      themeMode: ThemeMode.dark,
      home: const MiroLikeScreen(),
    );
  }
}

class MiroLikeScreen extends StatefulWidget {
  const MiroLikeScreen({super.key});

  @override
  State<MiroLikeScreen> createState() => _MiroLikeScreenState();
}

class _MiroLikeScreenState extends State<MiroLikeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Miro Like Board')),
      body: const Center(child: MiroLikeWidget()),
    );
  }
}
