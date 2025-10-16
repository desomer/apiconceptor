import 'package:flutter/material.dart';
import 'package:jsonschema/feature/content/state_manager.dart';

class PanSettingArray extends StatefulWidget {
  const PanSettingArray({super.key, required this.config});
  final ConfigArrayContainer config;

  @override
  State<PanSettingArray> createState() => _PanSettingArrayState();
}

class _PanSettingArrayState extends State<PanSettingArray> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 300, child: getChoise()),
        Expanded(child: Column()),
      ],
    );
  }

  Widget getChoise() {

    return Column(
      children: [
        SwitchListTile(
          title: Text('List of form'),
          value: widget.config.listOfForm,
          onChanged: (bool value) {
            setState(() {
              widget.config.listOfForm = value;
              widget.config.listOfRow = !widget.config.listOfForm;
            });
          },
        ),
        SwitchListTile(
          title: Text('List of row'),
          value: widget.config.listOfRow,
          onChanged: (bool value) {
            setState(() {
              widget.config.listOfRow = value;
              widget.config.listOfForm = !widget.config.listOfRow;
            });
          },
        ),
        //widget.config.nbRowPerPage
        TextField(
          decoration: InputDecoration(
            labelText: 'Nb row per page (-1 = all)',
          ),
          keyboardType: TextInputType.number,
          controller: TextEditingController(
              text: widget.config.nbRowPerPage.toString()),
          onChanged: (value) {
           // setState(() {
              widget.config.nbRowPerPage = int.tryParse(value) ?? -1;
           // });
          },
        ),
      ],
    );
  }
}
