import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jsonschema/widget/widget_model_helper.dart'; // Pour Clipboard

// ignore: must_be_immutable
class ValueViewer extends StatefulWidget {
  const ValueViewer({super.key, required this.longText});
  final String longText;

  @override
  State<ValueViewer> createState() => _ValueViewerState();
}

class _ValueViewerState extends State<ValueViewer> with WidgetHelper {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      child: getChip(
        Icon(
          Icons.remove_red_eye_outlined,
          size: 15,
          color: Color.fromARGB(255, 230, 219, 116),
        ),
        color: null,
      ),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) {
            var s = MediaQuery.of(context).size;

            return AlertDialog(
              title: Text('Value beautifer'),
              content: SizedBox(
                width: s.width * .8,
                height: s.height * .8,
                child: WidgetValueViewer(longText: widget.longText),
              ),
              actions: [
                TextButton(
                  child: Text('Copied'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.longText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('copy to clipboard')),
                    );
                  },
                ),
                TextButton(
                  child: Text('Close'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class WidgetValueViewer extends StatefulWidget {
  const WidgetValueViewer({super.key, required this.longText});
  final String longText;

  @override
  State<WidgetValueViewer> createState() => _WidgetValueViewerState();
}

class _WidgetValueViewerState extends State<WidgetValueViewer> {
  ScrollController sh = ScrollController();
  ScrollController shh = ScrollController();

  bool justify = false;

  Widget getSrollHoriz(Widget child) {
    if (justify) return child;

    var s = MediaQuery.of(context).size;

    return Scrollbar(
      controller: shh,
      thumbVisibility: true,
      trackVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller: shh,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: s.height * .6),
          child: child,
        ),
      ),
    );
  }

  Widget getContent() {
    return Scrollbar(
      controller: sh,
      thumbVisibility: true,
      trackVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        controller: sh,
        child: getSrollHoriz(
          Container(
            decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
            child: SelectionArea(
              child: Text(
                softWrap: true,
                overflow: TextOverflow.visible,
                textContent!,
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? textContent;

  bool isJsonFlexible(String input) {
    try {
      var decoded = jsonDecode(input);

      // Si le résultat est une chaîne, peut-être qu'il faut décoder encore
      if (decoded is String) {
        decoded = jsonDecode(decoded);
      }

      // Vérifie si le résultat final est un Map ou une List
      return decoded is Map || decoded is List;
    } catch (e) {
      return false;
    }
  }

  String prettyPrintJson(String input) {
    const JsonDecoder decoder = JsonDecoder();
    var obj = decoder.convert(input);
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(obj);
  }

  @override
  Widget build(BuildContext context) {
    textContent ??= widget.longText;

    return Column(
      children: [
        Row(
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  textContent = prettyPrintJson(textContent!);
                });
              },
              child: Text('JSON beautifier'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  textContent = textContent!.replaceAll('\\n', '\n');
                  //textContent = textContent!.replaceAll('\\"', '"');
                });
              },
              child: Text('\\\\n to \\n'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  justify = !justify;
                });
              },
              child: Text('Justify'),
            ),
          ],
        ),
        Expanded(child: getContent()),
      ],
    );
  }
}
