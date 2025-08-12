import 'package:flutter/material.dart';
import 'package:jsonschema/core/json_browser.dart';
import 'package:jsonschema/json_browser/browse_glossary.dart';
import 'package:jsonschema/start_core.dart';
import 'package:jsonschema/widget/widget_model_helper.dart';

// ignore: must_be_immutable
class WidgetGlossaryIndicator extends StatelessWidget with WidgetHelper {
  WidgetGlossaryIndicator({super.key, required this.attr});
  final AttributInfo attr;
  GlossaryInfo? info;

  @override
  Widget build(BuildContext context) {
    if (info != null) {
      return getIndicator(info!);
    }

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
          GlossaryInfo i = snapshot.data!;
          info = i;

          return getIndicator(info!);
        }
        // Si aucune donnée n'est retournée, on affiche un message par défaut
        return Text('?');
      },
    );
  }

  Widget getIndicator(GlossaryInfo info) {
    var isValid = info.validWord?.isNotEmpty ?? false;
    var icon =
        isValid ? Icons.check_circle_outline_outlined : Icons.warning_amber;
    var text = info.unexistWord?.toString() ?? info.validWord?.toString() ?? '';
    TextStyle? textWidget;
    if (!isValid && (info.existWord?.isNotEmpty ?? false)) {
      text = info.existWord!.toString();
      // textWidget = TextStyle(color: Colors.black);
    }
    if (text.startsWith('[')) text = text.substring(1, text.length - 1);
    return getChip(
      Row(
        children: [
          Icon(icon, size: 20),
          SizedBox(width: 5),
          Text(text, style: textWidget),
        ],
      ),
      color:
          isValid && (info.unexistWord?.isEmpty ?? true)
              ? Colors.green
              : (info.unexistWord?.isEmpty ?? true
                  ? Colors.orange
                  : Colors.red),
    );
  }
}
