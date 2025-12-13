import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:jsonschema/core/designer/component/helper/helper_editor.dart';
import 'package:jsonschema/core/designer/component/prop_editor/generic_editor.dart';
import 'package:jsonschema/widget/widget_tab.dart';

class HexColorEditor extends GenericEditor {
  const HexColorEditor({
    super.key,
    required super.json,
    required super.onJsonChanged,
    required super.config,
  });

  @override
  State<HexColorEditor> createState() => _HexColorEditorState();
}

class _HexColorEditorState extends State<HexColorEditor> with HelperEditor {
  late TextEditingController controller;
  late Color currentColor;

  @override
  void initState() {
    super.initState();
    final raw = widget.json[widget.config.id];
    currentColor = _parseColor(raw);
    controller = TextEditingController(text: currentColor.toHexString());
  }

  Color _parseColor(dynamic raw) {
    if (raw is String) {
      var hex = raw.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex'; // ajoute alpha si absent
      return Color(int.parse(hex, radix: 16));
    }
    return Colors.blue; // fallback
  }

  void _updateColor(Color c) {
    setState(() {
      currentColor = c;
      controller.text = c.toHexString();
      widget.json[widget.config.id] = c.toHexString(); // stocke en int ARGB
    });
    widget.onJsonChanged?.call(widget.json);
  }

