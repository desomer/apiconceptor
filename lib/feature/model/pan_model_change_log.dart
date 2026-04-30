import 'package:flutter/material.dart';
import 'package:jsonschema/core/bdd/data_acces.dart';
import 'package:jsonschema/core/model_schema.dart';

class PanModelChangeLog extends StatefulWidget {
  const PanModelChangeLog({super.key, required this.currentModel});
  final ModelSchema currentModel;

  @override
  State<PanModelChangeLog> createState() => _PanModelChangeLogState();
}

class _PanModelChangeLogState extends State<PanModelChangeLog> {
  @override
  Widget build(BuildContext context) {
    var modelSchemaDetail = widget.currentModel;

    var histo = bddStorage.getHistories(modelSchemaDetail);

    return FutureBuilder<List<Map<String, dynamic>>?>(
      future: histo,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Text('No change history available.');
        } else {
          // final md = modelSchemaDetail.getHistory(toMarkdown: true);
          // return MarkdownWidget(data: md);
          final changes = modelSchemaDetail.getHistoryInfo();
          return ListView.builder(
            itemCount: changes.length,
            itemBuilder: (context, index) {
              final change = changes[index];
              return change;
            },
          );
        }
      },
    );
  }
}
