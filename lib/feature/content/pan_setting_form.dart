import 'package:flutter/material.dart';
import 'package:jsonschema/feature/content/json_to_ui.dart';

class PanSettingForm extends StatefulWidget {
  const PanSettingForm({super.key, required this.data});
  final List<WidgetTyped> data;

  @override
  State<PanSettingForm> createState() => _PanSettingFormState();
}

class _PanSettingFormState extends State<PanSettingForm> {
  final List<String> options = ['Flow', 'Tab', 'OtherTab', 'Invisible'];

  @override
  Widget build(BuildContext context) {
    var lignes = widget.data;
    return ReorderableListView(
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final item = lignes.removeAt(oldIndex);
          lignes.insert(newIndex, item);
        });
      },
      children: List.generate(lignes.length, (index) {
        final ligne = lignes[index];
        return Card(
          key: ObjectKey(ligne),
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            title: Row(
              spacing: 20,
              children: [
                Expanded(child: Text(ligne.name)),
                Expanded(child: Text(ligne.type.name)),
                SizedBox( width: 200, child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Height px (-1=auto)',
                  ),
                  keyboardType: TextInputType.number,
                  controller:
                      TextEditingController(text: ligne.height.toString()),
                  onChanged: (value) {
                    //setState(() {
                      ligne.height = int.tryParse(value) ?? -1;
                    //});
                  },
                )),
                SizedBox(
                  width: 200,
                  child: DropdownButton<String>(
                    value: ligne.layout,
                    items:
                        options.map((String valeur) {
                          return DropdownMenuItem<String>(
                            value: valeur,
                            child: Text(valeur),
                          );
                        }).toList(),
                    onChanged: (String? choise) {
                      setState(() {
                        ligne.layout = choise!;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
