import 'dart:math';

enum TokenType { number, string, variable, function, ope, undefine }

class Token {
  Token(this.text, this.type);

  int start = 0;
  int end = 0;
  String text;
  TokenType type;
  EvalException? exception;

  @override
  String toString() {
    return '${type.name}[$text]($start,$end)';
  }
}

class EvalFormula {
  int idxChar = 0;
  late String tokenStr;
  final listTokens = <Token>[];

  void doFormula(String expression) {
    final tokens = _tokenize(expression);

    print("Expression : $expression");
    final rpn = _toRPN(tokens);
    print("Tokens     : $tokens");
    print("RPN        : $rpn");
    try {
      final result = _evaluateRPN(rpn);
      print("Résultat   : $result");
    } catch (e) {
      print('$e');
    }
  }

  void _addToken(Token token) {
    if (listTokens.isNotEmpty) {
      token.start = listTokens.last.end;
      int i = token.start;
      while (tokenStr[i] == ' ') {
        token.start++;
        i++;
      }
    }
    token.end = idxChar + 1;
    listTokens.add(token);
  }

  List<Token> _tokenize(String input) {
    listTokens.clear();
    tokenStr = input;
    final buffer = StringBuffer();

    for (int i = 0; i < input.length; i++) {
      idxChar = i;
      final char = input[i];

      if (char == ' ') continue;

      if (isOperator(char) ||
          isParenthesis(char) ||
          char == ',' ||
          char == '=') {
        if (buffer.isNotEmpty) {
          _addToken(Token(buffer.toString(), TokenType.undefine));
          buffer.clear();
        }
        var doubleOpe =
            listTokens.isNotEmpty &&
                listTokens.last.text.length == 1 &&
                listTokens.last.text[0] == char ||
            char == '=';
        if (doubleOpe) {
          // ==, >= , && , etc...
          String nToken = listTokens.last.text + char;
          listTokens.removeLast();
          _addToken(Token(nToken, TokenType.ope));
        } else {
          _addToken(Token(char, TokenType.ope));
        }
      } else if (isString(char)) {
        // les string
        buffer.write(char);
        int startString = i;
        while (i + 1 < input.length && input[i + 1] != char) {
          i++;
          buffer.write(input[i]);
        }
        EvalException? e;
        if (i == input.length - 1 && input[i] != char) {
          e = EvalException(message: 'String not end');
        } else if (i > startString) {
          i++;
          buffer.write(char);
        }
        var string = buffer.toString();
        _addToken(Token(string, TokenType.string)..exception = e);
        buffer.clear();
      } else if (isLetter(char)) {
        // les variable
        buffer.write(char);
        while (i + 1 < input.length &&
            (isLetter(input[i + 1]) || isDigit(input[i + 1]))) {
          i++;
          buffer.write(input[i]);
        }
        _addToken(Token(buffer.toString(), TokenType.variable));
        buffer.clear();
      } else {
        // les number
        buffer.write(char);
        while (i + 1 < input.length &&
            (isDigit(input[i + 1]) || input[i + 1] == '.')) {
          i++;
          buffer.write(input[i]);
        }
        _addToken(Token(buffer.toString(), TokenType.number));
        buffer.clear();
      }
    }

    if (buffer.isNotEmpty) {
      _addToken(Token(buffer.toString(), TokenType.undefine));
    }

    return listTokens;
  }

  //-----------------------------------------------------------
  List<Token> _toRPN(List<Token> tokens) {
    final output = <Token>[];
    final stack = <Token>[];

    final precedence = {
      '>': 1,
      '<': 1,
      '>=': 1,
      '<=': 1,
      '&&': 1,
      '||': 1,
      '+': 2,
      '-': 2,
      '*': 3,
      '/': 3,
      '^': 4,
    };

    int i = 0;
    for (final elem in tokens) {
      var token = elem.text;
      if (isNumber(token)) {
        output.add(elem);
      } else if (isFunc(elem, i)) {
        elem.type = TokenType.function;
        stack.add(elem);
      } else if (token == ',') {
        while (stack.isNotEmpty && stack.last.text != '(') {
          output.add(stack.removeLast());
        }
      } else if (isOperator(token)) {
        while (stack.isNotEmpty &&
            isOperator(stack.last.text) &&
            precedence[token]! <= precedence[stack.last.text]!) {
          output.add(stack.removeLast());
        }
        stack.add(elem);
      } else if (token == '(') {
        stack.add(elem);
      } else if (token == ')') {
        while (stack.isNotEmpty && stack.last.text != '(') {
          output.add(stack.removeLast());
        }
        if (stack.isEmpty) {
          elem.exception = EvalException(message: ') not start');
        } else {
          stack.removeLast(); // Remove '('
          if (stack.isNotEmpty && isFunc(stack.last, -1)) {
            output.add(stack.removeLast());
          }
        }
      } else {
        //print('var $token');
        output.add(elem);
      }
      i++;
    }

    while (stack.isNotEmpty) {
      output.add(stack.removeLast());
    }

    return output;
  }

