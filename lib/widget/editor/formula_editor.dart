import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jsonschema/widget/editor/eval.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Éditeur avec sélection')),
        body: Center(child: HorizontalTextEditor()),
      ),
    );
  }
}

class HorizontalTextEditor extends StatefulWidget {
  const HorizontalTextEditor({super.key});

  @override
  State<HorizontalTextEditor> createState() => _HorizontalTextEditorState();
}

int paddingBetweenWord = 0;

enum ZoneType { text, variable }

class InputZone {
  InputZone({required this.token, this.type = ZoneType.text});
  Token token;
  ZoneType type = ZoneType.text;
}

class _HorizontalTextEditorState extends State<HorizontalTextEditor>
    with SingleTickerProviderStateMixin {
  int cursorIndex = 0;
  int cursorIndexDrag = 0;
  int cursorPositionInWord = 0;
  int? selectionStart;
  int? selectionEnd;

  late AnimationController _controller;
  late Animation<double> _blinkAnimation;
  late FocusNode _focusNode;

  final TextStyle textStyle = TextStyle(fontSize: 15, color: Colors.black);
  List<InputZone> listZone = [];

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();

    _controller = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    )..repeat(reverse: true);

    _blinkAnimation = Tween<double>(begin: 1.0, end: 0.2).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _updateCursorFromPosition(details.localPosition.dx);
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    _updateCursorFromPosition(details.localPosition.dx, isDragging: true);
  }

  void _updateCursorFromPosition(double x, {bool isDragging = false}) {
    double currentX = 0;

    for (int i = 0; i < listZone.length; i++) {
      final text = listZone[i].token.text;
      final textPainter = TextPainter(
        text: TextSpan(text: text, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      double wordStart = currentX;
      double wordEnd = currentX + textPainter.width;

      if (x >= wordStart && x <= wordEnd) {
        // dans le mots
        for (int j = 0; j <= text.length; j++) {
          // recherche du char du cursor
          final subTextPainter = TextPainter(
            text: TextSpan(text: text.substring(0, j), style: textStyle),
            textDirection: TextDirection.ltr,
          )..layout();

          if (x + (isDragging ? 5 : 0) < wordStart + subTextPainter.width) {
            setState(() {
              cursorPositionInWord = j - 1;
              if (isDragging) {
                cursorIndexDrag = i;
                selectionEnd = j - 1;
              } else {
                cursorIndex = i;
                selectionStart = j - 1;
                selectionEnd = null;
                cursorIndexDrag = i;
              }
            });
            _focusNode.requestFocus();
            return;
          }
        }
        // derniere lettre
        setState(() {
          cursorPositionInWord = text.length;
          if (isDragging) {
            cursorIndexDrag = i;
            selectionEnd = text.length;
          } else {
            cursorIndex = i;
            selectionStart = text.length;
            selectionEnd = null;
          }
        });
        _focusNode.requestFocus();
        return;
      }

      currentX += textPainter.width + paddingBetweenWord;
    }

    if (isDragging && x > currentX) {
      setState(() {
        var text = listZone.last.token.text;
        cursorPositionInWord = text.length;
        cursorIndexDrag = listZone.length - 1;
        selectionEnd = cursorPositionInWord;
      });
    } else {
      setState(() {
        cursorIndex = -1;
        cursorPositionInWord = 0;
        selectionStart = null;
        selectionEnd = null;
      });
    }
    _focusNode.unfocus();
  }

  void _handleKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        cursorIndex >= 0 &&
        cursorIndex < listZone.length) {
      String text = listZone[cursorIndex].token.text;

      // if (listZone[cursorIndex].type == ZoneType.variable) return;

      int start = selectionStart ?? cursorPositionInWord;
      int end = selectionEnd ?? cursorPositionInWord;

      if (start > end) {
        int temp = start;
        start = end;
        end = temp;
      }

      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        setState(() {
          selectionStart = null;
          selectionEnd = null;

          if (cursorPositionInWord == 0) {
            gotoPrevWord();
          } else {
            cursorPositionInWord = (cursorPositionInWord - 1).clamp(
              0,
              text.length,
            );
          }
        });
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        setState(() {
          selectionStart = null;
          selectionEnd = null;

          if (cursorPositionInWord == text.length) {
            gotoNextWord();
          } else {
            cursorPositionInWord = (cursorPositionInWord + 1).clamp(
              0,
              text.length,
            );
          }
        });
      } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
        if (start != end) {
          setState(() {
            listZone[cursorIndex].token.text = text.replaceRange(
              start,
              end,
              '',
            );
            cursorPositionInWord = start;
            selectionStart = null;
            selectionEnd = null;
          });
        } else if (cursorPositionInWord > 0) {
          setState(() {
            listZone[cursorIndex].token.text =
                text.substring(0, cursorPositionInWord - 1) +
                text.substring(cursorPositionInWord);
            cursorPositionInWord--;
          });
        } else if (cursorIndex > 0) {
          // supprime sur le mot précedent
          setState(() {
            cursorIndex--;
            var text2 = listZone[cursorIndex].token.text;
            cursorPositionInWord = text2.length;
            listZone[cursorIndex].token.text = text2.substring(
              0,
              cursorPositionInWord - 1,
            );
            cursorPositionInWord--;
          });
        }
      } else if (event.character != null && event.character!.isNotEmpty) {
        // ajout d'un caractére
        setState(() {
          listZone[cursorIndex].token.text = listZone[cursorIndex].token.text
              .replaceRange(start, end, event.character!);
          cursorPositionInWord = start + event.character!.length;
          selectionStart = null;
          selectionEnd = null;
        });
      }
    }
  }

  void gotoNextWord() {
    if (cursorIndex == listZone.length - 1) return;
    cursorIndex++;
    if (listZone[cursorIndex].type == ZoneType.variable) gotoNextWord();
    cursorPositionInWord = 1;
  }

  void gotoPrevWord() {
    if (cursorIndex == 0) return;
    cursorIndex--;

    if (listZone[cursorIndex].type == ZoneType.variable) gotoPrevWord();
    String text = listZone[cursorIndex].token.text;
    cursorPositionInWord = text.length - 1;
  }

  String? formula;

  @override
  Widget build(BuildContext context) {
    if (formula == null) {
      formula = 'len("toto1") > toto2';
    } else {
      StringBuffer buf = StringBuffer();
      for (var element in listZone) {
        buf.write(element.token.text);
      }
      formula = buf.toString();
    }

    var formule = EvalFormula();
    formule.doFormula(formula!);

    var posCur = 0;
    //position du cursor;
    for (var i = 0; i < cursorIndex; i++) {
      posCur = posCur + listZone[i].token.text.length;
    }
    posCur = posCur + cursorPositionInWord;

    listZone.clear();
    int i = 0;
    cursorIndex = -1;
    for (var element in formule.listTokens) {
      if (cursorIndex == -1) {
        int newCur = posCur - element.text.length;
        if (newCur <= 0) {
          cursorIndex = i;
          cursorPositionInWord = posCur;
        }
        posCur = newCur;
      }
      if (element.type == TokenType.variable) {
        listZone.add(InputZone(token: element, type: ZoneType.variable));
      } else {
        listZone.add(InputZone(token: element));
      }
      i++;
    }

    // listZone = [
    //   InputZone(text: '= upper('),
    //   InputZone(text: 'variable a', type: ZoneType.variable),
    //   InputZone(text: ') * 2000'),
    // ];

    return Container(
      color: Colors.black12,
      child: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKey,
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onPanUpdate: _handlePanUpdate,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: AnimatedBuilder(
              animation: _blinkAnimation,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(1000, 40),
                  painter: HorizontalTextPainter(
                    listZone: listZone,
                    zoneIndex: cursorIndex,
                    zoneIndexDrag: cursorIndexDrag,
                    cursorPositionInWord: cursorPositionInWord,
                    selectionStart: selectionStart,
                    selectionEnd: selectionEnd,
                    cursorOpacity: _blinkAnimation.value,
                    defautStyle: textStyle,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class HorizontalTextPainter extends CustomPainter {
  final List<InputZone> listZone;
  int zoneIndex;
  int zoneIndexDrag;
  int cursorPositionInWord;
  int? selectionStart;
  int? selectionEnd;
  final double cursorOpacity;
  final TextStyle defautStyle;

  HorizontalTextPainter({
    required this.listZone,
    required this.zoneIndex,
    required this.zoneIndexDrag,
    required this.cursorPositionInWord,
    required this.selectionStart,
    required this.selectionEnd,
    required this.cursorOpacity,
    required this.defautStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double xOffset = 10.0;

    if (zoneIndex > zoneIndexDrag &&
        selectionStart != null &&
        selectionEnd != null) {
      int temp = zoneIndex;
      zoneIndex = zoneIndexDrag;
      zoneIndexDrag = temp;
      temp = selectionStart!;
      selectionStart = selectionEnd;
      selectionEnd = temp;
    }

    for (int i = 0; i < listZone.length; i++) {
      final inputZone = listZone[i];

      // Dessiner la sélection
      drawSelection(i, inputZone, xOffset, canvas);

      // Dessiner le texte
      var textStype = defautStyle;
      switch (inputZone.token.type) {
        case TokenType.number:
          textStype = defautStyle.copyWith(color: Colors.green);
          break;
        case TokenType.string:
          textStype = defautStyle.copyWith(color: Colors.deepOrange);
          break;   
        case TokenType.function:
          textStype = defautStyle.copyWith(color: Colors.indigoAccent);
          break;                    
        default:
      }

      final textPainter = TextPainter(
        text: TextSpan(text: inputZone.token.text, style: textStype),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(xOffset, 10));

      drawVariable(inputZone, xOffset, textPainter, canvas);

      drawException(inputZone, xOffset, textPainter, canvas);

      // Dessiner le curseur
      drawCursor(i, inputZone, xOffset, canvas, textPainter);

      xOffset += textPainter.width + paddingBetweenWord;
    }
  }

  void drawCursor(
    int i,
    InputZone inputZone,
    double xOffset,
    Canvas canvas,
    TextPainter textPainter,
  ) {
    if (i == zoneIndex && selectionEnd == null) {
      final subTextPainter = TextPainter(
        text: TextSpan(
          text: inputZone.token.text.substring(0, cursorPositionInWord),
          style: defautStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final paint =
          Paint()
            ..color = Colors.red.withValues(alpha: cursorOpacity)
            ..strokeWidth = 2;

      double cursorX = xOffset + subTextPainter.width;

      canvas.drawLine(
        Offset(cursorX, 10),
        Offset(cursorX, 10 + textPainter.height),
        paint,
      );
    }
  }

  void drawVariable(
    InputZone inputZone,
    double xOffset,
    TextPainter textPainter,
    Canvas canvas,
  ) {
    if (inputZone.type == ZoneType.variable) {
      final valueRect = Rect.fromLTWH(
        xOffset,
        10 + 1,
        textPainter.width,
        textPainter.height,
      );
      final paint =
          Paint()
            ..color = Colors.blue
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1;

      // Bordure simple
      canvas.drawRect(valueRect, paint);
    }
  }

  void drawException(
    InputZone inputZone,
    double xOffset,
    TextPainter textPainter,
    Canvas canvas,
  ) {
    if (inputZone.token.exception != null) {
      final paint =
          Paint()
            ..color = Colors.red
            ..strokeWidth = 1
            ..style = PaintingStyle.stroke;

      final path = Path();
      final valueRect = Rect.fromLTWH(
        xOffset,
        10 + 1,
        textPainter.width,
        textPainter.height,
      );
      var y = valueRect.height / 2 + valueRect.height + 2;

      path.moveTo(valueRect.left, y);

      // Paramètres de l'ondulation
      double waveWidth = 6;
      double waveHeight = 6;

      for (
        double x = valueRect.left;
        x < valueRect.left + valueRect.width;
        x += waveWidth
      ) {
        path.cubicTo(
          x + waveWidth / 4,
          y - waveHeight, // premier point de contrôle
          x + 3 * waveWidth / 4,
          y + waveHeight, // deuxième point de contrôle
          x + waveWidth,
          y, // point final
        );
      }

      canvas.drawPath(path, paint);
    }
  }

  void drawSelection(
    int i,
    InputZone inputZone,
    double xOffset,
    Canvas canvas,
  ) {
    if (i == zoneIndex && selectionStart != null && selectionEnd != null) {
      int start = selectionStart!;
      int end = selectionEnd!;

      if (zoneIndex == zoneIndexDrag && start > end) {
        int temp = start;
        start = end;
        end = temp;
      }

      final startPainter = TextPainter(
        text: TextSpan(
          text: inputZone.token.text.substring(0, start),
          style: defautStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      if (zoneIndex == zoneIndexDrag) {
        // sur le même mot
        final selectedPainter = TextPainter(
          text: TextSpan(
            text: inputZone.token.text.substring(start, end),
            style: defautStyle,
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final selectionRect = Rect.fromLTWH(
          xOffset + startPainter.width,
          10,
          selectedPainter.width,
          selectedPainter.height,
        );
        final paint =
            Paint()..color = Colors.lightBlueAccent.withValues(alpha: 0.5);
        canvas.drawRect(selectionRect, paint);
      } else {
        // sur des mot différent
        double dx = 0;
        double zh = 0;
        var selectedPainter = TextPainter(
          text: TextSpan(
            text: inputZone.token.text.substring(start),
            style: defautStyle,
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        dx = selectedPainter.width;
        zh = selectedPainter.height;

        for (var j = i + 1; j <= zoneIndexDrag; j++) {
          final inputZoneDrag = listZone[j];
          if (j < zoneIndexDrag) {
            // ajoute entieremenet la zone
            selectedPainter = TextPainter(
              text: TextSpan(
                text: inputZoneDrag.token.text,
                style: defautStyle,
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            dx = dx + selectedPainter.width;
          } else {
            // ajoute un partie de la zone
            selectedPainter = TextPainter(
              text: TextSpan(
                text: inputZoneDrag.token.text.substring(0, end),
                style: defautStyle,
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            dx = dx + selectedPainter.width;
          }
        }

        final selectionRect = Rect.fromLTWH(
          xOffset + startPainter.width,
          10,
          dx,
          zh,
        );
        final paint =
            Paint()..color = Colors.lightBlueAccent.withValues(alpha: 0.5);
        canvas.drawRect(selectionRect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
