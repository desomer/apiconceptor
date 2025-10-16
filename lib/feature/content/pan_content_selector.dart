import 'package:flutter/material.dart';
    
class PanContentSelector extends StatefulWidget {
  const PanContentSelector({super.key});

  @override
  State<PanContentSelector> createState() => _PanContentSelectorState();
}

class _PanContentSelectorState extends State<PanContentSelector> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Content Selector'),
      ),
      body: Container(),
    );
  }
}