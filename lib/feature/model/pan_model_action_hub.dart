import 'package:flutter/material.dart';
import 'package:jsonschema/feature/model/pan_model_selector.dart';

class PanModelActionHub extends StatelessWidget {
  const PanModelActionHub({super.key, required this.panModelSelector});

  final PanModelSelector panModelSelector;

  @override
  Widget build(BuildContext context) {
    var style = ElevatedButton.styleFrom(
      backgroundColor: Colors.blueGrey.shade800,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5), // button's shape
      ),
      elevation: 5, // button's elevation when it's pressed
    );

    return SizedBox(
      height: 30,
      child: Row(
        children: [
          ElevatedButton.icon(
            icon: Icon(Icons.add_box_outlined),
            onPressed: () {
              panModelSelector.showImportDialog(context);
            },
            style: style,
            label: Text('New Model'),
          ),
          // ElevatedButton(onPressed: () {}, child: Text('New component')),
          // ElevatedButton(onPressed: () {}, child: Text('New DTO')),
          // ElevatedButton(onPressed: () {}, child: Text('New ORM Entity')),
        ],
      ),
    );
  }
}
