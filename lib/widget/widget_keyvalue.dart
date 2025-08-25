import 'package:flutter/material.dart';

class KeyValueTable extends StatelessWidget {
  final Function fct;
  final ValueNotifier<int> change;

  const KeyValueTable({super.key, required this.fct, required this.change});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection:
          Axis.horizontal, // utile si les clés/valeurs sont longues
      child: ValueListenableBuilder(
        valueListenable: change,
        builder: (context, value, child) {
          List<Map<String, String>> data = fct() ?? [];

          return DataTable(
            dataRowMaxHeight: 30,
            dataRowMinHeight: 30,
            columns: const [
              DataColumn(
                label: Text(
                  'Key',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Value',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            rows:
                data.map((entry) {
                  return DataRow(
                    cells: [
                      DataCell(SelectableText(entry['key']!)),
                      DataCell(SelectableText(entry['value']!)),
                    ],
                  );
                }).toList(),
          );
        },
      ),
    );
  }
}