  //-------------------------------------------------------------
  dynamic _evaluateRPN(List<Token> rpn) {
    final stack = <dynamic>[];

    for (final token in rpn) {
      if (isNumber(token.text)) {
        stack.add(double.parse(token.text));
      } else if (isOperator(token.text)) {
        final b = stack.removeLast();
        final a = stack.removeLast();
        switch (token.text) {
          case '&&':
            stack.add(a && b);
            break;
          case '||':
            stack.add(a || b);
            break;
          case '>':
            stack.add(a > b);
            break;
          case '<':
            stack.add(a < b);
            break;
          case '>=':
            stack.add(a >= b);
            break;
          case '<=':
            stack.add(a <= b);
            break;
          case '+':
            stack.add(a + b);
            break;
          case '-':
            stack.add(a - b);
            break;
          case '*':
            stack.add(a * b);
            break;
          case '/':
            stack.add(a / b);
            break;
          case '^':
            stack.add(pow(a, b).toDouble());
            break;
        }
      } else if (isFunc(token, -1)) {
        switch (token.text) {
          case 'len':
            final a = stack.removeLast();
            stack.add((a as String).length);
            break;
          case 'max':
            final b = stack.removeLast();
            final a = stack.removeLast();
            stack.add(max(a, b));
            break;
          case 'min':
            final b = stack.removeLast();
            final a = stack.removeLast();
            stack.add(min(a, b));
            break;
          case 'pow':
            final b = stack.removeLast();
            final a = stack.removeLast();
            stack.add(pow(a, b).toDouble());
            break;
          case 'sqrt':
            final a = stack.removeLast();
            stack.add(sqrt(a));
            break;
          case 'log':
            final a = stack.removeLast();
            stack.add(log(a));
            break;
          case 'sin':
            final a = stack.removeLast();
            stack.add(sin(a * pi / 180)); // degrés → radians
            break;
          case 'cos':
            final a = stack.removeLast();
            stack.add(cos(a * pi / 180));
            break;
          case 'distance':
            final y2 = stack.removeLast();
            final x2 = stack.removeLast();
            final y1 = stack.removeLast();
            final x1 = stack.removeLast();
            final dx = x2 - x1;
            final dy = y2 - y1;
            stack.add(sqrt(dx * dx + dy * dy));
            break;
          default:
            var e = EvalException(message: 'function ${token.text} unkowned');
            token.exception = e;
            return e;
        }
      } else {
        if (token.text == 'true') {
          stack.add(true);
        } else if (token.text == 'false') {
          stack.add(false);
        } else if (isString(token.text[0]) &&
            isString(token.text[token.text.length - 1])) {
          // retire les quoite des string
          var substring = token.text.substring(1, token.text.length - 1);
          stack.add(substring);
        } else {
          print('${token.text} = 1.0');
          stack.add(1.0);
        }
      }
    }

    return stack.single;
  }

  bool isOperator(String token) => [
    '&&',
    '||',
    '>',
    '<',
    '>=',
    '<=',
    '&',
    '|',
    '+',
    '-',
    '*',
    '/',
    '^',
  ].contains(token);

  bool isParenthesis(String token) => ['(', ')'].contains(token);
  bool isString(String token) => ['"', '\''].contains(token);

  bool isLetter(String char) => RegExp(r'[a-zA-Z]').hasMatch(char);

  bool isDigit(String char) => RegExp(r'[0-9]').hasMatch(char);

  bool isNumber(String token) => RegExp(r'^\d+(\.\d+)?$').hasMatch(token);

  bool isFunc(Token token, int idx) {
    if (token.type == TokenType.function) return true;
    if (token.type == TokenType.variable &&
        idx >= 0 &&
        idx < listTokens.length - 2 &&
        listTokens[idx + 1].text == '(') {
      token.type = TokenType.function;
      return true;
    }
    return false;
  }
}

class EvalException {
  final String message;

  EvalException({required this.message});

  @override
  String toString() {
    return message;
  }
}
