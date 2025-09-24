import 'package:flutter/material.dart';
import 'package:jsonschema/feature/content/json_to_ui.dart';

class PanSetting extends StatefulWidget {
  const PanSetting({super.key, required this.data});
  final List<WidgetTyped> data;

  @override
  State<PanSetting> createState() => _PanSettingState();
}

class _PanSettingState extends State<PanSetting> {
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
              children: [
                Expanded(child: Text(ligne.name)),
                Expanded(child: Text(ligne.type.name)),
                SizedBox( width: 200,
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
            )
          ),
        );
      }),
    );
  }
}
