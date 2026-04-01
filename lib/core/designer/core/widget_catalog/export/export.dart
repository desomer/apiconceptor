import 'dart:convert';

/// Convertit du JSONL (une ligne = un objet JSON)
/// en CSV compatible Excel + Google Sheets.
class CsvOptions {
  final String separator; // "," ou ";"
  final bool excelProtectSensitiveValues;

  const CsvOptions({
    this.separator = ';',
    this.excelProtectSensitiveValues = true,
  });
}

class CsvResult {
  final String csv; // CSV en texte (CRLF)
  final List<int>
  bytes; // CSV en bytes UTF-8 + BOM (prêt à écrire dans un fichier)

  CsvResult(this.csv, this.bytes);
}

CsvResult jsonlToCsvExcelFriendly(
  List<Map<String, dynamic>> lines, {
  CsvOptions options = const CsvOptions(),
}) {
  final List<Map<String, dynamic>> objects = [];
  final Set<String> headers = {};

  for (final line in lines) {
    if (line.isEmpty) continue;

    objects.add(line);
    headers.addAll(line.keys);
  }

  final headerList = headers.toList();
  final buffer = StringBuffer();

  // Ligne d'en-tête
  buffer.writeln(
    headerList.map((h) => _toCsvValue(h, options)).join(options.separator),
  );

  // Lignes de données
  for (final obj in objects) {
    final rowValues = headerList
        .map((h) {
          final value = obj[h];
          final str = value == null ? '' : value.toString();
          return _toCsvValue(str, options);
        })
        .join(options.separator);

    buffer.writeln(rowValues);
  }

  // Normaliser les retours à la ligne pour Excel : \r\n
  String csv;
  if (options.excelProtectSensitiveValues) {
    csv = buffer.toString().replaceAll('\n', '\r\n');
  } else {
    csv = buffer.toString();
  }

  // UTF-8 avec BOM pour Excel
  var bytesWithBom = <int>[];
  if (options.excelProtectSensitiveValues) {
    final bom = utf8.encode('\uFEFF');
    final csvBytes = utf8.encode(csv);
    bytesWithBom = <int>[...bom, ...csvBytes];
  } else {
    bytesWithBom = utf8.encode(csv);
  }

  return CsvResult(csv, bytesWithBom);
}

/// Transforme une valeur en cellule CSV correctement échappée.
String _toCsvValue(String value, CsvOptions options) {
  var v = value;

  // Échapper les guillemets
  v = v.replaceAll('"', '""');
  
  if (/*options.excelProtectSensitiveValues &&*/
      _looksLikeNumberOrDateForExcel(v)) {
    // Empêche Excel de convertir en nombre/date
    v = '=${"\"$v\""}';
  }


  // Toujours entourer de guillemets
  return '"$v"';
}

/// Détecte les valeurs que Excel risque de convertir (dates, nombres, notation scientifique…)
bool _looksLikeNumberOrDateForExcel(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return false;

  final numericLike = RegExp(r'^[\+\-]?[0-9]+([.,][0-9]+)?$');
  final sciLike = RegExp(r'^[0-9]+(\.[0-9]+)?[eE][\+\-]?[0-9]+$');
  final dateLike = RegExp(r'^[0-9]{2,4}[-/][0-9]{1,2}[-/][0-9]{1,2}$');

  return numericLike.hasMatch(trimmed) ||
      sciLike.hasMatch(trimmed) ||
      dateLike.hasMatch(trimmed);
}