  void _updateFromHex(String hex) {
    if (hex.length != 8) return;

    try {
      final c = _parseColor(hex);
      _updateColor(c);
    } catch (_) {
      // ignore invalid hex
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Champ HEX
        Expanded(
          child: TextField(
            controller: controller,
            decoration: getInputDecoration(widget.config.name, 0),
            onChanged: _updateFromHex,
          ),
        ),
        const SizedBox(width: 8),
        // Bouton pour ouvrir le picker
        IconButton(
          icon: const Icon(Icons.color_lens),
          color: currentColor,
          onPressed: () {
            showDialog(
              barrierColor: Colors.transparent,
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: const Text('Choisir une couleur'),
                  content: SizedBox(
                    width: 650,
                    height: 300,
                    child: WidgetTab(
                      listTab: [Tab(text: 'Material'), Tab(text: "Picker")],
                      listTabCont: [
                        MaterialPicker(
                          pickerColor: currentColor,
                          onColorChanged: _updateColor,
                          enableLabel: true,
                          portraitOnly: true,
                        ),
                        ColorPicker(
                          pickerColor: currentColor,
                          onColorChanged: _updateColor,
                          enableAlpha: true,
                          displayThumbColor: true,
                        ),
                      ],
                      heightTab: 40,
                    ),
                  ),

                  // SingleChildScrollView(
                  //   child:
                  // ),
                  actions: [
                    TextButton(
                      child: const Text('Fermer'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}


/// Material Color Picker

// The Color Picker which contains Material Design Color Palette.
class MaterialPicker extends StatefulWidget {
  const MaterialPicker({
    super.key,
    required this.pickerColor,
    required this.onColorChanged,
    this.onPrimaryChanged,
    this.enableLabel = false,
    this.portraitOnly = false,
  });

  final Color pickerColor;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<Color>? onPrimaryChanged;
  final bool enableLabel;
  final bool portraitOnly;

  @override
  State<StatefulWidget> createState() => _MaterialPickerState();
}

class _MaterialPickerState extends State<MaterialPicker> {
  final List<List<Color>> _colorTypes = [
    [Colors.red, Colors.redAccent],
    [Colors.pink, Colors.pinkAccent],
    [Colors.purple, Colors.purpleAccent],
    [Colors.deepPurple, Colors.deepPurpleAccent],
    [Colors.indigo, Colors.indigoAccent],
    [Colors.blue, Colors.blueAccent],
    [Colors.lightBlue, Colors.lightBlueAccent],
    [Colors.cyan, Colors.cyanAccent],
    [Colors.teal, Colors.tealAccent],
    [Colors.green, Colors.greenAccent],
    [Colors.lightGreen, Colors.lightGreenAccent],
    [Colors.lime, Colors.limeAccent],
    [Colors.yellow, Colors.yellowAccent],
    [Colors.amber, Colors.amberAccent],
    [Colors.orange, Colors.orangeAccent],
    [Colors.deepOrange, Colors.deepOrangeAccent],
    [Colors.brown],
    [Colors.grey],
    [Colors.blueGrey],
    [Colors.black],
  ];

  List<Color> _currentColorType = [Colors.red, Colors.redAccent];
  Color _currentShading = Colors.transparent;

  List<Map<Color, String>> _shadingTypes(List<Color> colors) {
    List<Map<Color, String>> result = [];

    for (Color colorType in colors) {
      if (colorType == Colors.grey) {
        result.addAll([50, 100, 200, 300, 350, 400, 500, 600, 700, 800, 850, 900]
            .map((int shade) => {Colors.grey[shade]!: shade.toString()})
            .toList());
      } else if (colorType == Colors.black || colorType == Colors.white) {
        result.addAll([
          {Colors.black: ''},
          {Colors.white: ''}
        ]);
      } else if (colorType is MaterialAccentColor) {
        result.addAll([100, 200, 400, 700].map((int shade) => {colorType[shade]!: 'A$shade'}).toList());
      } else if (colorType is MaterialColor) {
        result.addAll([50, 100, 200, 300, 400, 500, 600, 700, 800, 900]
            .map((int shade) => {colorType[shade]!: shade.toString()})
            .toList());
      } else {
        result.add({const Color(0x00000000): ''});
      }
    }

    return result;
  }

  @override
  void initState() {
    for (List<Color> _colors in _colorTypes) {
      _shadingTypes(_colors).forEach((Map<Color, String> color) {
        if (widget.pickerColor.value == color.keys.first.value) {
          return setState(() {
            _currentColorType = _colors;
            _currentShading = color.keys.first;
          });
        }
      });
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    bool isPortrait = MediaQuery.of(context).orientation == Orientation.portrait || widget.portraitOnly;

    Widget colorList() {
      var theme = Theme.of(context);

      return Container(
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(),
        child: Container(
          margin: isPortrait ? const EdgeInsets.only(right: 10) : const EdgeInsets.only(bottom: 10),
          width: isPortrait ? 60 : null,
          height: isPortrait ? null : 60,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [BoxShadow(color: (theme.brightness == Brightness.light) ? (theme.brightness == Brightness.light) ? Colors.grey[300]! : Colors.black38 : Colors.black38, blurRadius: 10)],
            border: isPortrait
                ? Border(right: BorderSide(color: (theme.brightness == Brightness.light) ? Colors.grey[300]! : Colors.black38, width: 1))
                : Border(top: BorderSide(color: (theme.brightness == Brightness.light) ? Colors.grey[300]! : Colors.black38, width: 1)),
          ),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context),//.copyWith(dragDevices: PointerDeviceKind.values.toSet()),
            child: ListView(
              scrollDirection: isPortrait ? Axis.vertical : Axis.horizontal,
              children: [
                isPortrait
                    ? const Padding(padding: EdgeInsets.only(top: 7))
                    : const Padding(padding: EdgeInsets.only(left: 7)),
                ..._colorTypes.map((List<Color> colors) {
                  Color colorType = colors[0];
                  return GestureDetector(
                    onTap: () {
                      if (widget.onPrimaryChanged != null) widget.onPrimaryChanged!(colorType);
                      setState(() => _currentColorType = colors);
                    },
                    child: Container(
                      color: const Color(0x00000000),
                      padding:
                      isPortrait ? const EdgeInsets.fromLTRB(0, 7, 0, 7) : const EdgeInsets.fromLTRB(7, 0, 7, 0),
                      child: Align(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 25,
                          height: 25,
                          decoration: BoxDecoration(
                            color: colorType,
                            shape: BoxShape.circle,
                            boxShadow: _currentColorType == colors
                                ? [
                              colorType == theme.cardColor
                                  ? BoxShadow(
                                color: (theme.brightness == Brightness.light) ? Colors.grey[300]! : Colors.black38,
                                blurRadius: 10,
                              )
                                  : BoxShadow(
                                color: colorType,
                                blurRadius: 10,
                              ),
                            ]
                                : null,
                            border: colorType == Theme.of(context).cardColor
                                ? Border.all(color: (Theme.of(context).brightness == Brightness.light) ? Colors.grey[300]! : Colors.black38, width: 1)
                                : null,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                isPortrait
                    ? const Padding(padding: EdgeInsets.only(top: 5))
                    : const Padding(padding: EdgeInsets.only(left: 5)),
              ],
            ),
          ),
        ),
      );
    }

    Widget shadingList() {
      return ScrollConfiguration(
        behavior: ScrollConfiguration.of(context), //.copyWith(dragDevices: PointerDeviceKind.values.toSet()),
        child: ListView(
          scrollDirection: isPortrait ? Axis.vertical : Axis.horizontal,
          children: [
            isPortrait
                ? const Padding(padding: EdgeInsets.only(top: 15))
                : const Padding(padding: EdgeInsets.only(left: 15)),
            ..._shadingTypes(_currentColorType).map((Map<Color, String> aColor) {
              final Color color = aColor.keys.first;
              return GestureDetector(
                onTap: () {
                  setState(() => _currentShading = color);
                  widget.onColorChanged(color);
                },
                child: Container(
                  color: const Color(0x00000000),
                  margin: isPortrait ? const EdgeInsets.only(right: 10) : const EdgeInsets.only(bottom: 10),
                  padding: isPortrait ? const EdgeInsets.fromLTRB(0, 7, 0, 7) : const EdgeInsets.fromLTRB(7, 0, 7, 0),
                  child: Align(
                    child: AnimatedContainer(
                      curve: Curves.fastOutSlowIn,
                      duration: const Duration(milliseconds: 500),
                      width:
                      isPortrait ? (_currentShading == color ? 250 : 230) : (_currentShading == color ? 50 : 30),
                      height: isPortrait ? 50 : 220,
                      decoration: BoxDecoration(
                        color: color,
                        boxShadow: _currentShading == color
                            ? [
                          (color == Colors.white) || (color == Colors.black)
                              ? BoxShadow(
                            color: (Theme.of(context).brightness == Brightness.light) ? Colors.grey[300]! : Colors.black38,
                            blurRadius: 10,
                          )
                              : BoxShadow(
                            color: color,
                            blurRadius: 10,
                          ),
                        ]
                            : null,
                        border: (color == Colors.white) || (color == Colors.black)
                            ? Border.all(color: (Theme.of(context).brightness == Brightness.light) ? Colors.grey[300]! : Colors.black38, width: 1)
                            : null,
                      ),
                      child: widget.enableLabel
                          ? isPortrait
                          ? Row(
                        children: [
                          Text(
                            '  ${aColor.values.first}',
                            style: TextStyle(color: useWhiteForeground(color) ? Colors.white : Colors.black),
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '#${color.toHexString()}  ',
                                style: TextStyle(
                                  color: useWhiteForeground(color) ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                          : AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: _currentShading == color ? 1 : 0,
                        child: Container(
                          padding: const EdgeInsets.only(top: 16),
                          alignment: Alignment.topCenter,
                          child: Text(
                            aColor.values.first,
                            style: TextStyle(
                              color: useWhiteForeground(color) ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            softWrap: false,
                          ),
                        ),
                      )
                          : const SizedBox(),
                    ),
                  ),
                ),
              );
            }),
            isPortrait
                ? const Padding(padding: EdgeInsets.only(top: 15))
                : const Padding(padding: EdgeInsets.only(left: 15)),
          ],
        ),
      );
    }

    if (isPortrait) {
      return SizedBox(
        width: 350,
        height: 500,
        child: Row(
          children: <Widget>[
            colorList(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: shadingList(),
              ),
            ),
          ],
        ),
      );
    } else {
      return SizedBox(
        width: 500,
        height: 300,
        child: Column(
          children: <Widget>[
            colorList(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: shadingList(),
              ),
            ),
          ],
        ),
      );
    }
  }
}
