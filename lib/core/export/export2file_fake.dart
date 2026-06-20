import 'package:jsonschema/core/json_browser.dart';

class Export2JsonToFlatFile {
  final Map<String, dynamic> json;
  Export2JsonToFlatFile(this.json);

  String separator = ';';

  String toFlatFile(AttributInfo attributInfo) {
    StringBuffer bufferHeader = StringBuffer();
    String filename = attributInfo.properties?['filename'] ?? "";
    String encoding = attributInfo.properties?['encoding'] ?? "utf-8";
    String sep = attributInfo.properties?['separator']??";";
    String quote = attributInfo.properties?['quote'] ?? '"';
    String? lineEnding = attributInfo.properties?['line_ending']?? "\\n";

    bufferHeader.write('# filename: $filename\n');
    bufferHeader.write('# encoding: $encoding\n');
    bufferHeader.write('# separator: $sep\n');
    bufferHeader.write('# quote: $quote\n');
    bufferHeader.write('# line_ending: $lineEnding\n');
    separator = sep;

    StringBuffer buffer = StringBuffer();

    // Iterate through the JSON map and write each key-value pair to the buffer
    doNode(json, buffer, 'root', 0);

    bufferHeader.writeln('');
    bufferHeader.writeln(buffer.toString());

    return bufferHeader.toString();
  }

  void doNode(
    Map<dynamic, dynamic> value,
    StringBuffer buffer,
    String key,
    int level,
  ) {
    if (buffer.isNotEmpty && !buffer.toString().endsWith('\n')) {
      buffer.writeln();
    }
    //buffer.writeln('$key:');
    value.forEach((nestedKey, nestedValue) {
      if (nestedValue is Map) {
        doNode(nestedValue, buffer, nestedKey, level + 1);
      } else if (nestedValue is List) {
        for (var item in nestedValue) {
          if (item is Map) {
            doNode(item, buffer, nestedKey, level + 1);
          } else {
            addSeparator(buffer, level);
            buffer.write('$nestedValue');
          }
        }
      } else {
        addSeparator(buffer, level);
        buffer.write('$nestedValue');
      }
    });
  }

  void addSeparator(StringBuffer buffer, int level) {
    if (buffer.isNotEmpty && !buffer.toString().endsWith('\n')) {
      buffer.write(separator);
    }
  }
}
