import 'package:flutter/material.dart';
import 'package:jsonschema/feature/api/deprecated/pan_api_selector.dart';

class PanApiActionHub extends StatelessWidget {
  const PanApiActionHub({super.key, required this.selector});
  final PanAPISelector selector;

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
              selector.showImportDialog(context);
            },
            style: style,
            label: Text('New API'),
          ),
          // ElevatedButton(onPressed: () {}, child: Text('New component')),
          // ElevatedButton(onPressed: () {}, child: Text('New DTO')),
        ],
      ),
    );
  }
}
