import 'dart:math' as math;

class CalculationResult {
  final String expression;
  final double value;
  final String formattedResult;

  const CalculationResult({
    required this.expression,
    required this.value,
    required this.formattedResult,
  });
}

/// Safe, zero-dependency arithmetic expression evaluator for the Launcher Omnibar.
class CalculatorEvaluator {
  /// Evaluates [rawInput]. Returns [CalculationResult] if it's a valid math expression,
  /// or null if the input is not a math expression or has invalid syntax.
  static CalculationResult? tryEvaluate(String rawInput) {
    var input = rawInput.trim();
    if (input.isEmpty) return null;

    if (input.startsWith('=')) {
      input = input.substring(1).trim();
    }

    // Must contain digits
    if (!RegExp(r'\d').hasMatch(input)) return null;

    // Must contain at least one arithmetic operator
    if (!RegExp(r'[\+\-\*\/\×\÷\%\^]').hasMatch(input)) return null;

    // Reject letters or non-math characters (e.g., "gimp 2.10", "gcc -o", "v1.2")
    if (RegExp(r'[a-zA-Z_]').hasMatch(input)) return null;

    // Normalize operators
    final normalized = input
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll(' ', '');

    try {
      final parser = _Parser(normalized);
      final val = parser.parse();
      if (val.isNaN || val.isInfinite) return null;

      String formatted;
      if (val == val.roundToDouble() && val.abs() < 1e14) {
        // Integer
        final intVal = val.toInt();
        formatted = _formatWithSeparators(intVal.toString());
      } else {
        // Floating point - trim trailing zeros
        formatted = val.toStringAsFixed(6).replaceAll(RegExp(r'\.?0+$'), '');
      }

      return CalculationResult(
        expression: rawInput.trim(),
        value: val,
        formattedResult: formatted,
      );
    } catch (_) {
      return null;
    }
  }

  static String _formatWithSeparators(String intStr) {
    final isNeg = intStr.startsWith('-');
    final digits = isNeg ? intStr.substring(1) : intStr;
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }
    return isNeg ? '-$buffer' : buffer.toString();
  }
}

class _Parser {
  final String text;
  int pos = 0;

  _Parser(this.text);

  int get ch => pos < text.length ? text.codeUnitAt(pos) : -1;

  void nextChar() {
    pos++;
  }

  bool eat(int charToEat) {
    if (ch == charToEat) {
      nextChar();
      return true;
    }
    return false;
  }

  double parse() {
    final x = parseExpression();
    if (pos < text.length) throw FormatException('Unexpected char at $pos');
    return x;
  }

  // Grammar:
  // expression = term | expression `+` term | expression `-` term
  // term       = factor | term `*` factor | term `/` factor | term `%` factor
  // factor     = `+` factor | `-` factor | `(` expression `)` | number | factor `^` factor

  double parseExpression() {
    var x = parseTerm();
    while (true) {
      if (eat(0x2B)) {
        // '+'
        x += parseTerm();
      } else if (eat(0x2D)) {
        // '-'
        x -= parseTerm();
      } else {
        return x;
      }
    }
  }

  double parseTerm() {
    var x = parseFactor();
    while (true) {
      if (eat(0x2A)) {
        // '*'
        x *= parseFactor();
      } else if (eat(0x2F)) {
        // '/'
        final divisor = parseFactor();
        if (divisor == 0) throw const FormatException('Division by zero');
        x /= divisor;
      } else if (eat(0x25)) {
        // '%'
        final divisor = parseFactor();
        if (divisor == 0) throw const FormatException('Modulo by zero');
        x %= divisor;
      } else {
        return x;
      }
    }
  }

  double parseFactor() {
    if (eat(0x2B)) return parseFactor(); // unary '+'
    if (eat(0x2D)) return -parseFactor(); // unary '-'

    double x;
    final startPos = pos;
    if (eat(0x28)) {
      // '('
      x = parseExpression();
      if (!eat(0x29)) throw const FormatException("Missing ')'");
    } else if ((ch >= 0x30 && ch <= 0x39) || ch == 0x2E) {
      // numbers and decimal point
      while ((ch >= 0x30 && ch <= 0x39) || ch == 0x2E) {
        nextChar();
      }
      x = double.parse(text.substring(startPos, pos));
    } else {
      throw FormatException('Unexpected character: ${String.fromCharCode(ch)}');
    }

    if (eat(0x5E)) {
      // '^' power
      x = math.pow(x, parseFactor()).toDouble();
    }

    return x;
  }
}
