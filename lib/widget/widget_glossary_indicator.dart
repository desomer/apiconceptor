import 'package:flutter/material.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/json_browser/browse_glossary.dart';
import 'package:jsonschema/main.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';

class WidgetGlossaryIndicator extends StatelessWidget with WidgetModelHelper {
  const WidgetGlossaryIndicator({super.key, required this.attr});
  final AttributInfo attr;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GlossaryInfo>(
      future: currentCompany.glossaryManager.isValid(attr),
      builder: (context, snapshot) {
        // Pendant le chargement, on affiche un spinner
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container();
        }
        // En cas d'erreur, on affiche un message d'erreur
        if (snapshot.hasError) {
          return Text('Erreur : ${snapshot.error}');
        }
        // Si les données sont disponibles, on les affiche
        if (snapshot.hasData) {
          GlossaryInfo info = snapshot.data!;

          var isValid = info.validWord?.isNotEmpty ?? false;
          var icon =
              isValid
                  ? Icons.check_circle_outline_outlined
                  : Icons.warning_amber;
          var text =
              info.unexistWord?.toString() ?? info.validWord?.toString() ?? '';
          TextStyle? textWidget;
          if (!isValid && (info.existWord?.isNotEmpty ?? false)) {
            text = info.existWord!.toString();
            // textWidget = TextStyle(color: Colors.black);
          }
          if (text.startsWith('[')) text = text.substring(1, text.length - 1);
          return getChip(
            Row(
              children: [Icon(icon, size: 20), SizedBox(width: 5),  Text(text, style: textWidget)],
            ),
            color:
                isValid && (info.unexistWord?.isEmpty ?? true)
                    ? Colors.green
                    : (info.unexistWord?.isEmpty ?? true
                        ? Colors.orange
                        : Colors.red),
          );
        }
        // Si aucune donnée n'est retournée, on affiche un message par défaut
        return Text('?');
      },
    );
  }
}
