import 'package:flutter/material.dart';
import 'package:jsonschema/feature/model/pan_model_import_dialog.dart';
import 'package:jsonschema/widget/editor/cell_prop_editor.dart';

class PanSaveParam extends StatefulWidget {
  const PanSaveParam({super.key});

  @override
  State<PanSaveParam> createState() => _PanSaveParamState();
}

class _PanSaveParamState extends State<PanSaveParam> {
  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double width = size.width * 0.5;
    double height = size.height * 0.8;

    return AlertDialog(
      title: const Text('Save example'),
      content: SizedBox(width: width, height: height, child: getPan()),
      actions: <Widget>[
        TextButton(
          child: const Text('close'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  Map<String, String> info = {};

  Widget getPan() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 80,
          width: 600,
          child: Row(
            spacing: 20,
            children: [
              Flexible(
                child: CellEditor(
                  acces: InfoAccess(map: info, name: 'category'),
                  inArray: false,
                ),
              ),
              Flexible(
                child: CellEditor(
                  acces: InfoAccess(map: info, name: 'name'),
                  inArray: false,
                ),
              ),
            ],
          ),
        ),
        Flexible(child: Container()),
      ],
    );
  }
}
